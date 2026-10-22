import AppKit
import WebKit

/// Saves downloads to the folder the app's settings name (Downloads by
/// default), or asks where to put each one. Bounces the Downloads stack
/// when a file lands there, the way Safari does.
@MainActor
final class DownloadManager: NSObject, WKDownloadDelegate {
    private let store: SettingsStore
    private var active: [WKDownload: URL] = [:]

    init(store: SettingsStore) {
        self.store = store
    }

    func adopt(_ download: WKDownload) {
        download.delegate = self
    }

    static var systemDownloads: URL {
        FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    }

    /// The folder downloads go to: the chosen one if it still exists,
    /// otherwise ~/Downloads.
    nonisolated static func resolveFolder(_ chosen: String?) -> URL {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        guard let chosen, !chosen.isEmpty else { return downloads }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: chosen, isDirectory: &isDirectory), isDirectory.boolValue {
            return URL(fileURLWithPath: chosen)
        }
        NSLog("Rivlet: download folder \(chosen) is missing, saving to Downloads instead")
        return downloads
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String) async -> URL? {
        let folder = Self.resolveFolder(store.settings.downloadFolder)
        let destination: URL
        if store.settings.askWhereToSaveDownloads {
            guard let chosen = await askForDestination(in: folder, suggestedFilename: suggestedFilename) else { return nil }
            // The panel already confirmed any overwrite with the user, so
            // clear the way for WebKit, which refuses to replace a file.
            try? FileManager.default.removeItem(at: chosen)
            destination = chosen
        } else {
            destination = Self.uniqueURL(in: folder, preferredName: suggestedFilename)
        }
        active[download] = destination
        return destination
    }

    private func askForDestination(in folder: URL, suggestedFilename: String) async -> URL? {
        let panel = NSSavePanel()
        panel.directoryURL = folder
        panel.nameFieldStringValue = suggestedFilename.replacingOccurrences(of: "/", with: "-")
        panel.canCreateDirectories = true
        let response: NSApplication.ModalResponse
        if let window = NSApp.keyWindow {
            response = await panel.beginSheetModal(for: window)
        } else {
            NSApp.activate()
            response = panel.runModal()
        }
        return response == .OK ? panel.url : nil
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let url = active.removeValue(forKey: download) else { return }
        if url.deletingLastPathComponent().standardizedFileURL == Self.systemDownloads.standardizedFileURL {
            DistributedNotificationCenter.default().post(name: Notification.Name("com.apple.DownloadFileFinished"), object: url.path)
        }
        NSApp.requestUserAttention(.informationalRequest)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        active.removeValue(forKey: download)
        NSLog("Rivlet: download failed: \(error.localizedDescription)")
    }

    nonisolated static func uniqueURL(in directory: URL, preferredName: String) -> URL {
        let cleaned = preferredName.replacingOccurrences(of: "/", with: "-")
        let base = (cleaned as NSString).deletingPathExtension
        let ext = (cleaned as NSString).pathExtension
        var candidate = directory.appending(path: cleaned)
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let name = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
            candidate = directory.appending(path: name)
            counter += 1
        }
        return candidate
    }
}
