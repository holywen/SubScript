import Foundation

enum SentenceSplitter {

    static let maxCharsPerLine = 18
    static let maxDurationPerLine = 7.0

    struct WordTimestamp {
        let word: String
        let start: Double
        let end: Double
    }

    static func split(
        text: String,
        words: [WordTimestamp],
        chunkStart: Double,
        chunkEnd: Double
    ) -> [SubtitleSegment] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let sentences = splitByPunctuation(trimmed)
        let lines = sentences.flatMap { forceSplit($0, maxChars: maxCharsPerLine) }

        guard !lines.isEmpty else { return [] }

        if !words.isEmpty {
            return alignWithWordTimestamps(lines: lines, words: words)
        } else {
            return alignProportional(lines: lines, start: chunkStart, end: chunkEnd)
        }
    }

    private static func splitByPunctuation(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""

        for char in text {
            current.append(char)
            if "。？！…\n".contains(char) {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { result.append(trimmed) }
                current = ""
            }
        }

        if !current.trimmingCharacters(in: .whitespaces).isEmpty {
            result.append(current)
        }

        var final: [String] = []
        for seg in result {
            if seg.count <= maxCharsPerLine {
                final.append(seg)
            } else {
                let parts = seg.components(separatedBy: CharacterSet(charactersIn: "，、；"))
                final.append(contentsOf: parts.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
            }
        }

        if final.isEmpty { final = [text] }
        return final
    }

    private static func forceSplit(_ text: String, maxChars: Int) -> [String] {
        guard text.count > maxChars else { return [text] }
        var result: [String] = []
        var startIndex = text.startIndex
        while startIndex < text.endIndex {
            let endIndex = text.index(startIndex, offsetBy: maxChars,
                                       limitedBy: text.endIndex) ?? text.endIndex
            result.append(String(text[startIndex..<endIndex]))
            startIndex = endIndex
        }
        return result
    }

    private static func alignWithWordTimestamps(
        lines: [String],
        words: [WordTimestamp]
    ) -> [SubtitleSegment] {
        var result: [SubtitleSegment] = []
        var wordIdx = 0

        for line in lines {
            let charCount = line.replacingOccurrences(of: " ", with: "").count
            var lineStart: Double?
            var lineEnd: Double = 0
            var matched = 0

            while wordIdx < words.count && matched < charCount {
                let w = words[wordIdx]
                if lineStart == nil { lineStart = w.start }
                lineEnd = w.end
                matched += w.word.count
                wordIdx += 1
            }

            if let start = lineStart {
                result.append(SubtitleSegment(
                    text: line,
                    start: start,
                    end: max(lineEnd, start + 0.5)
                ))
            }
        }

        return result
    }

    private static func alignProportional(
        lines: [String],
        start: Double,
        end: Double
    ) -> [SubtitleSegment] {
        let totalChars = lines.reduce(0) { $0 + $1.count }
        let totalDuration = end - start
        var cursor = start

        return lines.map { line in
            let ratio = totalChars > 0 ? Double(line.count) / Double(totalChars) : 1.0 / Double(lines.count)
            let duration = totalDuration * ratio
            let seg = SubtitleSegment(text: line, start: cursor, end: cursor + duration)
            cursor += duration
            return seg
        }
    }
}