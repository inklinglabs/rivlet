import Foundation
import Observation
import RivletRuntime

@MainActor
@Observable
final class AppRegistry {
    private(set) var apps: [GeneratedApp] = []
    private let file: URL

    init(file: URL = RivletPaths.registryFile) {
        self.file = file
        load()
    }

    func load() {
        var loaded: [GeneratedApp] = []
        if let data = try? Data(contentsOf: file),
           let decoded = try? JSONDecoder().decode([GeneratedApp].self, from: data) {
            loaded = decoded.filter(\.exists)
        }
        for adopted in Self.scanForForeignApps(knownPaths: Set(loaded.map(\.bundlePath))) {
            loaded.append(adopted)
        }
        apps = loaded.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        save()
    }

    func add(_ app: GeneratedApp) {
        apps.removeAll { $0.bundlePath == app.bundlePath }
        apps.append(app)
        apps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        save()
    }

    func remove(_ app: GeneratedApp) {
        apps.removeAll { $0.id == app.id }
        save()
    }

    private func save() {
        do {
            try RivletPaths.ensureDirectory(file.deletingLastPathComponent())
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(apps).write(to: file, options: .atomic)
        } catch {
            NSLog("Rivlet: could not save registry: \(error)")
        }
    }

    /// Picks up apps made by Rivlet that the registry does not know about,
    /// for example after a restore from backup.
    nonisolated static func scanForForeignApps(knownPaths: Set<String>, in directories: [URL] = [RivletPaths.userApplications]) -> [GeneratedApp] {
        var found: [GeneratedApp] = []
        for directory in directories {
            let contents = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])) ?? []
            for url in contents where url.pathExtension == "app" && !knownPaths.contains(url.path) {
                guard let bundle = Bundle(url: url), let identity = AppIdentity(bundle: bundle) else { continue }
                let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
                found.append(GeneratedApp(id: UUID(), name: identity.name, url: identity.url, bundleIdentifier: identity.bundleIdentifier, bundlePath: url.path, createdAt: created))
            }
        }
        return found
    }
}
