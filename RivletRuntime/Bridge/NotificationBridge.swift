import AppKit
import UserNotifications
import WebKit

/// Bridges the page's `new Notification(...)` calls to Notification Center
/// under the generated app's own identity, and routes clicks back.
@MainActor
final class NotificationBridge: NSObject, UNUserNotificationCenterDelegate {
    private weak var webView: WKWebView?
    private var identifiersByTag: [String: String] = [:]
    private var enabled = true
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    override init() {
        super.init()
        center?.delegate = self
    }

    func install(into controller: WKUserContentController, enabled: Bool) {
        self.enabled = enabled
        controller.addUserScript(WKUserScript(
            source: BridgeScripts.notifications(initialPermission: "default"),
            injectionTime: .atDocumentStart, forMainFrameOnly: false))
        controller.add(ScriptMessageProxy(handler: { [weak self] message in
            self?.handle(message)
        }), name: BridgeScripts.notifyHandler)
        controller.addScriptMessageHandler(ScriptMessageProxy(replyHandler: { [weak self] message in
            await self?.requestPermission(from: message.webView) ?? "denied"
        }), contentWorld: .page, name: BridgeScripts.permissionHandler)
    }

    /// Tells the page what `Notification.permission` should report.
    func pushPermission(to webView: WKWebView) {
        self.webView = webView
        Task { @MainActor in
            let status = await currentPermission()
            webView.evaluateJavaScript("window.__rivletSetNotificationPermission && window.__rivletSetNotificationPermission(\(UserScriptWrapper.jsString(status)))") { _, _ in }
        }
    }

    private func currentPermission() async -> String {
        guard enabled, let center else { return "denied" }
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional: return "granted"
        case .denied: return "denied"
        default: return "default"
        }
    }

    private func requestPermission(from webView: WKWebView?) async -> String {
        if let webView { self.webView = webView }
        guard enabled, let center else { return "denied" }
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted ? "granted" : "denied"
        } catch {
            NSLog("Rivlet: notification authorization failed: \(error)")
            return "denied"
        }
    }

    private func handle(_ message: WKScriptMessage) {
        if let view = message.webView { webView = view }
        guard enabled, let center,
              let body = message.body as? [String: Any],
              let type = body["type"] as? String,
              let id = body["id"] as? String
        else { return }
        switch type {
        case "show":
            let content = UNMutableNotificationContent()
            content.title = (body["title"] as? String) ?? ""
            content.body = (body["body"] as? String) ?? ""
            if (body["silent"] as? Bool) != true { content.sound = .default }
            let tag = (body["tag"] as? String) ?? ""
            if !tag.isEmpty {
                content.threadIdentifier = tag
                if let previous = identifiersByTag[tag] {
                    center.removeDeliveredNotifications(withIdentifiers: [previous])
                }
                identifiersByTag[tag] = id
            }
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil)) { error in
                if let error { NSLog("Rivlet: notification failed: \(error)") }
            }
        case "close":
            center.removeDeliveredNotifications(withIdentifiers: [id])
            center.removePendingNotificationRequests(withIdentifiers: [id])
        default:
            break
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let active = await MainActor.run { NSApp.isActive && NSApp.keyWindow != nil }
        return active ? [.list] : [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let id = response.notification.request.identifier
        await MainActor.run {
            NSApp.activate()
            RuntimeAppDelegate.retained?.showMainWindow()
            webView?.evaluateJavaScript("window.__rivletNotificationClicked && window.__rivletNotificationClicked(\(UserScriptWrapper.jsString(id)))") { _, _ in }
        }
    }
}
