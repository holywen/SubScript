import Foundation

struct TranscriptionJob: Identifiable {
    let id: UUID
    let sourceURL: URL
    var status: Status
    var progress: Double
    var currentStep: Step
    var subtitles: [SubtitleSegment]
    var error: String?
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        sourceURL: URL,
        status: Status = .queued,
        progress: Double = 0,
        currentStep: Step = .idle,
        subtitles: [SubtitleSegment] = [],
        error: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.status = status
        self.progress = progress
        self.currentStep = currentStep
        self.subtitles = subtitles
        self.error = error
        self.createdAt = createdAt
    }
    
    enum Status: String, Codable {
        case queued, running, done, failed, cancelled
    }
    
    enum Step: String, CaseIterable {
        case idle = "processing_preparing"
        case extractingAudio = "processing_reading"
        case runningVAD = "processing_vad"
        case transcribing = "processing_transcribing"
        case postProcessing = "processing_capturing"
        case done = "processing_done"
        
        var progressRange: ClosedRange<Double> {
            switch self {
            case .idle:            return 0.00...0.00
            case .extractingAudio: return 0.00...0.10
            case .runningVAD:      return 0.10...0.20
            case .transcribing:    return 0.20...0.92
            case .postProcessing:  return 0.92...0.99
            case .done:            return 1.00...1.00
            }
        }
    }
}
