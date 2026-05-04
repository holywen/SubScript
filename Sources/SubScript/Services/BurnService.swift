import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class BurnService {
    static let shared = BurnService()
    
    private(set) var isBurning = false
    private(set) var progress: Double = 0
    private(set) var error: String?
    
    private var burnProcess: Process?

    func burnSubtitles(videoURL: URL, subtitles: [SubtitleSegment], config: BurnConfig, bilingual: Bool, completion: @escaping @Sendable (Result<URL, Error>) -> Void) {
        log("=== START burnSubtitles ===")
        
        isBurning = true
        progress = 0
        error = nil
        
        let srtURL: URL
        let outputURL: URL
        
        do {
            srtURL = try saveSubtitlesToTempSRT(subtitles, bilingual: bilingual)
            outputURL = try createOutputURL(for: videoURL, config: config)
        } catch {
            log("ERROR creating files: \(error)")
            completion(.failure(error))
            isBurning = false
            return
        }
        
        log("SRT: \(srtURL.path)")
        log("Output: \(outputURL.path)")
        
        // Find ffmpeg binary
        let ffmpegURL: URL
        do {
            ffmpegURL = try findFFmpeg()
        } catch {
            log("ERROR finding ffmpeg: \(error)")
            completion(.failure(error))
            isBurning = false
            return
        }
        log("FFmpeg: \(ffmpegURL.path)")
        
        // Build ffmpeg command string for shell execution
        // FFmpeg's subtitles filter requires special escaping for colons on macOS
        let escapedPath = srtURL.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ":", with: "\\:")
            .replacingOccurrences(of: "'", with: "'\\''")
        
        let subFilter = "subtitles=filename='\(escapedPath)':force_style='FontSize=\(config.fontSize),PrimaryColour=\(config.primaryColor),OutlineColour=\(config.outlineColor),Outline=\(config.outlineWidth),Shadow=\(config.shadowEnabled ? 1 : 0),Alignment=\(config.position.assAlignment)'"
        
        // 1. Scale to even dimensions (mandatory for VideoToolbox)
        var filter = "\(subFilter),scale=trunc(iw/2)*2:trunc(ih/2)*2"
        if config.videoCodec.rawValue.contains("videotoolbox") {
            filter += ",format=nv12"
        }
        
        log("Filter: \(filter)")
        
        let videoPath = videoURL.path
        let outputPath = outputURL.path
        
        log("FFmpeg: \(ffmpegURL.path)")
        
        let process = Process()
        process.executableURL = ffmpegURL
        
        // Build arguments based on codec type
        var args = [
            "-i", videoPath,
            "-vf", filter,
        ]
        
        // Video codec
        let codec = config.videoCodec.rawValue
        args.append(contentsOf: ["-c:v", codec])
        
        if codec.contains("videotoolbox") {
            args.append(contentsOf: ["-pix_fmt", "nv12"])
            args.append(contentsOf: ["-allow_sw", "1"])
            args.append(contentsOf: ["-color_range", "1"])
        } else if codec == "prores" {
            args.append(contentsOf: ["-pix_fmt", "yuv422p10le"])
        }
        
        // Quality - CRF or bitrate
        if config.videoCodec.supportsCRF {
            let crfValue: Int
            switch config.quality {
            case .high: crfValue = 18
            case .balanced: crfValue = 23
            case .small: crfValue = 28
            case .custom: crfValue = config.customCRF
            }
            args.append(contentsOf: ["-crf", String(crfValue)])
        } else {
            // Bitrate for encoders that don't support CRF (like VideoToolbox and ProRes)
            let rawBitrate = config.quality.bitrate
                .replacingOccurrences(of: "k", with: "")
                .replacingOccurrences(of: "K", with: "")
            if let bits = Int(rawBitrate) {
                args.append(contentsOf: ["-b:v", String(bits * 1000)])
            } else {
                args.append(contentsOf: ["-b:v", "4000k"])
            }
        }
        
        // Audio - copy
        args.append(contentsOf: ["-c:a", "copy"])
        
        // Progress and overwrite
        args.append(contentsOf: ["-progress", "pipe:1", "-y", outputPath])
        
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: "/tmp")

        log("Args: \(process.arguments!)")
        log("FFmpeg URL: \(ffmpegURL.path)")
        log("Video path: \(videoPath)")
        log("Output path: \(outputPath)")
        log("Filter: \(filter)")
        
        let errorPipe = Pipe()
        let outputPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = outputPipe
        
        self.burnProcess = process
        
        log("=== Starting read loop on background thread ===")
        
        Task.detached { [self] in
            do {
                try process.run()
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                    self.isBurning = false
                }
                return
            }
            
            let errorHandle = errorPipe.fileHandleForReading
            let outputHandle = outputPipe.fileHandleForReading
            
            var combinedOutput = ""
            
            while process.isRunning {
                let errorChunk = errorHandle.availableData
                let outputChunk = outputHandle.availableData
                
                // Parse from stderr (original ffmpeg progress)
                if !errorChunk.isEmpty {
                    if let line = String(data: errorChunk, encoding: .utf8) {
                        combinedOutput += line
                        if let timeIdx = line.range(of: "time=") {
                            let afterTime = line[timeIdx.upperBound...]
                            if let endIdx = afterTime.firstIndex(of: " ") ?? afterTime.firstIndex(of: "\n") {
                                let timeStr = String(afterTime[..<endIdx])
                                if let seconds = self.parseFFmpegTime(timeStr) {
                                    await MainActor.run {
                                        self.progress = seconds
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Parse from stdout (-progress output)
                if !outputChunk.isEmpty {
                    if let line = String(data: outputChunk, encoding: .utf8) {
                        combinedOutput += line
                        // -progress outputs "out_time=00:01:23.45"
                        if let timeIdx = line.range(of: "out_time=") {
                            let afterTime = line[timeIdx.upperBound...]
                            if let endIdx = afterTime.firstIndex(of: "\n") {
                                let timeStr = String(afterTime[..<endIdx])
                                if let seconds = self.parseFFmpegTime(timeStr) {
                                    await MainActor.run {
                                        self.progress = seconds
                                    }
                                }
                            }
                        }
                    }
                }
                
                if errorChunk.isEmpty && outputChunk.isEmpty {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }
            
            let finalError = errorHandle.readDataToEndOfFile()
            let finalOutput = outputHandle.readDataToEndOfFile()
            
            if let s = String(data: finalError, encoding: .utf8), !s.isEmpty {
                combinedOutput += s
            }
            if let s = String(data: finalOutput, encoding: .utf8), !s.isEmpty {
                combinedOutput += s
            }
            
            await MainActor.run {
                if process.terminationStatus == 0 {
                    completion(.success(outputURL))
                    self.isBurning = false
                } else {
                    let errorLines = combinedOutput.components(separatedBy: "\n")
                        .filter { $0.contains("Error") || $0.contains("error") || $0.contains("failed") }
                        .prefix(5)
                        .joined(separator: "\n")
                    let errorMsg = errorLines.isEmpty ? String(combinedOutput.suffix(500)) : errorLines
                    
                    let fullCommand = "\(process.executableURL?.path ?? "ffmpeg") \(process.arguments?.joined(separator: " ") ?? "")"
                    completion(.failure(NSError(domain: "BurnService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "FFmpeg failed: \(errorMsg)\n\nCommand: \(fullCommand)"])))
                    self.isBurning = false
                }
            }
        }
    }
    
    func cancel() {
        burnProcess?.terminate()
        isBurning = false
        progress = 0
    }
    
    private func saveSubtitlesToTempSRT(_ subtitles: [SubtitleSegment], bilingual: Bool) throws -> URL {
        let srtURL = URL(fileURLWithPath: "/tmp/subtitle_\(UUID().uuidString).srt")
        
        var srtContent = ""
        for (index, seg) in subtitles.enumerated() {
            let start = formatSRTTime(seg.start)
            let end = formatSRTTime(seg.end)
            var text = seg.text
            if bilingual, let t = seg.translation { text += "\n\(t)" }
            srtContent += "\(index + 1)\n\(start) --> \(end)\n\(text)\n\n"
        }
        
        try srtContent.write(to: srtURL, atomically: true, encoding: .utf8)
        log("SRT saved: \(srtURL.path)")
        return srtURL
    }
    
    private func createOutputURL(for videoURL: URL, config: BurnConfig) throws -> URL {
        let folder: URL
        if let selected = config.outputFolder {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: selected.path, isDirectory: &isDir) && isDir.boolValue {
                folder = selected
            } else {
                folder = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
            }
        } else {
            folder = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        }
        
        let ext = config.videoCodec == .prores ? "mov" : config.outputFormat.fileExtension
        let outputPath = "\(folder.path)/burned_\(UUID().uuidString).\(ext)"
        let url = URL(fileURLWithPath: outputPath)
        log("Output path: \(url.path)")
        return url
    }
    
    private func formatSRTTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let millis = Int((seconds * 1_000).truncatingRemainder(dividingBy: 1_000))
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        return String(format: "%02d:%02d:%02d,%03d", h, m, s, millis)
    }
    
    private func updateProgress(from line: String) {
        if let timeRange = line.range(of: "time=") {
            let afterTime = line[timeRange.upperBound...]
            if let spaceIdx = afterTime.firstIndex(of: " ") ?? afterTime.firstIndex(of: "\n") {
                let timeStr = String(afterTime[..<spaceIdx])
                if let seconds = parseFFmpegTime(timeStr) {
                    progress = seconds
                }
            }
        }
    }
    
private nonisolated func parseFFmpegTime(_ timeStr: String) -> Double? {
        let components = timeStr.split(separator: ":")
        guard components.count == 3 else { return nil }
        let h = Double(components[0]) ?? 0
        let m = Double(components[1]) ?? 0
        let s = Double(components[2]) ?? 0
        return h * 3600 + m * 60 + s
    }
    
    fileprivate func log(_ message: String) {
        logger.info("\(message)")
        os_log("%{public}@", message)
    }
    
    private func findFFmpeg() throws -> URL {
        // Try bundled in App Bundle first
        if let bundledURL = Bundle.main.url(forResource: "ffmpeg", withExtension: nil), FileManager.default.fileExists(atPath: bundledURL.path) {
            log("Using bundled ffmpeg: \(bundledURL.path)")
            return bundledURL
        }
        // Try at /tmp (legacy location)
        if FileManager.default.fileExists(atPath: "/tmp/ffmpeg-darwin") {
            return URL(fileURLWithPath: "/tmp/ffmpeg-darwin")
        }
        // Try Homebrew
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/ffmpeg") {
            return URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
        }
        throw NSError(domain: "BurnService", code: 1, userInfo: [NSLocalizedDescriptionKey: "FFmpeg not found"])
    }
}

private let logger = Logger(subsystem: "com.subscript.app", category: "BurnService")

private func log(_ message: String) {
    logger.info("\(message)")
    os_log("%{public}@", message)
}