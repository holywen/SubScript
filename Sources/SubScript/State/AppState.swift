import Observation
import Foundation
import AVFoundation

@Observable
@MainActor
final class AppState {
 
    var screen: Screen = .home
    var currentJob: TranscriptionJob?
    var mediaURL: URL?
    var subtitles: [SubtitleSegment] = []
    var recentFiles: [RecentFile] = []
 
    var selectedSubtitleId: UUID?
    var playerCurrentTime: Double = 0
    var isPlaying = false
    var playbackRate: Double = 1.0
    var seekTarget: Double? = nil
    
    enum Language: String, CaseIterable, Identifiable {
        case auto = "auto"
        case zh = "zh"
        case en = "en"
        case yue = "yue"
        case ar = "ar"
        case de = "de"
        case fr = "fr"
        case es = "es"
        case pt = "pt"
        case id = "id"
        case it = "it"
        case ko = "ko"
        case ru = "ru"
        case th = "th"
        case vi = "vi"
        case ja = "ja"
        case tr = "tr"
        case hi = "hi"
        case ms = "ms"
        case nl = "nl"
        case sv = "sv"
        case da = "da"
        case fi = "fi"
        case pl = "pl"
        case cs = "cs"
        case fil = "fil"
        case fa = "fa"
        case el = "el"
        case hu = "hu"
        case mk = "mk"
        case ro = "ro"
        var id: String { self.rawValue }
        
        var localizedName: String {
            let key = "lang_\(self.rawValue)"
            return NSLocalizedString(key, bundle: .module, comment: "")
        }
    }
    
    enum ChineseDialect: String, CaseIterable, Identifiable {
        case mandarin = "mandarin"
        case anhui = "anhui"
        case dongbei = "dongbei"
        case fujian = "fujian"
        case gansu = "gansu"
        case guizhou = "guizhou"
        case hebei = "hebei"
        case henan = "henan"
        case hubei = "hubei"
        case hunan = "hunan"
        case jiangxi = "jiangxi"
        case ningxia = "ningxia"
        case shandong = "shandong"
        case shaanxi = "shaanxi"
        case shanxi = "shanxi"
        case sichuan = "sichuan"
        case tianjin = "tianjin"
        case yunnan = "yunnan"
        case zhejiang = "zhejiang"
        case cantoneseHK = "cantonese_hk"
        case cantoneseGD = "cantonese_gd"
        case wu = "wu"
        case minnan = "minnan"
        var id: String { self.rawValue }
        
        var localizedName: String {
            let key = "dialect_\(self.rawValue)"
            return NSLocalizedString(key, bundle: .module, comment: "")
        }
    }
    
    var transcriptionLanguage: Language = .auto
    var transcriptionDialect: ChineseDialect = .mandarin
    var modelMode: ModelManager.ModelMode = .quality
    
    var asrModelSize: ASRModelSize = .small
    var asrPrecision: ASRPrecision = .bit4
    var vadModel: VADModel = .silero
    var showSettings = false
    
    enum ASRModelSize: String, CaseIterable, Identifiable {
        case small = "0.6B (Balanced)"
        case large = "1.7B (High Quality)"
        var id: String { self.rawValue }
    }
    
    enum ASRPrecision: String, CaseIterable, Identifiable {
        case bit4 = "4-bit (Fast)"
        case bit8 = "8-bit (Balanced)"
        case bit16 = "16-bit (Precise)"
        var id: String { self.rawValue }
    }
    
    enum VADModel: String, CaseIterable, Identifiable {
        case silero = "Silero VAD (General)"
        case fireRed = "FireRed VAD (Multi-lang)"
        var id: String { self.rawValue }
    }
    
    enum TranslationQuantization: String, CaseIterable, Identifiable {
        case int4 = "4-bit (Fast)"
        case int8 = "8-bit (Quality)"
        var id: String { self.rawValue }
    }
    
    var translationQuantization: TranslationQuantization = .int8
 
    private var transcriptionTask: Task<Void, Never>?
    private var pipeline: StreamingPipeline?
    private var eventHandler: ((PipelineEvent) -> Void)?
 
    var isTranscribing: Bool {
        transcriptionTask != nil && currentJob?.status == .running
    }
    var showExportSheet = false
    var showBurnSheet = false
    var showBurnOptions = false
    var showBilingual = false
    var burnConfig = BurnConfig.default
    var totalWindows: Int = 0
 
    private let videoExtensions = ["mp4", "mov", "m4v", "avi", "mkv", "webm"]
    private let audioExtensions = ["mp3", "m4a", "wav", "aac", "flac", "ogg"]
 
    var isVideoFile: Bool {
        guard let url = mediaURL else { return false }
        let ext = url.pathExtension.lowercased()
        return videoExtensions.contains(ext) && !audioExtensions.contains(ext)
    }
 
    enum Screen {
        case home, processing, results, export
    }
 
    var activeSubtitleId: UUID? {
        subtitles.first {
            playerCurrentTime >= $0.start && playerCurrentTime <= $0.end
        }?.id
    }
 
    var totalDuration: Double {
        subtitles.last?.end ?? 0
    }
    
    init() {
        loadRecentFiles()
        loadSettings()
    }
 
    func addToRecentFiles(url: URL, isCompleted: Bool) {
        if let index = recentFiles.firstIndex(where: { $0.url == url }) {
            recentFiles[index].isCompleted = isCompleted
            recentFiles[index].lastOpenedAt = Date()
        } else {
            recentFiles.insert(RecentFile(url: url, isCompleted: isCompleted), at: 0)
        }
        if recentFiles.count > 5 {
            recentFiles = Array(recentFiles.prefix(5))
        }
        saveRecentFiles()
    }
 
    func removeRecentFile(_ file: RecentFile) {
        recentFiles.removeAll { $0.id == file.id }
        saveRecentFiles()
    }
    
    func loadRecentFiles() {
        if let data = UserDefaults.standard.data(forKey: "recentFiles"),
           let files = try? JSONDecoder().decode([RecentFile].self, from: data) {
            recentFiles = files.filter { FileManager.default.fileExists(atPath: $0.url.path) }
        }
    }
    
    func saveRecentFiles() {
        if let data = try? JSONEncoder().encode(recentFiles) {
            UserDefaults.standard.set(data, forKey: "recentFiles")
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(transcriptionLanguage.rawValue, forKey: "transcriptionLanguage")
        UserDefaults.standard.set(transcriptionDialect.rawValue, forKey: "transcriptionDialect")
        UserDefaults.standard.set(asrModelSize.rawValue, forKey: "asrModelSize")
        UserDefaults.standard.set(asrPrecision.rawValue, forKey: "asrPrecision")
        UserDefaults.standard.set(vadModel.rawValue, forKey: "vadModel")
        UserDefaults.standard.set(translationQuantization.rawValue, forKey: "translationQuantization")
    }
    
    func loadSettings() {
        if let langRaw = UserDefaults.standard.string(forKey: "transcriptionLanguage"),
           let lang = Language(rawValue: langRaw) {
            transcriptionLanguage = lang
        }
        if let dialectRaw = UserDefaults.standard.string(forKey: "transcriptionDialect"),
           let dialect = ChineseDialect(rawValue: dialectRaw) {
            transcriptionDialect = dialect
        }
        if let sizeRaw = UserDefaults.standard.string(forKey: "asrModelSize"),
           let size = ASRModelSize(rawValue: sizeRaw) {
            asrModelSize = size
        }
        if let precisionRaw = UserDefaults.standard.string(forKey: "asrPrecision"),
           let precision = ASRPrecision(rawValue: precisionRaw) {
            asrPrecision = precision
        }
        if let vadRaw = UserDefaults.standard.string(forKey: "vadModel"),
           let vad = VADModel(rawValue: vadRaw) {
            vadModel = vad
        }
        if let tqRaw = UserDefaults.standard.string(forKey: "translationQuantization"),
           let tq = TranslationQuantization(rawValue: tqRaw) {
            translationQuantization = tq
        }
    }
 
    func startTranscription(url: URL) async {
        mediaURL = url
        screen = .processing
        currentJob = TranscriptionJob(sourceURL: url)
        currentJob?.status = .running
 
        addToRecentFiles(url: url, isCompleted: false)
 
        await ModelManager.shared.loadModels(
            mode: modelMode,
            size: asrModelSize,
            precision: asrPrecision,
            vadType: vadModel
        )
 
        guard ModelManager.shared.isReady else {
            currentJob?.status = .failed
            currentJob?.error = ModelManager.shared.loadError
            return
        }
 
        let mm = ModelManager.shared
        let newPipeline = StreamingPipeline(asr: mm.asr!, vad: mm.vad!)
        self.pipeline = newPipeline
 
        let handler: @Sendable (PipelineEvent) -> Void = { [self] event in
            switch event {
            case .progress(let step, let percent, let detail):
                Task { @MainActor in
                    guard self.currentJob?.status == .running else { return }
                    self.currentJob?.currentStep = TranscriptionJob.Step(rawValue: step.rawValue) ?? .idle
                    self.currentJob?.progress = percent
                }
            case .segment(let seg):
                Task { @MainActor in
                    guard self.currentJob?.status == .running else { return }
                    self.subtitles.append(seg)
                    self.currentJob?.subtitles = self.subtitles
                }
            case .completed(let segments):
                Task { @MainActor in
                    guard self.currentJob?.status == .running else { return }
                    self.subtitles = segments
                    self.currentJob?.subtitles = segments
                    self.currentJob?.status = .done
                    self.currentJob?.progress = 1.0
                    self.screen = .results
                    self.saveSubtitlesToCache(segments)
                    self.addToRecentFiles(url: url, isCompleted: true)
                }
            case .failed(let error):
                Task { @MainActor in
                    guard self.currentJob?.status == .running else { return }
                    self.currentJob?.status = .failed
                    self.currentJob?.error = error.localizedDescription
                }
            }
        }
 
        self.eventHandler = handler
 
        transcriptionTask = Task { @MainActor in
            await newPipeline.transcribe(
                url: url, 
                language: transcriptionLanguage.rawValue, 
                dialect: transcriptionLanguage == .zh ? transcriptionDialect.rawValue : nil,
                onEvent: handler
            )
        }
    }
 
    func cancelTranscription() {
        Task {
            await pipeline?.cancel()
        }
        transcriptionTask?.cancel()
        transcriptionTask = nil
        pipeline = nil
        eventHandler = nil
        currentJob?.status = .cancelled
        screen = .home
        ModelManager.shared.unloadModels()
    }
    
    func reset() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        pipeline = nil
        eventHandler = nil
        screen = .home
        currentJob = nil
        mediaURL = nil
        subtitles = []
        selectedSubtitleId = nil
        playerCurrentTime = 0
    }
 
    func saveSubtitlesToCache(_ subtitles: [SubtitleSegment]) {
        guard let url = mediaURL else { return }
        let key = "subtitles_\(url.lastPathComponent)"
        if let data = try? JSONEncoder().encode(subtitles) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
