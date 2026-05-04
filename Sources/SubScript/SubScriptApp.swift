import SwiftUI
import AppKit

@main
struct SubScriptApp: App {
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(ModelManager.shared)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .help) {
                Button("SubScript Help") {
                    if let url = URL(string: "https://github.com/holywen/SubScript") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            CommandMenu(String(localized: "app_debug_menu")) {
                Button(String(localized: "app_show_log_panel")) {
                    openWindow(id: "logger")
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }

        Window("Debug Log", id: "logger") {
            LogPanelView()
        }
        .windowResizability(.contentSize)
    }
}