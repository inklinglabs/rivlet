import AppKit
import WebKit

/// Saves downloads to ~/Downloads and bounces the Downloads stack when
/// they finish, the way Safari does.
@MainActor
final class DownloadManager: NSObject, WKDownloadDelegate {
    private var active: [WKDownload: URL] = [:]

    func adopt(_ download: WKDownload) {
        download.delegate = self
    }

    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String) async -> URL? {
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
        let destination = Self.uniqueURL(in: downloads, preferredName: suggestedFilename)
        active[download] = destination
        return destination
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let url = active.removeValue(forKey: download) else { return }
        DistributedNotificationCenter.default().post(name: Notification.Name("com.apple.DownloadFileFinished"), object: url.path)
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
