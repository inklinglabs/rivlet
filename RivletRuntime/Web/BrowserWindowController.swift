import AppKit
import WebKit

/// One window of a generated app: a WKWebView, an optional navigation
/// toolbar, a find bar, and the menu actions that operate on the page.
@MainActor
final class BrowserWindowController: NSWindowController, NSWindowDelegate, NSToolbarDelegate, NSMenuItemValidation {
    let context: RuntimeContext
    let isMain: Bool
    let webView: WKWebView
    private let coordinator: WebCoordinator
    private let findBar = FindBarController()
    private var addressField: NSTextField?

    init(context: RuntimeContext, configuration: WKWebViewConfiguration, isMain: Bool) {
        self.context = context
        self.isMain = isMain
        self.coordinator = WebCoordinator(context: context)
        self.webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1100, height: 760), configuration: configuration)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        window.delegate = self
        window.title = context.identity.name
        window.tabbingMode = .disallowed
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.minSize = NSSize(width: 360, height: 240)
        window.contentView = webView
        if isMain {
            window.setFrameAutosaveName("RivletMainWindow")
        } else {
            window.center()
        }

        coordinator.owner = self
        webView.navigationDelegate = coordinator
        webView.uiDelegate = coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.underPageBackgroundColor = .windowBackgroundColor
        findBar.webView = webView

        applySettings()
        observeTitle()
        if isMain { context.badge.observe(webView: webView) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: Settings

    func applySettings() {
        let settings = context.store.settings
        webView.customUserAgent = settings.userAgent?.isEmpty == false ? settings.userAgent : nil
        webView.pageZoom = settings.zoom
        if settings.showToolbar {
            if window?.toolbar == nil {
                let toolbar = NSToolbar(identifier: "RivletBrowserToolbar")
                toolbar.delegate = self
                toolbar.displayMode = .iconOnly
                toolbar.allowsUserCustomization = false
                window?.toolbar = toolbar
            }
        } else {
            window?.toolbar = nil
        }
        window?.toolbarStyle = .unified
    }

    private var titleObservation: NSKeyValueObservation?
    private var urlObservation: NSKeyValueObservation?

    private func observeTitle() {
        titleObservation = webView.observe(\.title, options: [.new]) { [weak self] view, _ in
            let title = view.title
            MainActor.assumeIsolated {
                guard let self else { return }
                let name = self.context.identity.name
                if let title, !title.isEmpty, title != name {
                    self.window?.title = self.isMain ? "\(title)" : title
                } else {
                    self.window?.title = name
                }
            }
        }
        urlObservation = webView.observe(\.url, options: [.new]) { [weak self] view, _ in
            let url = view.url
            MainActor.assumeIsolated {
                self?.addressField?.stringValue = url?.host() ?? ""
            }
        }
    }

    // MARK: Window delegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if isMain && context.store.settings.keepRunningWhenWindowCloses {
            sender.orderOut(nil)
            return false
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        if !isMain { context.windows.remove(self) }
    }

    // MARK: Toolbar

    private enum Item {
        static let back = NSToolbarItem.Identifier("back")
        static let forward = NSToolbarItem.Identifier("forward")
        static let reload = NSToolbarItem.Identifier("reload")
        static let address = NSToolbarItem.Identifier("address")
    }

    nonisolated func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Item.back, Item.forward, Item.reload, .flexibleSpace, Item.address, .flexibleSpace]
    }

    nonisolated func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: id)
        item.target = self
        switch id {
        case Item.back:
            item.label = "Back"; item.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back"); item.action = #selector(goBack(_:))
        case Item.forward:
            item.label = "Forward"; item.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward"); item.action = #selector(goForward(_:))
        case Item.reload:
            item.label = "Reload"; item.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Reload"); item.action = #selector(reload(_:))
        case Item.address:
            let field = NSTextField(labelWithString: webView.url?.host() ?? "")
            field.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
            field.textColor = .secondaryLabelColor
            field.alignment = .center
            field.lineBreakMode = .byTruncatingMiddle
            addressField = field
            item.view = field
            item.label = "Address"
            item.visibilityPriority = .low
        default:
            return nil
        }
        return item
    }

    // MARK: Actions (menu and toolbar)

    @objc func goBack(_ sender: Any?) { webView.goBack() }
    @objc func goForward(_ sender: Any?) { webView.goForward() }
    @objc func reload(_ sender: Any?) { webView.reload() }
    @objc func stopLoading(_ sender: Any?) { webView.stopLoading() }
    @objc func goHome(_ sender: Any?) { webView.load(URLRequest(url: context.identity.url)) }

    @objc func openInBrowser(_ sender: Any?) {
        context.openExternally(webView.url ?? context.identity.url)
    }

    @objc func copyPageURL(_ sender: Any?) {
        let url = webView.url ?? context.identity.url
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    @objc func printPage(_ sender: Any?) {
        let info = NSPrintInfo.shared
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        let operation = webView.printOperation(with: info)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.view?.frame = webView.bounds
        operation.runModal(for: window!, delegate: nil, didRun: nil, contextInfo: nil)
    }

    @objc func zoomIn(_ sender: Any?) { setZoom(min(3.0, webView.pageZoom + 0.1)) }
    @objc func zoomOut(_ sender: Any?) { setZoom(max(0.5, webView.pageZoom - 0.1)) }
    @objc func zoomActualSize(_ sender: Any?) { setZoom(1.0) }

    private func setZoom(_ value: Double) {
        let rounded = (value * 10).rounded() / 10
        webView.pageZoom = rounded
        if isMain { context.store.settings.zoom = rounded }
    }

    @objc func toggleToolbar(_ sender: Any?) {
        context.store.settings.showToolbar.toggle()
        for controller in context.windows.all { controller.applySettings() }
    }

    @objc func showFindBar(_ sender: Any?) { findBar.show(in: self) }
    @objc func findNext(_ sender: Any?) { findBar.findNext() }
    @objc func findPrevious(_ sender: Any?) { findBar.findPrevious() }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case #selector(goBack(_:)): return webView.canGoBack
        case #selector(goForward(_:)): return webView.canGoForward
        case #selector(stopLoading(_:)): return webView.isLoading
        case #selector(toggleToolbar(_:)):
            item.title = context.store.settings.showToolbar ? "Hide Toolbar" : "Show Toolbar"
            return true
        default: return true
        }
    }
}
