import AppKit
import WebKit

@MainActor
final class WindowManager {
    private unowned let context: RuntimeContext
    private(set) var main: BrowserWindowController?
    private(set) var popups: [BrowserWindowController] = []

    var all: [BrowserWindowController] { [main].compactMap { $0 } + popups }

    init(context: RuntimeContext) {
        self.context = context
    }

    /// The main window and its web view, created on first use. Presenters
    /// decide how and where it shows.
    @discardableResult
    func ensureMain() -> BrowserWindowController {
        if let main { return main }
        let controller = BrowserWindowController(context: context, configuration: context.makeConfiguration(), isMain: true)
        controller.webView.load(URLRequest(url: context.identity.url))
        main = controller
        return controller
    }

    /// Shows the app the way its mode presenter does it.
    func showMainWindow() {
        context.modes.show()
    }

    func makePopup(configuration: WKWebViewConfiguration, features: WKWindowFeatures) -> BrowserWindowController {
        let controller = BrowserWindowController(context: context, configuration: configuration, isMain: false)
        if let w = features.width?.doubleValue, let h = features.height?.doubleValue, w > 200, h > 200 {
            controller.window?.setContentSize(NSSize(width: w, height: h))
            controller.window?.center()
        }
        popups.append(controller)
        controller.showWindow(nil)
        return controller
    }

    func remove(_ controller: BrowserWindowController) {
        popups.removeAll { $0 === controller }
    }
}
