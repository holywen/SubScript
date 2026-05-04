import AVFoundation

final class AudioExtractor {
    static let targetSampleRate: Double = 16000

    enum ExError: Swift.Error, LocalizedError {
        case noAudioTrack
        case exportFailed(String)
        case unsupportedFormat

        var errorDescription: String? {
            switch self {
            case .noAudioTrack:       return String(localized: "audio_no_track")
            case .exportFailed(let m): return String(format: String(localized: "audio_extract_failed"), m)
            case .unsupportedFormat:  return String(localized: "audio_unsupported_format")
            }
        }
    }

    struct AudioChunk: Sendable {
        let samples: [Float]
        let startTime: Double
        let endTime: Double
        let isFinal: Bool
    }

    func duration(of url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        let duration = try? await asset.load(.duration)
        return duration?.seconds ?? 0
    }

    func extract(from url: URL) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else { throw ExError.noAudioTrack }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        return try await extractToWAV(asset: asset, outputURL: outputURL)
    }

    func streamAudio(from url: URL) -> AsyncStream<AudioChunk> {
        return AsyncStream { continuation in
            let extractor = Self()
            let task = Task.detached {
                await extractor.streamAudioReader(url: url, continuation: continuation)
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func streamAudioReader(
        url: URL,
        continuation: AsyncStream<AudioChunk>.Continuation
    ) async {
        let asset = AVURLAsset(url: url)
        
        do {
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let track = tracks.first else {
                continuation.finish()
                return
            }

            var targetDesc = AudioStreamBasicDescription(
                mSampleRate: Self.targetSampleRate,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
                mBytesPerPacket: 4,
                mFramesPerPacket: 1,
                mBytesPerFrame: 4,
                mChannelsPerFrame: 1,
                mBitsPerChannel: 32,
                mReserved: 0
            )
            guard let targetFormat = AVAudioFormat(streamDescription: &targetDesc) else {
                continuation.finish()
                return
            }

            let reader = try AVAssetReader(asset: asset)
            let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: [
                AVFormatIDKey:             kAudioFormatLinearPCM,
                AVSampleRateKey:           44100,
                AVNumberOfChannelsKey:     1,
                AVLinearPCMBitDepthKey:    32,
                AVLinearPCMIsFloatKey:     true,
                AVLinearPCMIsNonInterleaved: false
            ])
            readerOutput.alwaysCopiesSampleData = false
            reader.add(readerOutput)
            reader.startReading()

            let windowSize = Int(25.0 * Self.targetSampleRate)
            let overlapSize = Int(2.0 * Self.targetSampleRate)
            var accumulated: [Float] = []
            var totalSamplesRead: Int = 0

            while reader.status == .reading {
                try Task.checkCancellation()

                guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else { break }
                guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }
                let length = CMBlockBufferGetDataLength(blockBuffer)
                guard length > 0 else { continue }

                var bytes = [UInt8](repeating: 0, count: length)
                CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: &bytes)

                let sourceFormat = AVAudioFormat(
                    commonFormat: .pcmFormatFloat32,
                    sampleRate: 44100, channels: 1, interleaved: false
                )!
                guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else { continue }

                let inputCount = AVAudioFrameCount(length / 4)
                let outputCount = Int(Double(inputCount) * Self.targetSampleRate / 44100) + 1

                var inputBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: inputCount)!
                inputBuffer.frameLength = inputCount
                bytes.withUnsafeBytes { ptr in
                    let floatPtr = ptr.bindMemory(to: Float.self)
                    inputBuffer.floatChannelData![0].update(from: floatPtr.baseAddress!, count: Int(inputCount))
                }

                var outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: AVAudioFrameCount(outputCount))!
                var convertError: NSError?
                var inputConsumed = false
                converter.convert(to: outputBuffer, error: &convertError) { _, status in
                    if inputConsumed { status.pointee = .endOfStream; return nil }
                    status.pointee = .haveData
                    inputConsumed = true
                    return inputBuffer
                }

                if convertError != nil { continue }

                let newSamples = Array(UnsafeBufferPointer(
                    start: outputBuffer.floatChannelData![0],
                    count: Int(outputBuffer.frameLength)
                ))
                accumulated.append(contentsOf: newSamples)
                totalSamplesRead += newSamples.count

                while accumulated.count >= windowSize {
                    let windowSamples = Array(accumulated.prefix(windowSize))
                    accumulated.removeFirst(overlapSize)

                    let startTime = Double(totalSamplesRead - accumulated.count + overlapSize) / Self.targetSampleRate
                    let endTime = Double(totalSamplesRead - accumulated.count + windowSize) / Self.targetSampleRate

                    continuation.yield(AudioChunk(
                        samples: windowSamples,
                        startTime: startTime,
                        endTime: endTime,
                        isFinal: false
                    ))
                }
            }

            if !accumulated.isEmpty {
                let startTime = Double(totalSamplesRead - accumulated.count) / Self.targetSampleRate
                let endTime = Double(totalSamplesRead) / Self.targetSampleRate
                continuation.yield(AudioChunk(
                    samples: accumulated,
                    startTime: startTime,
                    endTime: endTime,
                    isFinal: true
                ))
            }

            continuation.finish()
        } catch {
            continuation.finish()
        }
    }

    private func extractToWAV(asset: AVURLAsset, outputURL: URL) async throws -> URL {
        var targetDesc = AudioStreamBasicDescription(
            mSampleRate: Self.targetSampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 32,
            mReserved: 0
        )
        guard let targetFormat = AVAudioFormat(streamDescription: &targetDesc)
        else { throw ExError.unsupportedFormat }

        let reader = try AVAssetReader(asset: asset)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else { throw ExError.noAudioTrack }

        let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey:             kAudioFormatLinearPCM,
            AVSampleRateKey:           44100,
            AVNumberOfChannelsKey:     1,
            AVLinearPCMBitDepthKey:    32,
            AVLinearPCMIsFloatKey:     true,
            AVLinearPCMIsNonInterleaved: false
        ])
        readerOutput.alwaysCopiesSampleData = false
        reader.add(readerOutput)
        reader.startReading()

        var allSamples = [Float]()
        allSamples.reserveCapacity(44100 * 60)

        while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }
            let length = CMBlockBufferGetDataLength(blockBuffer)
            var bytes = [UInt8](repeating: 0, count: length)
            CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: length, destination: &bytes)
            bytes.withUnsafeBytes { ptr in
                let floats = ptr.bindMemory(to: Float.self)
                allSamples.append(contentsOf: floats.prefix(length / 4))
            }
        }

        guard reader.status == .completed else {
            throw ExError.exportFailed(reader.error?.localizedDescription ?? "读取失败")
        }

        let sourceFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 44100, channels: 1, interleaved: false
        )!

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat)
        else { throw ExError.unsupportedFormat }

        let inputCount  = AVAudioFrameCount(allSamples.count)
        let outputCount = Int(Double(inputCount) * Self.targetSampleRate / 44100) + 1

        let inputBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: inputCount)!
        inputBuffer.frameLength = inputCount
        allSamples.withUnsafeBufferPointer { ptr in
            inputBuffer.floatChannelData![0].update(from: ptr.baseAddress!, count: allSamples.count)
        }

        let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: AVAudioFrameCount(outputCount))!
        var convertError: NSError?
        var inputConsumed = false
        converter.convert(to: outputBuffer, error: &convertError) { _, status in
            if inputConsumed { status.pointee = .endOfStream; return nil }
            status.pointee = .haveData
            inputConsumed = true
            return inputBuffer
        }

        if let err = convertError { throw ExError.exportFailed(err.localizedDescription) }

        let file = try AVAudioFile(
            forWriting: outputURL,
            settings: targetFormat.settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
        try file.write(from: outputBuffer)
        return outputURL
    }
}