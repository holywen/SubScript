import SwiftUI

struct ExportView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFormat: ExportService.Options.Format = .srt
    @State private var withTimestamps = true
    @State private var withSpeakerLabels = false
    @State private var isExporting = false
    @State private var exportError: String?

    var body: some View {
        VStack(spacing: 24) {
            header
            
            ScrollView {
                VStack(spacing: 24) {
                    formatPicker
                    optionsGrid
                }
            }
            
            actionButtons
        }
        .padding(24)
        .frame(width: 400, height: 450)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(String(localized: "export_title"))
                .font(.title2)
                .fontWeight(.semibold)

            Text(String(format: String(localized: "export_subtitles_count"), appState.subtitles.count))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var formatPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "export_format_label"))
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(ExportService.Options.Format.allCases, id: \.self) { format in
                    formatButton(format)
                }
            }
        }
    }

    private func formatButton(_ format: ExportService.Options.Format) -> some View {
        Button {
            selectedFormat = format
        } label: {
            VStack(spacing: 4) {
                Image(systemName: formatIcon(format))
                    .font(.title2)

                Text(format.displayName.uppercased())
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                selectedFormat == format
                    ? Color.blue.opacity(0.1)
                    : Color(nsColor: .controlBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selectedFormat == format ? Color.blue : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func formatIcon(_ format: ExportService.Options.Format) -> String {
        switch format {
        case .srt: return "captions.bubble"
        case .vtt: return "globe"
        case .txt: return "doc.text"
        case .ass, .ssa: return "movie"
        case .sbv: return "captions.bubble.fill"
        case .csv: return "tablecells"
        case .lrc: return "music.note"
        case .ttml: return "doc.richtext"
        }
    }

    private var optionsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "export_options_label"))
                .font(.headline)

            Toggle(String(localized: "export_include_timestamps"), isOn: $withTimestamps)
                .disabled(!selectedFormat.supportsTimestamps)

            Toggle(String(localized: "export_speaker_labels"), isOn: $withSpeakerLabels)

            Toggle("双语字幕 (Pro)", isOn: $appState.showBilingual)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(String(localized: "export_cancel")) {
                dismiss()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)

            Button(String(localized: "export_button")) {
                exportFile()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isExporting)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func exportFile() {
        isExporting = true
        
        let options = ExportService.Options(
            format: selectedFormat,
            withTimestamps: withTimestamps && selectedFormat != .ass,
            withSpeakerLabels: withSpeakerLabels,
            bilingual: appState.showBilingual
        )
        
        do {
            let (data, baseName, ext) = try ExportService.export(subtitles: appState.subtitles, options: options)
        
            let panel = NSSavePanel()
            panel.nameFieldStringValue = baseName
            panel.allowedContentTypes = [.init(filenameExtension: ext) ?? .data]
        
            if panel.runModal() == .OK, let url = panel.url {
                try data.write(to: url)
                dismiss()
            }
        } catch {
            exportError = error.localizedDescription
        }
        
        isExporting = false
    }
}