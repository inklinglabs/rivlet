import Foundation
import Observation

/// Owns the per-app support folder: `settings.json`, `userscripts/*.js`,
/// and `user.css`. Used by the runtime and by the maker when it seeds a
/// new app.
@MainActor
@Observable
public final class SettingsStore {
    public let bundleIdentifier: String
    public let directory: URL
    public var settings: AppSettings {
        didSet { if settings != oldValue { save() } }
    }

    public var settingsFile: URL { directory.appending(path: "settings.json") }
    public var userScriptsDirectory: URL { directory.appending(path: "userscripts", directoryHint: .isDirectory) }
    public var userCSSFile: URL { directory.appending(path: "user.css") }

    public init(bundleIdentifier: String, directory: URL? = nil) {
        self.bundleIdentifier = bundleIdentifier
        self.directory = directory ?? RivletPaths.appDirectory(for: bundleIdentifier)
        self.settings = AppSettings()
        load()
    }

    public func load() {
        guard let data = try? Data(contentsOf: settingsFile),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return }
        settings = decoded
    }

    public func save() {
        do {
            try RivletPaths.ensureDirectory(directory)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(settings).write(to: settingsFile, options: .atomic)
        } catch {
            NSLog("Rivlet: could not save settings: \(error)")
        }
    }

    // MARK: Userscripts and CSS

    public func userScriptFiles() -> [URL] {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: userScriptsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])) ?? []
        return urls.filter { $0.pathExtension.lowercased() == "js" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    public func userScripts() -> [UserScript] {
        userScriptFiles().compactMap { url in
            guard let source = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return UserScriptParser.parse(name: url.deletingPathExtension().lastPathComponent, source: source)
        }
    }

    public func userCSS() -> String? {
        guard let css = try? String(contentsOf: userCSSFile, encoding: .utf8),
              !css.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return css
    }

    public func writeUserScript(named name: String, source: String) throws {
        try RivletPaths.ensureDirectory(userScriptsDirectory)
        let safe = name.replacingOccurrences(of: "/", with: "-")
        try source.write(to: userScriptsDirectory.appending(path: "\(safe).js"), atomically: true, encoding: .utf8)
    }

    public func deleteUserScript(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    public func writeUserCSS(_ css: String) throws {
        try RivletPaths.ensureDirectory(directory)
        try css.write(to: userCSSFile, atomically: true, encoding: .utf8)
    }
}
