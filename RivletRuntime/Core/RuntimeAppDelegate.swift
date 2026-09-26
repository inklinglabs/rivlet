import AppKit
import WebKit

@MainActor
final class RuntimeAppDelegate: NSObject, NSApplicationDelegate {
    static var retained: RuntimeAppDelegate?

    let arguments: [String]
    private var window: NSWindow?

    init(arguments: [String]) {
        self.arguments = arguments
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let identity = AppIdentity(bundle: .main)
        let url = identity?.url ?? URL(string: "https://inkling-labs.com")!
        let webView = WKWebView(frame: .zero)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = identity?.name ?? "Rivlet"
        window.contentView = webView
        window.center()
        window.makeKeyAndOrderFront(nil)
        webView.load(URLRequest(url: url))
        self.window = window
        NSApp.activate()
    }
}
