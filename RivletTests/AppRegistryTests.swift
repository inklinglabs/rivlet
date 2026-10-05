import Foundation
import Testing
@testable import Rivlet

@Suite struct AppRegistryTests {
    @Test @MainActor func reloadKeepsIdentifiers() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "rivlet-registry-\(UUID().uuidString)")
        let bundle = root.appending(path: "Kept.app")
        try FileManager.default.createDirectory(at: bundle, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let file = root.appending(path: "apps.json")
        let app = GeneratedApp(id: UUID(), name: "Kept", url: URL(string: "https://example.com/")!,
                               bundleIdentifier: "com.inklinglabs.rivlet.app.kept-000000", bundlePath: bundle.path, createdAt: Date())
        let registry = AppRegistry(file: file)
        registry.add(app)

        // The selection is an ID, so a reload has to hand back the same one.
        registry.load()
        #expect(registry.apps.contains { $0.id == app.id })
        #expect(AppRegistry(file: file).apps.contains { $0.id == app.id })
    }
}
