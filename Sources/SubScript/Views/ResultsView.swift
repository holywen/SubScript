import SwiftUI
import AVKit
import AVFoundation

struct ResultsView: View {
    @Bindable var appState: AppState
    @State private var searchText = ""
    @State private var editingId: UUID?
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var wasPlayingBeforeDrag = false
    @State private var player: AVPlayer?
    @State private var currentTime: Double = 0
    @State private var dividerPosition: CGFloat = 0.70
    @State private var editText = ""
    @State private var editStart = ""
    @State private var editEnd = ""
    @FocusState private var isFocused: Bool
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                videoPanel
                    .frame(width: geometry.size.width * dividerPosition)
                
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 8)
                    .overlay(
                        Rectangle()
                            .fill(Color.gray.opacity(0.4))
                            .frame(width: 4)
                            .cornerRadius(2)
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                let delta = value.translation.width / geometry.size.width
                                dividerPosition = min(max(dividerPosition + delta, 0.2), 0.8)
                            }
                            .onEnded { _ in }
                    )
                
                subtitlePanel
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .focused($isFocused)
        .onAppear {
            isFocused = true
            if let url = appState.mediaURL {
                player = AVPlayer(url: url)
                setupTimeObserver()
            }
        }
    }
    
    private func setupTimeObserver() {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            DispatchQueue.main.async {
                self?.currentTime = time.seconds
            }
        }
    }

    private var videoPanel: some View {
        VStack(spacing: 16) {
            if let player = player {
                AVPlayerViewWrapper(player: player)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                VStack {
                    Image(systemName: "film")
                        .font(.system(size: 48))
                    Text(String(localized: "results_no_video"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            playbackControls

            Spacer()
        }
        .padding()
    }

    private var playbackControls: some View {
        VStack(spacing: 16) {
            if let last = appState.subtitles.last {
                let totalDuration = last.end
                let current = isDragging ? dragValue : currentTime
                
                HStack {
                    Text(formatTime(current))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(formatTime(totalDuration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 6)
                        
                        if let first = appState.subtitles.first {
                            ForEach(appState.subtitles) { segment in
                                let startX = geo.size.width * CGFloat(segment.start / max(totalDuration, 0.1))
                                let endX = geo.size.width * CGFloat(segment.end / max(totalDuration, 0.1))
                                Capsule()
                                    .fill(current >= segment.start && current <= segment.end ? Color.blue : Color.blue.opacity(0.3))
                                    .frame(width: max(endX - startX, 2), height: 6)
                                    .offset(x: startX)
                            }
                        }
                        
                        Capsule()
                            .fill(Color.blue)
                            .frame(width: geo.size.width * CGFloat(current / max(totalDuration, 0.1)), height: 6)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                            .offset(x: geo.size.width * CGFloat(current / max(totalDuration, 0.1)) - 7)
                    }
                    .frame(height: 20)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isDragging {
                                    wasPlayingBeforeDrag = appState.isPlaying
                                    isDragging = true
                                }
                                let ratio = min(max(value.location.x / geo.size.width, 0), 1)
                                dragValue = ratio * totalDuration
                            }
                            .onEnded { value in
                                let ratio = min(max(value.location.x / geo.size.width, 0), 1)
                                let targetTime = ratio * totalDuration
                                player?.seek(to: CMTime(seconds: targetTime, preferredTimescale: 600))
                                if wasPlayingBeforeDrag {
                                    player?.play()
                                    appState.isPlaying = true
                                } else {
                                    player?.pause()
                                    appState.isPlaying = false
                                }
                                isDragging = false
                            }
                    )
                }
                .frame(height: 20)
            }
            
            HStack(spacing: 24) {
                Button {
                    let targetTime = max(0, currentTime - 5)
                    player?.seek(to: CMTime(seconds: targetTime, preferredTimescale: 600))
                } label: {
                    Image(systemName: "gobackward.5")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.leftArrow, modifiers: .command)
                
                Button {
                    togglePlayPause()
                } label: {
                    Image(systemName: appState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space)
                .disabled(isSearchFocused)
                
                Button {
                    if let last = appState.subtitles.last {
                        let targetTime = min(last.end, currentTime + 5)
                        player?.seek(to: CMTime(seconds: targetTime, preferredTimescale: 600))
                    }
                } label: {
                    Image(systemName: "goforward.5")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.rightArrow, modifiers: .command)
                .disabled(isSearchFocused)
            }
            
                Picker(String(localized: "results_speed_label"), selection: $appState.playbackRate) {
                    Text("0.5x").tag(0.5)
                    Text("1x").tag(1.0)
                    Text("1.5x").tag(1.5)
                    Text("2x").tag(2.0)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
        }
    }

    private var subtitlePanel: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            TranslationPanel(subtitles: $appState.subtitles, appState: appState)

            Divider()

            subtitleList
        }
    }

    private var toolbar: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(String(localized: "results_search_placeholder"), text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onTapGesture {}
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: String(localized: "results_subtitles_count"), appState.subtitles.count))
                        .font(.headline)

                    if let last = appState.subtitles.last {
                        Text(String(format: String(localized: "results_duration"), formatTime(last.end)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button(String(localized: "results_export_button")) {
                    appState.showExportSheet = true
                }
                .buttonStyle(.bordered)

                if appState.isVideoFile {
                    Button(String(localized: "results_burn_button")) {
                        appState.showBurnOptions = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.blue)
                }
            }
            
            HStack {
                Toggle(String(localized: "results_show_bilingual"), isOn: $appState.showBilingual)
                Spacer()
            }
        }
        .padding()
    }

    private var subtitleList: some View {
        let currentHighlightTime = isDragging ? dragValue : currentTime
        let filtered = searchText.isEmpty
            ? appState.subtitles
            : appState.subtitles.filter { $0.text.localizedCaseInsensitiveContains(searchText) }

        return ScrollViewReader { proxy in
            List {
                ForEach(filtered) { segment in
                    subtitleRow(segment, highlightTime: currentHighlightTime)
                        .id(segment.id)
                        .listRowBackground(
                            currentHighlightTime >= segment.start && currentHighlightTime <= segment.end
                                ? Color.blue.opacity(0.1)
                                : Color.clear
                        )
                }
            }
            .listStyle(.plain)
            .onChange(of: currentHighlightTime) { _, _ in
                if let activeId = appState.subtitles.first(where: { currentHighlightTime >= $0.start && currentHighlightTime <= $0.end })?.id {
                    withAnimation {
                        proxy.scrollTo(activeId, anchor: .center)
                    }
                }
            }
        }
    }

    private func subtitleRow(_ segment: SubtitleSegment, highlightTime: Double) -> some View {
        
        return HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(highlightTime >= segment.start && highlightTime <= segment.end ? Color.blue : Color.clear)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 4) {
                if editingId == segment.id {
                    HStack(spacing: 4) {
                        TextField("start", text: $editStart)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 10, design: .monospaced))
                            .onTapGesture {}
                        Text("-")
                            .font(.system(size: 10))
                        TextField("end", text: $editEnd)
                            .frame(width: 60)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 10, design: .monospaced))
                            .onTapGesture {}
                    }
                    .foregroundStyle(.secondary)
                    
                    TextField("", text: $editText)
                        .textFieldStyle(.roundedBorder)
                        .onTapGesture {}
                        .onSubmit {
                            if let index = appState.subtitles.firstIndex(where: { $0.id == segment.id }) {
                                appState.subtitles[index].text = editText
                                if let s = Double(editStart) { appState.subtitles[index].start = s }
                                if let e = Double(editEnd) { appState.subtitles[index].end = e }
                            }
                            editingId = nil
                        }
                } else {
                    HStack(spacing: 4) {
                        Text(segment.startSRT)
                            .font(.system(size: 10, design: .monospaced))
                        Text("-")
                            .font(.system(size: 10))
                        Text(segment.endSRT)
                            .font(.system(size: 10, design: .monospaced))
                    }
                    .foregroundStyle(.secondary)
                    
                    Text(segment.text)
                        .font(.body)
                        .lineLimit(3)
                        .onTapGesture(count: 2) {
                            player?.pause()
                            appState.isPlaying = false
                            editText = segment.text
                            editStart = segment.startSRT
                            editEnd = segment.endSRT
                            editingId = segment.id
                        }
                }

                if appState.showBilingual, let translation = segment.translation {
                    Text(translation)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 8)

            Spacer()
        }
        .contentShape(Rectangle())
        .background(highlightTime >= segment.start && highlightTime <= segment.end ? Color.blue.opacity(0.1) : Color.clear)
        .onTapGesture {
            player?.seek(to: CMTime(seconds: segment.start, preferredTimescale: 600))
            if appState.isPlaying {
                player?.play()
            } else {
                player?.pause()
            }
        }
    }

    private func togglePlayPause() {
        if appState.isPlaying {
            player?.pause()
            appState.isPlaying = false
        } else {
            player?.play()
            appState.isPlaying = true
        }
    }

    private func confidenceBadge(_ confidence: Double) -> some View {
        let color: Color = confidence > 0.9 ? .green : (confidence > 0.7 ? .yellow : .red)
        return Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }

    private func formatTime(_ t: Double) -> String {
        let m = Int(t / 60)
        let s = Int(t.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", m, s)
    }
}

private struct AVPlayerViewWrapper: NSViewRepresentable {
    let player: AVPlayer?
    
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        return view
    }
    
    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        nsView.player = player
    }
}