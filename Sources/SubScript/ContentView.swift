import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()

    var body: some View {
        ZStack {
            switch appState.screen {
            case .home:
                HomeView()
            case .processing:
                ProcessingView()
            case .results, .export:
                ResultsView(appState: appState)
            }
        }
        .environment(appState)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
        .sheet(isPresented: $appState.showExportSheet) {
            ExportView(appState: appState)
        }
        .sheet(isPresented: $appState.showBurnOptions) {
            BurnOptionsView(appState: appState)
                .environment(appState)
        }
        .sheet(isPresented: $appState.showBurnSheet) {
            BurnProgressView(appState: appState)
                .environment(appState)
        }
    }
}