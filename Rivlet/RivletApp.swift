import SwiftUI

@main
struct RivletApp: App {
    @NSApplicationDelegateAdaptor(MakerAppDelegate.self) private var delegate
    @State private var state = AppState()

    var body: some Scene {
        Window("Rivlet", id: "main") {
            ContentView()
                .environment(state)
        }
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Rivlet") { AboutWindowController.shared.show() }
                Button("Check for Updates\u{2026}") { UpdaterManager.shared.checkForUpdates() }
                    .disabled(!UpdaterManager.shared.isConfigured)
            }
            CommandGroup(replacing: .newItem) {
                Button("New App\u{2026}") { state.showNewApp = true }
                    .keyboardShortcut("n")
            }
        }
        Settings {
            MakerSettingsView()
        }
    }
}

@MainActor
final class MakerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        MakerSettings.applyAppearance()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = UpdaterManager.shared
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
