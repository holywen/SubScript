import SwiftUI
import UniformTypeIdentifiers

struct HomeView: View {
    @Environment(AppState.self) private var appState
    
    private let supportedTypes: [UTType] = [.item]
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 32) {
                headerSection
                
                dropZone
                
                if !appState.recentFiles.isEmpty {
                    recentFilesSection
                }
                
                Spacer()
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
            .onAppear {
                appState.loadRecentFiles()
            }
            
            Button {
                appState.showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor), in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .padding(20)
        }
        .sheet(isPresented: Binding(
            get: { appState.showSettings },
            set: { appState.showSettings = $0 }
        )) {
            SettingsView(appState: appState)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(String(localized: "home_title"))
                .font(.title2)
                .fontWeight(.semibold)
                .lineLimit(1)
            
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
    
    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 2, dash: [10]))
                )
            
                VStack(spacing: 16) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(.blue)
                    
                    Text(String(localized: "home_drop_zone"))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    Button {
                        openFilePicker()
                    } label: {
                        Text(String(localized: "home_browse_button"))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
        }
        .frame(height: 300)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    private var recentFilesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "home_recent_files"))
                .font(.headline)
                .padding(.bottom, 4)
            
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(appState.recentFiles) { file in
                        RecentFileRow(file: file) {
                            handleRecentFileTap(file)
                        } onRemove: {
                            appState.removeRecentFile(file)
                        }
                    }
                }
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadObject(ofClass: URL.self) { url, error in
            if let url = url {
                Task { @MainActor in
                    await appState.startTranscription(url: url)
                }
            }
        }
        return true
    }
    
    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = supportedTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            Task { @MainActor in
                await appState.startTranscription(url: url)
            }
        }
    }
    
    private func handleRecentFileTap(_ file: RecentFile) {
        Task { @MainActor in
            appState.loadRecentFiles()
            if let cached = loadCachedSubtitles(for: file.url) {
                appState.mediaURL = file.url
                appState.subtitles = cached
                appState.screen = .results
            } else {
                await appState.startTranscription(url: file.url)
            }
        }
    }
    
    private func loadCachedSubtitles(for url: URL) -> [SubtitleSegment]? {
        let key = "subtitles_\(url.lastPathComponent)"
        if let data = UserDefaults.standard.data(forKey: key),
           let subs = try? JSONDecoder().decode([SubtitleSegment].self, from: data) {
            return subs
        }
        return nil
    }
}

struct RecentFileRow: View {
    let file: RecentFile
    let action: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: file.isCompleted ? "checkmark.circle.fill" : "doc")
                .foregroundStyle(file.isCompleted ? .green : .secondary)
                .font(.system(size: 16))
            
            Text(file.url.lastPathComponent)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary.opacity(0.5))
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
        .help(file.url.path)
    }
}
