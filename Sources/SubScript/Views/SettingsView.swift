import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var appState: AppState
    
    @State private var pendingSize: AppState.ASRModelSize
    @State private var pendingPrecision: AppState.ASRPrecision
    @State private var pendingVadModel: AppState.VADModel
    @State private var pendingLanguage: AppState.Language
    @State private var pendingDialect: AppState.ChineseDialect
    @State private var pendingTranslationQuantization: AppState.TranslationQuantization
    
    init(appState: AppState) {
        self.appState = appState
        _pendingSize = State(initialValue: appState.asrModelSize)
        _pendingPrecision = State(initialValue: appState.asrPrecision)
        _pendingVadModel = State(initialValue: appState.vadModel)
        _pendingLanguage = State(initialValue: appState.transcriptionLanguage)
        _pendingDialect = State(initialValue: appState.transcriptionDialect)
        _pendingTranslationQuantization = State(initialValue: appState.translationQuantization)
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("settings_language")) {
                    Picker("settings_language_label", selection: $pendingLanguage) {
                        ForEach(AppState.Language.allCases) { lang in
                            Text(lang.localizedName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    if pendingLanguage == .zh {
                        Picker("settings_dialect_label", selection: $pendingDialect) {
                            ForEach(AppState.ChineseDialect.allCases) { dialect in
                                Text(dialect.localizedName).tag(dialect)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section(header: Text("settings_asr_model")) {
                    Picker("settings_size", selection: $pendingSize) {
                        ForEach(AppState.ASRModelSize.allCases) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Picker("settings_precision", selection: $pendingPrecision) {
                        ForEach(AppState.ASRPrecision.allCases) { precision in
                            Text(precision.rawValue).tag(precision)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("settings_vad_model")) {
                    Picker("settings_vad_engine", selection: $pendingVadModel) {
                        ForEach(AppState.VADModel.allCases) { model in
                            Text(model.rawValue).tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("settings_translation_model")) {
                    Picker("settings_translation_quantization", selection: $pendingTranslationQuantization) {
                        ForEach(AppState.TranslationQuantization.allCases) { q in
                            Text(q.rawValue).tag(q)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle(Text("settings_title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("settings_cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("settings_apply") {
                        applySettings()
                    }
                    .disabled(ModelManager.shared.isLoading)
                }
            }
            .overlay {
                if ModelManager.shared.isLoading {
                    ZStack {
                        Color.black.opacity(0.2).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("settings_applying")
                                .font(.callout)
                                .foregroundColor(.primary)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private func applySettings() {
        appState.transcriptionLanguage = pendingLanguage
        appState.transcriptionDialect = pendingDialect
        appState.asrModelSize = pendingSize
        appState.asrPrecision = pendingPrecision
        appState.vadModel = pendingVadModel
        appState.translationQuantization = pendingTranslationQuantization
        appState.saveSettings()
        dismiss()
    }
}
