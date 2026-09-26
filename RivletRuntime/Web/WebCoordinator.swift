import AppKit
import UniformTypeIdentifiers
import WebKit

/// Navigation and UI delegate for one WKWebView.
@MainActor
final class WebCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    private unowned let context: RuntimeContext
    weak var owner: BrowserWindowController?

    init(context: RuntimeContext) {
        self.context = context
    }

    // MARK: Navigation policy

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, preferences: WKWebpagePreferences) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        guard let url = navigationAction.request.url else { return (.allow, preferences) }
        if navigationAction.shouldPerformDownload { return (.download, preferences) }

        let isLink = navigationAction.navigationType == .linkActivated
        if isLink && navigationAction.modifierFlags.contains(.command) {
            context.openExternally(url)
            return (.cancel, preferences)
        }
        if let target = navigationAction.targetFrame, !target.isMainFrame {
            return (.allow, preferences)
        }
        switch context.policy.decision(for: url, isUserLinkClick: isLink || navigationAction.targetFrame == nil) {
        case .stayInApp:
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
                return (.cancel, preferences)
            }
            return (.allow, preferences)
        case .openExternally:
            context.openExternally(url)
            return (.cancel, preferences)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        if !navigationResponse.canShowMIMEType { return .download }
        if let http = navigationResponse.response as? HTTPURLResponse,
           let disposition = http.value(forHTTPHeaderField: "Content-Disposition")?.lowercased(),
           disposition.hasPrefix("attachment") {
            return .download
        }
        return .allow
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        context.downloads.adopt(download)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        context.downloads.adopt(download)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        context.notifications.pushPermission(to: webView)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain, nsError.code != NSURLErrorCancelled else { return }
        guard let window = owner?.window else { return }
        let alert = NSAlert()
        alert.messageText = "Could not load the page"
        alert.informativeText = nsError.localizedDescription
        alert.addButton(withTitle: "Try Again")
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn { webView.reload() }
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    // MARK: Popups

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url,
           context.policy.decision(for: url, isUserLinkClick: true) == .openExternally {
            context.openExternally(url)
            return nil
        }
        return context.windows.makePopup(configuration: configuration, features: windowFeatures).webView
    }

    func webViewDidClose(_ webView: WKWebView) {
        guard let owner, !owner.isMain else { return }
        owner.close()
    }

    // MARK: Media and files

    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType) async -> WKPermissionDecision {
        .prompt
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo) async -> [URL]? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = true
        guard let window = owner?.window else { return nil }
        let response = await panel.beginSheetModal(for: window)
        return response == .OK ? panel.urls : nil
    }

    // MARK: JavaScript dialogs

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async {
        guard let window = owner?.window else { return }
        let alert = NSAlert()
        alert.messageText = frame.securityOrigin.host
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        _ = await alert.beginSheetModal(for: window)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async -> Bool {
        guard let window = owner?.window else { return false }
        let alert = NSAlert()
        alert.messageText = frame.securityOrigin.host
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return await alert.beginSheetModal(for: window) == .alertFirstButtonReturn
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo) async -> String? {
        guard let window = owner?.window else { return nil }
        let alert = NSAlert()
        alert.messageText = frame.securityOrigin.host
        alert.informativeText = prompt
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        field.stringValue = defaultText ?? ""
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        let response = await alert.beginSheetModal(for: window)
        return response == .alertFirstButtonReturn ? field.stringValue : nil
    }
}
