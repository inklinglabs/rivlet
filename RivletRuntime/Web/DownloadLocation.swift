import Foundation

/// Where a generated app saves downloads. Shared by the runtime, its
/// Settings pane, and the maker's detail view, so all three agree on what
/// a stored folder means.
public enum DownloadLocation {
    public static var systemDownloads: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    }

    /// The folder downloads go to: the chosen one if it still exists,
    /// otherwise ~/Downloads.
    public static func resolve(_ chosen: String?) -> URL {
        guard let chosen, !chosen.isEmpty else { return systemDownloads }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: chosen, isDirectory: &isDirectory), isDirectory.boolValue {
            return URL(fileURLWithPath: chosen)
        }
        NSLog("Rivlet: download folder \(chosen) is missing, saving to Downloads instead")
        return systemDownloads
    }

    /// What to store for a folder the user picked. ~/Downloads is stored as
    /// nil so the default keeps following the system.
    public static func storedValue(for folder: URL) -> String? {
        folder.standardizedFileURL == systemDownloads.standardizedFileURL ? nil : folder.standardizedFileURL.path
    }

    /// The short name shown next to the Choose button.
    public static func label(for stored: String?) -> String {
        guard let stored, !stored.isEmpty else { return "Downloads" }
        return (stored as NSString).abbreviatingWithTildeInPath
    }
}
