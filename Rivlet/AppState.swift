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
