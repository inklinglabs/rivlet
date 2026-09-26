import AppKit
import WebKit

/// Sets the Dock badge from the page title or from the Badging API shim.
@MainActor
final class BadgeController {
    private var titleObservation: NSKeyValueObservation?
    private var titleEnabled = true

    func install(into controller: WKUserContentController, enabled: Bool) {
        guard enabled else { return }
        controller.addUserScript(WKUserScript(source: BridgeScripts.badging, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        controller.add(ScriptMessageProxy(handler: { [weak self] message in
            guard let body = message.body as? [String: Any] else { return }
            let count = (body["count"] as? NSNumber)?.intValue ?? 0
            self?.apply(count: count)
        }), name: BridgeScripts.badgeHandler)
    }

    func observe(webView: WKWebView, enabled: Bool = true) {
        titleEnabled = enabled
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] view, _ in
            let title = view.title
            MainActor.assumeIsolated {
                guard let self, self.titleEnabled else { return }
                self.apply(count: Self.count(inTitle: title ?? "") ?? 0)
            }
        }
    }

    func setTitleBadging(enabled: Bool) {
        titleEnabled = enabled
        if !enabled { apply(count: 0) }
    }

    /// -1 means "show a dot with no number", 0 clears, anything else shows.
    func apply(count: Int) {
        switch count {
        case 0: NSApp.dockTile.badgeLabel = nil
        case ..<0: NSApp.dockTile.badgeLabel = "\u{2022}"
        default: NSApp.dockTile.badgeLabel = count > 999 ? "999+" : String(count)
        }
    }

    nonisolated static func count(inTitle title: String) -> Int? {
        let patterns: [Regex<(Substring, Substring)>] = [
            /\((\d+)\)/,
            /^\s*(\d+)\s*[\u{2022}\u{00B7}\-\u{2013}\u{2014}|:]/,
        ]
        for pattern in patterns {
            if let match = title.firstMatch(of: pattern), let value = Int(match.1) {
                return value
            }
        }
        return nil
    }
}
