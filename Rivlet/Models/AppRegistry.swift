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
        // Must match the encoder in save(). When the dates fail to decode,
        // every app is adopted again under a new ID and the selection is lost.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: file),
           let decoded = try? decoder.decode([GeneratedApp].self, from: data) {
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

    /// Points an entry at its bundle's new home after a move.
    func relocate(_ app: GeneratedApp, to bundleURL: URL) {
        guard let index = apps.firstIndex(where: { $0.id == app.id }) else { return }
        apps[index].bundlePath = bundleURL.path
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
    nonisolated static func scanForForeignApps(knownPaths: Set<String>, in directories: [URL] = [RivletPaths.userApplications, RivletPaths.systemApplications]) -> [GeneratedApp] {
        var found: [GeneratedApp] = []
        for directory in directories {
            let contents = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])) ?? []
            for url in contents where url.pathExtension == "app" && !knownPaths.contains(url.path) {
                // /Applications holds every app on the Mac; one cheap read of
                // Info.plist rules out the ones Rivlet did not make.
                guard isRivletApp(url), let bundle = Bundle(url: url), let identity = AppIdentity(bundle: bundle) else { continue }
                let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date()
                found.append(GeneratedApp(id: UUID(), name: identity.name, url: identity.url, bundleIdentifier: identity.bundleIdentifier, bundlePath: url.path, createdAt: created))
            }
        }
        return found
    }

    nonisolated private static func isRivletApp(_ bundle: URL) -> Bool {
        guard let data = try? Data(contentsOf: bundle.appending(path: "Contents/Info.plist")),
              let info = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        else { return false }
        return info[AppIdentity.InfoKey.rivletApp] as? Bool == true
    }
}
