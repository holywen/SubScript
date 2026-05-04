import Foundation

struct ExportService {

    struct Options {
        var format: Format = .srt
        var withTimestamps: Bool = true
        var withSpeakerLabels: Bool = false
        var bilingual: Bool = false

        enum Format: String, CaseIterable {
            case srt, vtt, txt, ass, ssa, sbv, csv, lrc, ttml
            
            var fileExtension: String {
                switch self {
                case .srt: return "srt"
                case .vtt: return "vtt"
                case .txt: return "txt"
                case .ass, .ssa: return "ass"
                case .sbv: return "sbv"
                case .csv: return "csv"
                case .lrc: return "lrc"
                case .ttml: return "ttml"
                }
            }
            
            var displayName: String {
                switch self {
                case .srt: return "SRT (SubRip)"
                case .vtt: return "VTT (WebVTT)"
                case .txt: return "TXT (纯文本)"
                case .ass: return "ASS (高级字幕)"
                case .ssa: return "SSA (SubStation Alpha)"
                case .sbv: return "SBV (SubViewer)"
                case .csv: return "CSV"
                case .lrc: return "LRC (歌词)"
                case .ttml: return "TTML (Timed Text)"
                }
            }
            
            var supportsTimestamps: Bool {
                switch self {
                case .txt, .csv, .lrc: return false
                default: return true
                }
            }
        }
    }

    static func export(
        subtitles: [SubtitleSegment],
        options: Options
    ) throws -> (data: Data, baseName: String, ext: String) {
        let content: String
        let ext = options.format.fileExtension

        switch options.format {
        case .srt: content = makeSRT(subtitles, options: options)
        case .vtt: content = makeVTT(subtitles, options: options)
        case .txt: content = makeTXT(subtitles, options: options)
        case .ass, .ssa: content = makeASS(subtitles, options: options)
        case .sbv: content = makeSBV(subtitles, options: options)
        case .csv: content = makeCSV(subtitles, options: options)
        case .lrc: content = makeLRC(subtitles, options: options)
        case .ttml: content = makeTTML(subtitles, options: options)
        }

        guard let data = content.data(using: .utf8)
        else { throw ExportError.encodingFailed }

        return (data, "subtitles", ext)
    }

    // MARK: - Encoders

    private static func makeSRT(_ subtitles: [SubtitleSegment], options: Options) -> String {
        subtitles.enumerated().map { index, sub in
            var text = sub.text
            if options.bilingual, let translation = sub.translation { text += "\n\(translation)" }
            if options.withSpeakerLabels, let speaker = sub.speaker { text = "[\(speaker)] \(text)" }
            return "\(index + 1)\n\(sub.startSRT) --> \(sub.endSRT)\n\(text)"
        }.joined(separator: "\n\n")
    }

    private static func makeVTT(_ subtitles: [SubtitleSegment], options: Options) -> String {
        var lines = ["WEBVTT", ""]
        for (_, sub) in subtitles.enumerated() {
            lines.append("")
            lines.append("\(sub.startVTT) --> \(sub.endVTT)")
            var text = sub.text
            if options.bilingual, let t = sub.translation { text += "\n\(t)" }
            if options.withSpeakerLabels, let speaker = sub.speaker { text = "[\(speaker)] \(text)" }
            lines.append(text)
        }
        return lines.joined(separator: "\n")
    }

    private static func makeTXT(_ subtitles: [SubtitleSegment], options: Options) -> String {
        subtitles.map { sub in
            let text = options.bilingual ? "\(sub.text)\n\(sub.translation ?? "")" : sub.text
            if options.withTimestamps {
                return "[\(sub.startSRT)] \(text)"
            }
            return text
        }.joined(separator: "\n")
    }

    private static func makeASS(_ subtitles: [SubtitleSegment], options: Options) -> String {
        let header = """
        [Script Info]
        ScriptType: v4.00+
        PlayResX: 1920
        PlayResY: 1080

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, Bold, Italic, Alignment, MarginV
        Style: Default,PingFang SC,56,&H00FFFFFF,0,0,2,60

        [Events]
        Format: Layer, Start, End, Style, Text
        """
        let events = subtitles.map { sub in
            var text = sub.text
            if options.bilingual, let translation = sub.translation { text += "\\N\(translation)" }
            if options.withSpeakerLabels, let speaker = sub.speaker { text = "[\(speaker)] \(text)" }
            return "Dialogue: 0,\(formatASS(sub.start)),\(formatASS(sub.end)),Default,\(text)"
        }.joined(separator: "\n")
        return header + "\n" + events
    }

    private static func makeSBV(_ subtitles: [SubtitleSegment], options: Options) -> String {
        subtitles.enumerated().map { index, sub in
            var text = sub.text
            if options.bilingual, let translation = sub.translation { text += "\n\(translation)" }
            if options.withSpeakerLabels, let speaker = sub.speaker { text = "[\(speaker)] \(text)" }
            return "\(index)\n\(formatTimeSBV(sub.start)),\(formatTimeSBV(sub.end))\n\(text)"
        }.joined(separator: "\n\n")
    }

    private static func makeLRC(_ subtitles: [SubtitleSegment], options: Options) -> String {
        subtitles.map { sub in
            var text = sub.text
            if options.bilingual, let translation = sub.translation { text += " / \(translation)" }
            if options.withSpeakerLabels, let speaker = sub.speaker { text = "[\(speaker)] \(text)" }
            return "[\(formatTimeLRC(sub.start))]\(text)"
        }.joined(separator: "\n")
    }

    private static func makeCSV(_ subtitles: [SubtitleSegment], options: Options) -> String {
        var lines = ["Index,Start,End,Text"]
        for (index, sub) in subtitles.enumerated() {
            var text = sub.text
            if options.bilingual, let translation = sub.translation { text += " | \(translation)" }
            if options.withSpeakerLabels, let speaker = sub.speaker { text = "[\(speaker)] \(text)" }
            let escapedText = "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
            lines.append("\(index + 1),\(sub.start),\(sub.end),\(escapedText)")
        }
        return lines.joined(separator: "\n")
    }

    private static func makeTTML(_ subtitles: [SubtitleSegment], options: Options) -> String {
        var body = ""
        for (index, sub) in subtitles.enumerated() {
            var text = sub.text
            if options.bilingual, let translation = sub.translation { text += " " + translation }
            if options.withSpeakerLabels, let speaker = sub.speaker { text = "[\(speaker)] \(text)" }
            body += "    <p begin=\"\(formatTimeTTML(sub.start))\" end=\"\(formatTimeTTML(sub.end))\" bx=\"\(index)\">\(text)</p>\n"
        }
        return """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <tt xmlns=\"http://www.w3.org/ns/ttml\" xml:lang=\"en\">
          <head>
            <styling>
              <style xml:id=\"S1\" tts:textAlign=\"center\" tts:fontSize=\"16px\"/>
            </styling>
          </head>
          <body>
            <div>
        \(body)
            </div>
          </body>
        </tt>
        """
    }

    // MARK: - Time Formatters

    private static func formatASS(_ t: Double) -> String {
        let h = Int(t / 3600)
        let m = Int((t.truncatingRemainder(dividingBy: 3600)) / 60)
        let s = t.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%02d:%05.2f", h, m, s)
    }

    private static func formatTimeSBV(_ t: Double) -> String {
        let h = Int(t / 3600)
        let m = Int((t.truncatingRemainder(dividingBy: 3600)) / 60)
        let s = t.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%02d:%06.3f", h, m, s)
    }

    private static func formatTimeLRC(_ t: Double) -> String {
        let m = Int((t / 60).truncatingRemainder(dividingBy: 60))
        let s = Int(t.truncatingRemainder(dividingBy: 60))
        let ms = Int((t * 100).truncatingRemainder(dividingBy: 100))
        return String(format: "%02d:%02d.%02d", m, s, ms)
    }

    private static func formatTimeTTML(_ t: Double) -> String {
        let h = Int(t / 3600)
        let m = Int((t.truncatingRemainder(dividingBy: 3600)) / 60)
        let s = t.truncatingRemainder(dividingBy: 60)
        return String(format: "%02d:%02d:%06.3f", h, m, s)
    }

    enum ExportError: Error {
        case encodingFailed
    }
}