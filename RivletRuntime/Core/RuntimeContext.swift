import AppKit
import WebKit

/// Everything a running generated app shares between its windows.
@MainActor
final class RuntimeContext {
    let identity: AppIdentity
    let store: SettingsStore
    let notifications: NotificationBridge
    let badge: BadgeController
    let downloads: DownloadManager
    private(set) var windows: WindowManager!

    var policy: NavigationPolicy {
        NavigationPolicy(appURL: identity.url, allowedHosts: store.settings.allowedHosts)
    }

    init(identity: AppIdentity) {
        self.identity = identity
        self.store = SettingsStore(bundleIdentifier: identity.bundleIdentifier)
        self.notifications = NotificationBridge()
        self.badge = BadgeController()
        self.downloads = DownloadManager()
        self.windows = WindowManager(context: self)
    }

    /// Safari's user agent string for the running macOS, unless the user
    /// set their own. Google and Microsoft refuse sign-in to anything that
    /// looks like an embedded web view.
    var applicationNameForUserAgent: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "Version/\(v.majorVersion).\(v.minorVersion) Safari/605.1.15"
    }

    func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.applicationNameForUserAgent = applicationNameForUserAgent
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        installUserContent(into: configuration.userContentController)
        return configuration
    }

    /// (Re)installs the bridges, userscripts, and user CSS.
    func installUserContent(into controller: WKUserContentController) {
        controller.removeAllUserScripts()
        controller.removeAllScriptMessageHandlers()
        notifications.install(into: controller, enabled: store.settings.notificationsEnabled)
        badge.install(into: controller, enabled: store.settings.badgeFromAPI)
        for script in store.userScripts() {
            let time: WKUserScriptInjectionTime = script.runAt == .documentStart ? .atDocumentStart : .atDocumentEnd
            controller.addUserScript(WKUserScript(source: UserScriptWrapper.wrapped(script), injectionTime: time, forMainFrameOnly: true))
        }
        if let css = store.userCSS() {
            controller.addUserScript(WKUserScript(source: UserScriptWrapper.cssInjector(css), injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        }
    }

    func openExternally(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// Called after settings that affect page content change.
    func reloadUserContent() {
        for controller in windows.all {
            installUserContent(into: controller.webView.configuration.userContentController)
            controller.applySettings()
            controller.webView.reload()
        }
    }
}
