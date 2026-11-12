import Foundation
import Testing
@testable import Rivlet

@Suite struct AppMoverTests {
    private func makeApp(in root: URL, named name: String = "Movable") throws -> URL {
        let bundle = root.appending(path: "from/\(name).app")
        try FileManager.default.createDirectory(at: bundle.appending(path: "Contents"), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: bundle.appending(path: "Contents/Info.plist"))
        return bundle
    }

    @Test @MainActor func movesAndRefusesToOverwrite() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "rivlet-mover-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = try makeApp(in: root)
        let target = root.appending(path: "to")

        let moved = try await AppMover.move(bundle, bundleIdentifier: "com.inklinglabs.rivlet.app.none-000000", to: target)
        #expect(moved.path == target.appending(path: "Movable.app").path)
        #expect(FileManager.default.fileExists(atPath: moved.appending(path: "Contents/Info.plist").path))
        #expect(!FileManager.default.fileExists(atPath: bundle.path))

        // Same name already there: both stay put.
        let second = try makeApp(in: root)
        await #expect(throws: AppMoverError.alreadyExists("Movable")) {
            _ = try await AppMover.move(second, bundleIdentifier: "com.inklinglabs.rivlet.app.none-000000", to: target)
        }
        #expect(FileManager.default.fileExists(atPath: second.path))
        #expect(FileManager.default.fileExists(atPath: moved.path))
    }

    @Test func adminCommandQuotesPaths() {
        let command = AppMover.adminCommand(
            from: URL(filePath: "/Users/me/Applications/Matt's Mail.app"),
            to: URL(filePath: "/Applications/Matt's Mail.app"),
            user: "me"
        )
        #expect(command == "/bin/mkdir -p '/Applications' && /bin/mv -n '/Users/me/Applications/Matt'\\''s Mail.app' '/Applications/Matt'\\''s Mail.app' && /usr/sbin/chown -R 'me' '/Applications/Matt'\\''s Mail.app'")
    }

    @Test @MainActor func registryFollowsAMove() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "rivlet-relocate-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let bundle = try makeApp(in: root, named: "Kept")
        let registry = AppRegistry(file: root.appending(path: "apps.json"))
        let app = GeneratedApp(id: UUID(), name: "Kept", url: URL(string: "https://example.com/")!,
                               bundleIdentifier: "com.inklinglabs.rivlet.app.kept-000000", bundlePath: bundle.path, createdAt: Date())
        registry.add(app)
        let target = root.appending(path: "to/Kept.app")
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: bundle, to: target)
        registry.relocate(app, to: target)
        #expect(registry.apps.first { $0.id == app.id }?.bundlePath == target.path)
        // And it survives a reload, which drops entries whose bundle is gone.
        registry.load()
        #expect(registry.apps.contains { $0.id == app.id })
    }
}
