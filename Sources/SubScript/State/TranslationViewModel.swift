import Foundation
import Observation
import MADLADTranslation

@Observable
@MainActor
final class TranslationViewModel {
    var isTranslating: Bool = false
    var progress: Double = 0
    var translatedCount: Int = 0
    var totalCount: Int = 0
    var error: String?

    var isModelLoading: Bool = false
    var isModelReady: Bool = false

    private let service: TranslationService = TranslationService()
    private var translateTask: Task<Void, Never>?

    func loadModels(quantization: MADLADTranslator.Quantization) {
        isModelLoading = true

        Task {
            do {
                try await service.loadModels(quantization: quantization)
                isModelReady = true
            } catch {
                    self.error = String(format: String(localized: "translation_model_loading_failed"), error.localizedDescription)
            }
            isModelLoading = false
        }
    }

    func translateSubtitles(
        _ subtitles: [SubtitleSegment],
        to targetLang: TranslationLanguage,
        onUpdate: @escaping ([SubtitleSegment]) -> Void
    ) {
        translateTask?.cancel()
        isTranslating = true
        progress = 0
        translatedCount = 0
        totalCount = subtitles.count
        error = nil

        translateTask = Task {
            var currentSubtitles = subtitles

            let stream = await service.translateSubtitles(
                subtitles: subtitles,
                targetLang: targetLang
            )

            for await event in stream {
                switch event {
                case .progress(let cur, let tot, let pct):
                    progress = pct
                    translatedCount = cur
                    totalCount = tot

                case .partialResult(let idx, let translation):
                    if idx < currentSubtitles.count {
                        currentSubtitles[idx].translation = translation
                        onUpdate(currentSubtitles)
                    }

                case .completed(let final):
                    onUpdate(final)
                    isTranslating = false

                case .failed(let err):
                    self.error = err
                    isTranslating = false
                }
            }
        }
    }

    func cancelTranslation() {
        translateTask?.cancel()
        isTranslating = false
        progress = 0
    }
}