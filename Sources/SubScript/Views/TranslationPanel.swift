import SwiftUI
import Observation
import MADLADTranslation

struct TranslationPanel: View {
    @Binding var subtitles: [SubtitleSegment]
    @Bindable var appState: AppState
    @State private var vm = TranslationViewModel()
    @State private var targetLang = TranslationLanguage.english

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)

                Picker(String(localized: "translation_target_language"), selection: $targetLang) {
                    ForEach(TranslationLanguage.allCases) { lang in
                        Text("\(lang.flag) \(lang.displayName)")
                            .tag(lang)
                    }
                }
                .frame(width: 160)
                .disabled(vm.isTranslating)

                Spacer()

                if vm.isTranslating {
                    Button(String(localized: "translation_cancel")) { vm.cancelTranslation() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                } else {
                    Button {
                        let q = appState.translationQuantization == .int8 ? MADLADTranslator.Quantization.int8 : .int4
                        vm.loadModels(quantization: q)
                        vm.translateSubtitles(subtitles, to: targetLang) { [self] updated in
                            subtitles = updated
                            appState.saveSubtitlesToCache(updated)
                        }
                    } label: {
                        Label(String(localized: "translation_button"), systemImage: "translate")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            if vm.isModelLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(String(localized: "translation_loading_model"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 8)
            }

            if vm.isTranslating {
                VStack(spacing: 4) {
                    ProgressView(value: vm.progress)
                        .progressViewStyle(.linear)
                        .padding(.horizontal, 14)
                        .animation(.easeInOut(duration: 0.2), value: vm.progress)

                    Text(String(format: String(localized: "translation_progress"), vm.translatedCount, vm.totalCount))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
            }

            if let error = vm.error {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 8)
            }
        }
    }
}