import SwiftUI

struct ProcessingView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack(spacing: 32) {
            headerSection
            
            progressSection
            
            subtitlePreview
            
            Spacer()
            
            cancelButton
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            if let url = appState.mediaURL {
                Text(url.lastPathComponent)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                Text(url.fileSizeFormatted)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var progressSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: appState.currentJob?.progress ?? 0)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack(spacing: 2) {
                    Text("\(appState.subtitles.count)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("processing_subtitles_label")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 150, height: 150)
            
            VStack(spacing: 8) {
                if let job = appState.currentJob {
                    HStack(spacing: 12) {
                        statusBadge(for: job.currentStep)
                        
                        Text("\(Int(job.progress * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    
                    if job.currentStep == .idle && !ModelManager.shared.statusMessage.isEmpty {
                        Text(ModelManager.shared.statusMessage)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                            .transition(.opacity)
                            .id("model_status")
                    }
                }
            }
        }
    }
    
    private func statusBadge(for step: TranscriptionJob.Step) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.blue)
                .frame(width: 6, height: 6)
            
            Text(LocalizedStringKey(step.rawValue))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var subtitlePreview: some View {
        VStack(spacing: 8) {
            if let lastSubtitle = appState.subtitles.last {
                Text(lastSubtitle.text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            } else {
                Text("processing_waiting")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var cancelButton: some View {
        Button("processing_cancel") {
            appState.cancelTranscription()
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

extension URL {
    var fileSizeFormatted: String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64
        else { return "" }
        
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
