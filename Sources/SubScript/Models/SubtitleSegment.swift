import Foundation

struct SubtitleSegment: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var start: Double
    var end: Double
    var translation: String?
    var speaker: String?
    var confidence: Double?

    init(
        id: UUID = UUID(),
        text: String,
        start: Double,
        end: Double,
        translation: String? = nil,
        speaker: String? = nil,
        confidence: Double? = nil
    ) {
        self.id = id
        self.text = text
        self.start = start
        self.end = end
        self.translation = translation
        self.speaker = speaker
        self.confidence = confidence
    }

    var duration: Double { end - start }

    var startSRT: String { formatSRT(start) }
    var endSRT:   String { formatSRT(end) }

    var startVTT: String { startSRT.replacingOccurrences(of: ",", with: ".") }
    var endVTT:   String { endSRT.replacingOccurrences(of: ",", with: ".") }

    private func formatSRT(_ t: Double) -> String {
        let h  = Int(t / 3600)
        let m  = Int((t.truncatingRemainder(dividingBy: 3600)) / 60)
        let s  = Int(t.truncatingRemainder(dividingBy: 60))
        let ms = Int((t.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d,%03d", h, m, s, ms)
    }
}