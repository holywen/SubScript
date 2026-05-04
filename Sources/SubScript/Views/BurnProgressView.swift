import SwiftUI
import Combine

struct BurnProgressView: View {
    @Bindable var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var isProcessing = false
    @State private var resultURL: URL?
    @State private var errorMessage: String?
    @State private var progressPercent: Double = 0
    @State private var currentTimeText: String = "00:00"
    @State private var timerCancellable: AnyCancellable?
    @State private var isDone = false

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text(isDone ? String(localized: "burn_progress_title_done") : String(localized: "burn_progress_title_processing"))
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 8) {
                ProgressView(value: progressPercent)
                    .progressViewStyle(.linear)
                    .frame(width: 200)
                
                Text(currentTimeText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                
                Text("\(Int(progressPercent * 100))%")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(.tint)
            }
            .opacity(resultURL != nil ? 0 : 1)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }

            if let url = resultURL {
                Text(String(localized: "burn_progress_done"))
                    .font(.headline)
                    .foregroundStyle(.green)
                
                Button(String(localized: "burn_progress_show_in_finder")) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .buttonStyle(.borderedProminent)
            }

            Button(isProcessing ? String(localized: "burn_progress_cancel") : String(localized: "burn_progress_close")) {
                if isProcessing {
                    BurnService.shared.cancel()
                }
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding(40)
        .frame(minWidth: 300, minHeight: 300)
        .onAppear {
            startBurn()
            timerCancellable = Timer.publish(every: 0.3, on: .main, in: .common)
                .autoconnect()
                .sink { _ in
                    let burning = BurnService.shared.isBurning
                    let progress = BurnService.shared.progress
                    
                    let current = Int(progress)
                    let m = current / 60
                    let s = current % 60
                    self.currentTimeText = String(format: "%02d:%02d", m, s)
                    
if progress > 0 {
                        let fraction = min(progress / 360, 0.99)
                        self.progressPercent = fraction
                    }

                    if !burning && self.resultURL != nil {
                        self.progressPercent = 1.0
                        self.isDone = true
                    }
                    
                    self.isProcessing = burning
                }
        }
    }
    
    private func startBurn() {
        guard let videoURL = appState.mediaURL else {
            errorMessage = String(localized: "burn_error_no_video")
            return
        }

        isProcessing = true
        
        BurnService.shared.burnSubtitles(
            videoURL: videoURL,
            subtitles: appState.subtitles,
            config: appState.burnConfig,
            bilingual: appState.showBilingual
        ) { result in
            Task { @MainActor in
                self.isProcessing = false
                switch result {
                case .success(let url):
                    self.resultURL = url
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}