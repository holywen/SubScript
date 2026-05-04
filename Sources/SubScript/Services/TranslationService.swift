import Foundation
import MADLADTranslation
import Qwen3Chat

private let logger = AppLogger.shared

enum TranslationLanguage: String, CaseIterable, Identifiable, Codable {
    case english    = "en"
    case japanese = "ja"
    case korean   = "ko"
    case spanish  = "es"
    case french   = "fr"
    case german  = "de"
    case arabic   = "ar"
    case portuguese = "pt"
    case russian  = "ru"
    case thai    = "th"
    case vietnamese = "vi"
    case indonesian = "id"
    case chinese = "zh"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english:    return "English"
        case .japanese:  return "日本語"
        case .korean:    return "한국어"
        case .spanish:    return "Español"
        case .french:    return "Français"
        case .german:    return "Deutsch"
        case .arabic:    return "العربية"
        case .portuguese: return "Português"
        case .russian:   return "Русский"
        case .thai:      return "ไทย"
        case .vietnamese: return "Tiếng Việt"
        case .indonesian: return "Indonesia"
        case .chinese:   return "中文"
        }
    }

    var flag: String {
        switch self {
        case .english:    return "🇬🇧"
        case .japanese:  return "🇯🇵"
        case .korean:    return "🇰🇷"
        case .spanish:   return "🇪🇸"
        case .french:    return "🇫🇷"
        case .german:    return "🇩🇪"
        case .arabic:    return "🇸🇦"
        case .portuguese: return "🇧🇷"
        case .russian:   return "🇷🇺"
        case .thai:      return "🇹🇭"
        case .vietnamese: return "🇻🇳"
        case .indonesian: return "🇮🇩"
        case .chinese:   return "🇨🇳"
        }
    }
}

actor TranslationService {
    private var madlad: MADLADTranslator?
    private var isLoaded = false
    private var isLoading = false
    private var loadError: Error?
    private var loadedQuantization: String?

    enum TranslationEvent: Sendable {
        case progress(current: Int, total: Int, percent: Double)
        case partialResult(index: Int, translation: String)
        case completed([SubtitleSegment])
        case failed(String)
    }

    func getStatus() -> (loaded: Bool, loading: Bool, error: String?) {
        return (isLoaded, isLoading, loadError?.localizedDescription)
    }

    func loadModels(quantization: MADLADTranslator.Quantization) async throws {
        let needsReload = isLoaded && loadedQuantization != quantization.rawValue
        if needsReload {
            logger.info("Translation quantization changed, reloading model...", module: .translation)
            madlad = nil
            isLoaded = false
            loadedQuantization = nil
        }
        guard !isLoaded else { return }
        guard !isLoading else {
            try await Task.sleep(nanoseconds: 500_000_000)
            if isLoaded { return }
            if let err = loadError { throw err }
            throw TranslationError.modelLoadingFailed("Model is loading...")
        }

        isLoading = true

        do {
            self.madlad = try await MADLADTranslator.fromPretrained(quantization: quantization)
            self.loadedQuantization = quantization.rawValue
            isLoaded = true
            logger.info("MADLAD model loaded (\(quantization.rawValue)) successfully", module: .translation)
        } catch {
            loadError = error
            logger.error("Failed to load MADLAD: \(error)", module: .translation)
            throw error
        }
        isLoading = false
    }

    func translateSubtitles(
        subtitles: [SubtitleSegment],
        targetLang: TranslationLanguage
    ) -> AsyncStream<TranslationEvent> {
        AsyncStream { continuation in
            let task = Task {
                await self.runTranslation(
                    subtitles: subtitles,
                    targetLang: targetLang,
                    continuation: continuation
                )
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func runTranslation(
        subtitles: [SubtitleSegment],
        targetLang: TranslationLanguage,
        continuation: AsyncStream<TranslationEvent>.Continuation
    ) async {
        guard let translator = madlad else {
                continuation.yield(.failed(String(localized: "translation_model_not_loaded")))
            continuation.finish()
            return
        }

        guard !subtitles.isEmpty else {
                continuation.yield(.failed(String(localized: "translation_no_subtitles")))
            continuation.finish()
            return
        }

        var results = subtitles
            let batchSize = 1

            logger.info("Starting translation: \(subtitles.count) segments → \(targetLang.rawValue)", module: .translation)

            for batchStart in stride(from: 0, to: subtitles.count, by: batchSize) {
                try? Task.checkCancellation()

                let batchEnd = min(batchStart + batchSize, subtitles.count)
                let batch = Array(subtitles[batchStart..<batchEnd])
                let rawText = batch.first?.text ?? ""

            logger.info("[T:\(batchStart)] Translating → \(targetLang.rawValue)", module: .translation)
            logger.info("[T:\(batchStart)] Input: \(rawText.prefix(200))", module: .translation)

            do {
                let sampling = TranslationSamplingConfig(
                    temperature: 0.1,
                    topK: 1,
                    topP: 1.0,
                    maxTokens: 512,
                    repetitionPenalty: 1.5
                )
                let translated = try translator.translate(rawText, to: targetLang.rawValue, sampling: sampling)
                logger.info("[T:\(batchStart)] Raw output: \(String(translated.prefix(500)))", module: .translation)
                let trimmed = translated.trimmingCharacters(in: .whitespacesAndNewlines)

                for (i, segment) in batch.enumerated() {
                    let globalIndex = batchStart + i
                    let translation = i == 0 ? trimmed : trimmed
                    let snippet = translation.prefix(60)
                    logger.info("[T:\(globalIndex)] \"\(snippet)...\"", module: .translation)
                    if globalIndex < results.count {
                        results[globalIndex].translation = translation

                        continuation.yield(.partialResult(
                            index: globalIndex,
                            translation: translation
                        ))

                        let percent = Double(globalIndex + 1) / Double(subtitles.count)
                        continuation.yield(.progress(
                            current: globalIndex + 1,
                            total: subtitles.count,
                            percent: percent
                        ))
                    } else {
                        logger.info("[T:\(globalIndex)] Index out of bounds (results.count=\(results.count))", module: .translation)
                    }
                }
            } catch {
                logger.error("Translation failed: \(error)", module: .translation)
                continuation.yield(.failed(String(format: String(localized: "translation_failed"), error.localizedDescription)))
                continuation.finish()
                return
            }
        }

        logger.info("Translation complete! \(results.count) segments translated", module: .translation)
        continuation.yield(.completed(results))
        continuation.finish()
    }

    enum TranslationError: Error, LocalizedError {
        case modelLoadingFailed(String)

        var errorDescription: String? {
            switch self {
            case .modelLoadingFailed(let m): return String(format: String(localized: "translation_model_loading_failed"), m)
            }
        }
    }
}
