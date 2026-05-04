import Foundation
import OSLog
import SwiftUI
import Observation
import MADLADTranslation

enum LogLevel: Int, Comparable, CaseIterable {
    case debug    = 0
    case info     = 1
    case warning  = 2
    case error    = 3
    case critical = 4

    static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .debug:    return "DEBUG"
        case .info:     return "INFO"
        case .warning:  return "WARN"
        case .error:    return "ERROR"
        case .critical: return "FATAL"
        }
    }

    var emoji: String {
        switch self {
        case .debug:    return "🔍"
        case .info:     return "ℹ️"
        case .warning:  return "⚠️"
        case .error:    return "❌"
        case .critical: return "💥"
        }
    }

    var color: Color {
        switch self {
        case .debug:    return Color(.systemGray)
        case .info:     return Color(.systemBlue)
        case .warning:  return Color(.systemOrange)
        case .error:    return Color(.systemRed)
        case .critical: return Color(.systemPurple)
        }
    }

    var osLogType: OSLogType {
        switch self {
        case .debug:    return .debug
        case .info:     return .info
        case .warning:  return .default
        case .error:    return .error
        case .critical: return .fault
        }
    }
}

enum LogModule: String, CaseIterable {
    case app         = "App"
    case pipeline    = "Pipeline"
    case asr         = "ASR"
    case vad         = "VAD"
    case translation = "Translation"
    case burn        = "Burn"
    case storeKit    = "StoreKit"
    case export      = "Export"
    case ui          = "UI"
    case audio       = "Audio"
    case network     = "Network"
    case general     = "General"

    var color: Color {
        switch self {
        case .app:         return .primary
        case .pipeline:    return .cyan
        case .asr:         return .blue
        case .vad:         return .indigo
        case .translation: return .green
        case .burn:        return .orange
        case .storeKit:    return .yellow
        case .export:      return .teal
        case .ui:          return .pink
        case .audio:       return .purple
        case .network:     return .mint
        case .general:     return .secondary
        }
    }
}

struct LogEntry: Identifiable {
    let id:        UUID    = UUID()
    let timestamp: Date    = Date()
    let level:     LogLevel
    let module:    LogModule
    let message:   String
    let file:      String
    let function:  String
    let line:      Int

    var formattedTime: String {
        Self.timeFormatter.string(from: timestamp)
    }

    var shortFile: String {
        URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}

@Observable
final class AppLogger: @unchecked Sendable {
    static let shared = AppLogger()

    var minimumLevel:     LogLevel    = .debug
    var enabledModules:   Set<LogModule> = Set(LogModule.allCases)
    var maxEntries:       Int         = 500

    private(set) var entries: [LogEntry] = []
    private let lock = NSLock()

    private let subsystem = Bundle.main.bundleIdentifier ?? "com.subscript"
    private var _osLoggers: [LogModule: Logger]?
    private var osLoggersLock = NSLock()

    private var osLoggers: [LogModule: Logger] {
        osLoggersLock.lock()
        defer { osLoggersLock.unlock() }
        if let cached = _osLoggers { return cached }
        let created = Dictionary(uniqueKeysWithValues: LogModule.allCases.map { module in
            (module, Logger(subsystem: subsystem, category: module.rawValue))
        })
        _osLoggers = created
        return created
    }

    var filterLevel:  LogLevel?     = nil
    var filterModule: LogModule?    = nil
    var filterText:   String        = ""

    var filteredEntries: [LogEntry] {
        entries.filter { entry in
            if let lvl = filterLevel,  entry.level  < lvl  { return false }
            if let mod = filterModule, entry.module != mod  { return false }
            if !filterText.isEmpty,
               !entry.message.localizedCaseInsensitiveContains(filterText),
               !entry.module.rawValue.localizedCaseInsensitiveContains(filterText)
            { return false }
            return true
        }
    }

    func log(
        _ message:  String,
        level:      LogLevel  = .debug,
        module:     LogModule = .general,
        file:       String    = #file,
        function:   String    = #function,
        line:       Int       = #line
    ) {
        #if !DEBUG
        guard level >= .debug else { return }
        #endif

        guard level >= minimumLevel,
              enabledModules.contains(module)
        else { return }

        let entry = LogEntry(
            level:    level,
            module:   module,
            message:  message,
            file:     file,
            function: function,
            line:     line
        )

        let osLogger = osLoggers[module] ?? Logger()
        let formatted = "[\(entry.shortFile):\(line)] \(message)"
        osLogger.log(level: level.osLogType, "\(formatted)")

        lock.lock()
        defer { lock.unlock() }

        if entries.count >= maxEntries {
            entries.removeFirst(entries.count - maxEntries + 1)
        }
        entries.append(entry)
    }

    func debug(
        _ msg: String, module: LogModule = .general,
        file: String = #file, function: String = #function, line: Int = #line
    ) {
        log(msg, level: .debug, module: module, file: file, function: function, line: line)
    }

    func info(
        _ msg: String, module: LogModule = .general,
        file: String = #file, function: String = #function, line: Int = #line
    ) {
        log(msg, level: .info, module: module, file: file, function: function, line: line)
    }

    func warning(
        _ msg: String, module: LogModule = .general,
        file: String = #file, function: String = #function, line: Int = #line
    ) {
        log(msg, level: .warning, module: module, file: file, function: function, line: line)
    }

    func error(
        _ msg: String, module: LogModule = .general,
        file: String = #file, function: String = #function, line: Int = #line
    ) {
        log(msg, level: .error, module: module, file: file, function: function, line: line)
    }

    func critical(
        _ msg: String, module: LogModule = .general,
        file: String = #file, function: String = #function, line: Int = #line
    ) {
        log(msg, level: .critical, module: module, file: file, function: function, line: line)
    }

    @discardableResult
    func measure<T>(
        _ label:    String,
        module:     LogModule = .general,
        file:       String    = #file,
        function:   String    = #function,
        line:       Int       = #line,
        block:      () async throws -> T
    ) async rethrows -> T {
        let start  = CFAbsoluteTimeGetCurrent()
        let result = try await block()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        let msg = "⏱ \(label)：\(String(format: "%.1f", elapsed))ms"
        log(msg, level: .debug, module: module, file: file, function: function, line: line)
        return result
    }

    @discardableResult
    func measureSync<T>(
        _ label:    String,
        module:     LogModule = .general,
        file:       String    = #file,
        function:   String    = #function,
        line:       Int       = #line,
        block:      () throws -> T
    ) rethrows -> T {
        let start  = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        let msg = "⏱ \(label)：\(String(format: "%.1f", elapsed))ms"
        log(msg, level: .debug, module: module, file: file, function: function, line: line)
        return result
    }

    func clear() {
        lock.lock()
        entries.removeAll()
        lock.unlock()
    }

    func export() -> String {
        entries.map { e in
            "[\(e.formattedTime)] [\(e.level.label)] [\(e.module.rawValue)] "
            + "[\(e.shortFile):\(e.line)] \(e.message)"
        }.joined(separator: "\n")
    }
}

enum Log {
    static func debug(
        _ msg: String, module: LogModule = .general,
        file: String = #file, function: String = #function, line: Int = #line
    ) {
        AppLogger.shared.debug(msg, module: module, file: file, function: function, line: line)
    }

    static func info(
        _ msg: String, module: LogModule = .general,
        file: String = #file, function: String = #function, line: Int = #line
    ) {
        AppLogger.shared.info(msg, module: module, file: file, function: function, line: line)
    }

    static func warning(
        _ msg: String, module: LogModule = .general,
        file: String = #file, function: String = #function, line: Int = #line
    ) {
        AppLogger.shared.warning(msg, module: module, file: file, function: function, line: line)
    }

    static func error(
        _ msg: String, module: LogModule = .general,
        file: String = #file, function: String = #function, line: Int = #line
    ) {
        AppLogger.shared.error(msg, module: module, file: file, function: function, line: line)
    }

    static func critical(
        _ msg: String, module: LogModule = .general,
        file: String = #file, function: String = #function, line: Int = #line
    ) {
        AppLogger.shared.critical(msg, module: module, file: file, function: function, line: line)
    }

    @discardableResult
    static func measure<T>(
        _ label: String, module: LogModule = .general,
        file: String = #file, function: String = #function, line: Int = #line,
        block: () async throws -> T
    ) async rethrows -> T {
        try await AppLogger.shared.measure(
            label, module: module, file: file, function: function, line: line, block: block
        )
    }
}

struct LogPanelView: View {
    @State private var logger = AppLogger.shared
    @Environment(\.dismiss) private var dismiss
    @State private var autoScroll   = true
    @State private var showCopied   = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.bar)

            Divider()

            filterBar
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.background.opacity(0.5))

            Divider()

            logList
        }
        .frame(minWidth: 760, minHeight: 420)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "terminal")
                .foregroundStyle(.secondary)

            Text(String(localized: "logger_title"))
                .font(.headline)

            Spacer()

            statsRow

            Divider().frame(height: 16)

            Toggle(isOn: $autoScroll) {
                Label(String(localized: "logger_auto_scroll"), systemImage: "arrow.down.to.line")
                    .font(.caption)
            }
            .toggleStyle(.button)
            .controlSize(.small)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(logger.export(), forType: .string)
                showCopied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showCopied = false
                }
            } label: {
                Label(showCopied ? String(localized: "logger_copied") : String(localized: "logger_copy_all"),
                      systemImage: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                logger.clear()
            } label: {
                Label(String(localized: "logger_clear"), systemImage: "trash")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 6) {
            ForEach([LogLevel.error, .warning, .info], id: \.self) { level in
                let count = logger.entries.filter { $0.level == level }.count
                if count > 0 {
                    Text("\(level.emoji) \(count)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(level.color)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(level.color.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField(String(localized: "logger_search_placeholder"), text: $logger.filterText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                if !logger.filterText.isEmpty {
                    Button { logger.filterText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(maxWidth: 200)

            Picker(String(localized: "logger_level"), selection: $logger.filterLevel) {
                Text(String(localized: "logger_level_all")).tag(Optional<LogLevel>.none)
                ForEach(LogLevel.allCases, id: \.self) { level in
                    Text("\(level.emoji) \(level.label)").tag(Optional(level))
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            Spacer()

            Picker(String(localized: "logger_module"), selection: $logger.filterModule) {
                Text(String(localized: "logger_module_all")).tag(Optional<LogModule>.none)
                ForEach(LogModule.allCases, id: \.self) { mod in
                    Text(mod.rawValue).tag(Optional(mod))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 140)

            Text(String(format: String(localized: "logger_entries_count"), logger.filteredEntries.count))
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            List(logger.filteredEntries) { entry in
                LogEntryRow(entry: entry)
                    .id(entry.id)
                    .listRowSeparator(.visible)
                    .listRowInsets(EdgeInsets(
                        top: 1, leading: 8, bottom: 1, trailing: 8
                    ))
            }
            .listStyle(.plain)
            .font(.caption.monospaced())
            .onChange(of: logger.filteredEntries.count) {
                if autoScroll, let last = logger.filteredEntries.last {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

struct LogEntryRow: View {
    let entry: LogEntry
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .center, spacing: 6) {
                Text(entry.formattedTime)
                    .foregroundStyle(.tertiary)
                    .frame(width: 90, alignment: .leading)

                Text(entry.level.label)
                    .foregroundStyle(entry.level.color)
                    .frame(width: 44, alignment: .center)
                    .padding(.horizontal, 4)
                    .background(entry.level.color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                Text(entry.module.rawValue)
                    .foregroundStyle(entry.module.color)
                    .frame(width: 80, alignment: .leading)

                Text(entry.message)
                    .foregroundStyle(.primary)
                    .lineLimit(isExpanded ? nil : 1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                Text("\(entry.shortFile):\(entry.line)")
                    .foregroundStyle(.quaternary)
                    .frame(width: 130, alignment: .trailing)
            }
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }

            if isExpanded {
                Text(entry.function)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 220)
            }
        }
        .padding(.vertical, 1)
    }
}

struct FloatingLogButton: View {
    @Binding var showPanel: Bool

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showPanel = true
                } label: {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            AppLogger.shared.entries
                                .contains(where: { $0.level >= .error })
                            ? Color.red : Color.black.opacity(0.7)
                        )
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .buttonStyle(.plain)
                .padding(20)
            }
        }
    }
}

struct LogPanelModifier: ViewModifier {
    @State private var showPanel = false

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                FloatingLogButton(showPanel: $showPanel)
            }
            .sheet(isPresented: $showPanel) {
                LogPanelView()
            }
    }
}

extension View {
    func withLogPanel() -> some View {
        modifier(LogPanelModifier())
    }
}