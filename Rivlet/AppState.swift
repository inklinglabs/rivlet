import AppKit
import Observation
import RivletRuntime

@MainActor
@Observable
final class AppState {
    let registry = AppRegistry()
    var selection: GeneratedApp.ID?
    var showNewApp = false
    var errorMessage: String?

    var selectedApp: GeneratedApp? {
        registry.apps.first { $0.id == selection }
    }

    func create(_ request: AppBundleRequest) async throws -> GeneratedApp {
        let app = try await AppBundleWriter.build(request)
        registry.add(app)
        selection = app.id
        open(app)
        return app
    }

    func open(_ app: GeneratedApp, arguments: [String] = []) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = arguments
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: app.bundleURL, configuration: configuration) { _, error in
            if let error {
                Task { @MainActor in self.errorMessage = error.localizedDescription }
            }
        }
    }

    func openSettings(for app: GeneratedApp) {
        open(app, arguments: ["--settings"])
    }

    /// The mode stored in the app's own settings file.
    func mode(of app: GeneratedApp) -> AppMode {
        SettingsStore(bundleIdentifier: app.bundleIdentifier).settings.mode
    }

    /// Writes the mode to the app's settings file and tells the app, if it
    /// is running, to pick it up. The one thing in the bundle that follows
    /// the mode, `LSUIElement`, is brought in line here too, so an app that
    /// is not running is right before its next launch.
    func setMode(_ mode: AppMode, for app: GeneratedApp) {
        updateSettings(for: app) { $0.mode = mode }
    }

    func settings(of app: GeneratedApp) -> AppSettings {
        SettingsStore(bundleIdentifier: app.bundleIdentifier).settings
    }

    /// Changes an app's `settings.json` and notifies a running copy.
    func updateSettings(for app: GeneratedApp, _ change: (inout AppSettings) -> Void) {
        let store = SettingsStore(bundleIdentifier: app.bundleIdentifier)
        var next = store.settings
        change(&next)
        guard next != store.settings else { return }
        store.settings = next
        let running = !NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier).isEmpty
        if !running {
            // A running app reconciles its own bundle when it hears the
            // notification; two writers at once would race on the signature.
            do {
                try BundleBaker.reconcile(app.bundleURL, wanted: next.wantsBakedDockIcon)
            } catch {
                NSLog("Rivlet: could not update \(app.name): \(error.localizedDescription)")
            }
        }
        DistributedNotificationCenter.default().postNotificationName(
            RivletPaths.settingsChangedNotification,
            object: app.bundleIdentifier,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    /// Moves the app's bundle to another folder, asking for an admin
    /// password only if macOS will not let this user do it.
    func move(_ app: GeneratedApp, to directory: URL) async {
        do {
            let moved = try await AppMover.move(app.bundleURL, bundleIdentifier: app.bundleIdentifier, to: directory)
            registry.relocate(app, to: moved)
        } catch AppMoverError.cancelled {
            // The user closed the password dialog. Nothing moved.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reveal(_ app: GeneratedApp) {
        NSWorkspace.shared.activateFileViewerSelecting([app.bundleURL])
    }

    func trash(_ app: GeneratedApp) async {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier)
        running.forEach { $0.terminate() }
        do {
            _ = try await NSWorkspace.shared.recycle([app.bundleURL])
            registry.remove(app)
            if selection == app.id { selection = nil }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
