import AVFoundation
import Foundation
import Qwen3ASR
import SpeechVAD

enum PipelineEvent {
    case progress(step: PipelineStep, percent: Double, detail: String)
    case segment(SubtitleSegment)
    case completed([SubtitleSegment])
    case failed(Error)
}

enum PipelineStep: String {
    case reading = "processing_reading"
    case detectingSpeech = "processing_vad"
    case transcribing = "processing_transcribing"
    case postProcessing = "processing_capturing"
    case done = "processing_done"
}

enum PipelineError: Error, LocalizedError {
    case modelsNotLoaded
    case noAudioTrack
    case readFailed(String)

    var errorDescription: String? {
        switch self {
            case .modelsNotLoaded: return String(localized: "transcription_models_not_loaded")
            case .noAudioTrack: return String(localized: "transcription_no_audio_track")
            case .readFailed(let m): return String(format: String(localized: "transcription_read_failed"), m)
        }
    }
}

final class StreamingPipeline: @unchecked Sendable {
  
    private let asr: Qwen3ASRModel
    private let vad: VADModelProtocol
    private var isCancelled = false
  
    init(asr: Qwen3ASRModel, vad: VADModelProtocol) {
        self.asr = asr
        self.vad = vad
    }
    
    func cancel() {
        isCancelled = true
    }
    
    func transcribe(url: URL, language: String = "zh", dialect: String? = nil, onEvent: @escaping @Sendable (PipelineEvent) -> Void) {
        Task.detached(priority: .userInitiated) {
            do {
                try await self.run(url: url, language: language, dialect: dialect, onEvent: onEvent)
            } catch {
                if self.isCancelled || Task.isCancelled {
                    return
                }
                onEvent(.failed(error))
            }
        }
    }
    
    private func run(
        url: URL,
        language: String,
        dialect: String? = nil,
        onEvent: @escaping @Sendable (PipelineEvent) -> Void
    ) async throws {
        print("[Pipeline] run started for URL: \(url.lastPathComponent)")
        
        print("[Pipeline] Calculating audio duration...")
        let totalDuration = await AudioExtractor().duration(of: url)
        print("[Pipeline] Audio duration: \(totalDuration)s")
        
        var allSubtitles: [SubtitleSegment] = []
        var processedUntil: Double = 0.0
        
        onEvent(.progress(
            step: .reading, percent: 0.02,
            detail: String(localized: "pipeline_reading")
        ))
        print("[Pipeline] Sent .reading progress event")
        
        let windowDuration: Double = 25.0
        let overlapDuration: Double = 2.0
        let windowFrames = Int(windowDuration * 16000)
        let overlapFrames = Int(overlapDuration * 16000)
        
        var ringBuffer: [Float] = []
        var windowStart: Double = 0.0
        
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else {
            throw PipelineError.noAudioTrack
        }
        
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false
        ])
        output.alwaysCopiesSampleData = false
        reader.add(output)
        reader.startReading()
        
        while reader.status == .reading {
            try Task.checkCancellation()
            if isCancelled { throw CancellationError() }
        
            guard let sampleBuffer = output.copyNextSampleBuffer(),
                  let block = CMSampleBufferGetDataBuffer(sampleBuffer)
            else { continue }
        
            let length = CMBlockBufferGetDataLength(block)
            var bytes = [UInt8](repeating: 0, count: length)
            CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: &bytes)
        
            bytes.withUnsafeBytes { ptr in
                ringBuffer.append(contentsOf: ptr.bindMemory(to: Float.self).prefix(length / 4))
            }
        
            while ringBuffer.count >= windowFrames {
                let windowSamples = Array(ringBuffer.prefix(windowFrames))
                let windowEnd = windowStart + windowDuration
        
                let percent = totalDuration > 0 ? min(windowStart / totalDuration, 0.95) : 0.5
                
                onEvent(.progress(
                    step: .detectingSpeech,
                    percent: percent,
                    detail: formatTime(windowStart)
                ))
                
                try await Task.sleep(nanoseconds: 1_000_000)
        
                let vadResult = vad.detectSpeech(
                    audio: windowSamples,
                    sampleRate: 16000
                )
        
                for seg in vadResult {
                    let segStart = Double(seg.startTime)
                    let segEnd = Double(seg.endTime)
                    let absStart = windowStart + segStart
                    let absEnd = windowStart + segEnd
        
                    guard absStart >= processedUntil else { continue }
        
                    let startSample = max(0, Int(Double(seg.startTime) * 16000))
                    let endSample = min(windowSamples.count - 1, Int(Double(seg.endTime) * 16000))
        
                    guard startSample < endSample else { continue }
        
                    let speechSamples = Array(windowSamples[startSample...endSample])
        
                    let result = asr.transcribe(
                        audio: speechSamples,
                        sampleRate: 16000,
                        language: dialect ?? language
                    )
        
                    if !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let subtitle = SubtitleSegment(
                            text: result,
                            start: absStart,
                            end: absEnd
                        )
                        allSubtitles.append(subtitle)
                        onEvent(.segment(subtitle))
                    }
                }
        
                processedUntil = windowEnd - overlapDuration
        
                ringBuffer.removeFirst(windowFrames - overlapFrames)
                windowStart += Double(windowFrames - overlapFrames) / 16000
            }
        }
        
        if !ringBuffer.isEmpty {
            let vadResult = vad.detectSpeech(
                audio: ringBuffer,
                sampleRate: 16000
            )
        
            for seg in vadResult {
                let absStart = windowStart + Double(seg.startTime)
                let absEnd = windowStart + Double(seg.endTime)
                
                let startSample = max(0, Int(seg.startTime * 16000))
                let endSample = min(ringBuffer.count - 1, Int(seg.endTime * 16000))
                
                guard startSample < endSample else { continue }
                
                let speechSamples = Array(ringBuffer[startSample...endSample])
                
                let result = asr.transcribe(
                    audio: speechSamples,
                    sampleRate: 16000,
                    language: dialect ?? language
                )
        
                if !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let subtitle = SubtitleSegment(
                        text: result,
                        start: absStart,
                        end: absEnd
                    )
                    allSubtitles.append(subtitle)
                    onEvent(.segment(subtitle))
                }
            }
        }
        
        guard reader.status == .completed else {
            throw PipelineError.readFailed(reader.error?.localizedDescription ?? "未知错误")
        }
        
        onEvent(.progress(
            step: .postProcessing, percent: 0.97,
            detail: String(localized: "pipeline_organizing")
        ))
        
        let sorted = allSubtitles.sorted { $0.start < $1.start }
        let final = mergeShortSegments(sorted, minDuration: 0.5)
        
            onEvent(.progress(step: .done, percent: 1.0, detail: String(localized: "pipeline_done")))
        onEvent(.completed(final))
    }
    
    private func mergeShortSegments(
        _ segments: [SubtitleSegment],
        minDuration: Double
    ) -> [SubtitleSegment] {
        guard !segments.isEmpty else { return [] }
        
        var result = [SubtitleSegment]()
        var pending = segments[0]
        
        for seg in segments.dropFirst() {
            if pending.duration < minDuration {
                pending.text += seg.text
                pending.end = seg.end
            } else {
                result.append(pending)
                pending = seg
            }
        }
        result.append(pending)
        return result
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let m = Int(seconds / 60)
        let s = Int(seconds) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
