import SwiftUI

@main
struct LocalWhisperMacApp: App {
    @StateObject private var setupManager = SetupManager()
    @StateObject private var transcriber = Transcriber()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(setupManager)
                .environmentObject(transcriber)
                .frame(minWidth: 900, minHeight: 620)
                .task {
                    await setupManager.loadState()
                }
        }

        Settings {
            SettingsView()
                .environmentObject(setupManager)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
    }
}
