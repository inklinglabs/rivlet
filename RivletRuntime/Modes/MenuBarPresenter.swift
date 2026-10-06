import AppKit
import WebKit

/// A status item whose popover holds the page. The same web view the
/// window would show is reparented into the popover, and back into the
/// main window when the user detaches.
@MainActor
final class MenuBarPresenter: NSObject, ModePresenter, NSPopoverDelegate {
    let mode: AppMode = .menuBar
    private unowned let context: RuntimeContext
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let content: PopoverContentController
    private var hotkeyToken: HotkeyRegistrar.Token?
    private var registeredHotkey: Hotkey?
    /// Set when the status item could not be made; the app shows as a
    /// window for this launch and the stored mode is left alone.
    private var fallback: WindowPresenter?
    private(set) var isDetached = false

    init(context: RuntimeContext) {
        self.context = context
        self.content = PopoverContentController(title: context.identity.name)
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = content
        content.onDetach = { [weak self] in self?.detach() }
        content.onEscape = { [weak self] in self?.popover.performClose(nil) }
    }

    // MARK: ModePresenter

    func activate() {
        let controller = context.windows.ensureMain()
        if statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            guard let button = item.button else {
                NSStatusBar.system.removeStatusItem(item)
                NSLog("Rivlet: no room for a status item, showing a window instead")
                let fallback = WindowPresenter(context: context)
                self.fallback = fallback
                fallback.activate()
                return
            }
            button.image = Self.statusIcon()
            button.imageScaling = .scaleProportionallyDown
            button.toolTip = context.identity.name
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            statusItem = item
        }
        let settings = context.store.settings.menuBar
        let size = NSSize(
            width: max(PopoverSize.minimum.width, settings.popoverSize.width),
            height: max(PopoverSize.minimum.height, settings.popoverSize.height)
        )
        content.preferredContentSize = size
        popover.contentSize = size
        controller.closeHandler = { [weak self] _ in
            // Closing the detached window puts the page back in the popover.
            self?.reattach(showPopover: false)
            return false
        }
        if !isDetached {
            controller.window?.orderOut(nil)
            content.host(controller.releaseWebView())
        }
        NSApp.setActivationPolicy(settings.hideDockIcon ? .accessory : .regular)
        applyHotkey(settings.hotkey)
    }

    /// A menu bar app launches into its status item and nothing else.
    func showAtLaunch() {
        if let fallback { fallback.show(); return }
    }

    func show() {
        if let fallback { fallback.show(); return }
        if isDetached { showDetachedWindow() } else { openPopover() }
    }

    func toggle() {
        if let fallback { fallback.show(); return }
        if isDetached { showDetachedWindow(); return }
        if popover.isShown { popover.performClose(nil) } else { openPopover() }
    }

    func deactivate() {
        if let fallback { fallback.deactivate(); self.fallback = nil }
        applyHotkey(nil)
        popover.performClose(nil)
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        statusItem = nil
        if let controller = context.windows.main {
            controller.closeHandler = nil
            controller.embedWebView()
            controller.window?.setFrameAutosaveName("")
        }
        isDetached = false
        NSApp.setActivationPolicy(.regular)
    }

    // MARK: Popover

    private func openPopover() {
        guard let button = statusItem?.button else { return }
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func popoverDidShow(_ notification: Notification) {
        guard let webView = context.windows.main?.webView else { return }
        webView.window?.makeFirstResponder(webView)
    }

    /// LaunchServices resets an app without `LSUIElement` to the regular
    /// policy whenever it is opened again, so a hidden Dock icon has to be
    /// re-hidden on every reopen.
    func reapplyActivationPolicy() {
        guard fallback == nil else { return }
        let hide = context.store.settings.menuBar.hideDockIcon
        if hide, NSApp.activationPolicy() != .accessory {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func popoverShouldDetach(_ popover: NSPopover) -> Bool { false }

    @objc private func statusItemClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            toggle()
        }
    }

    private func showStatusMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()
        let detachItem = menu.addItem(withTitle: isDetached ? "Return to Menu Bar" : "Open in Window", action: #selector(toggleDetached(_:)), keyEquivalent: "")
        detachItem.target = self
        let settings = menu.addItem(withTitle: "Settings\u{2026}", action: #selector(RuntimeAppDelegate.showSettings(_:)), keyEquivalent: "")
        settings.target = RuntimeAppDelegate.retained
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit \(context.identity.name)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    // MARK: Detach and reattach

    @objc func toggleDetached(_ sender: Any?) {
        if isDetached { reattach(showPopover: true) } else { detach() }
    }

    func detach() {
        guard !isDetached, let controller = context.windows.main, let window = controller.window else { return }
        popover.performClose(nil)
        isDetached = true
        controller.embedWebView()
        WindowPresentation.reset(window)
        window.setFrameAutosaveName("RivletMainWindow")
        showDetachedWindow()
    }

    func reattach(showPopover: Bool) {
        guard isDetached, let controller = context.windows.main, let window = controller.window else { return }
        isDetached = false
        window.setFrameAutosaveName("")
        window.orderOut(nil)
        content.host(controller.releaseWebView())
        if showPopover { openPopover() }
    }

    private func showDetachedWindow() {
        guard let controller = context.windows.main else { return }
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    // MARK: Hotkey

    /// Tries the combination for real and lets it go again, so the
    /// Settings pane can refuse one another app already owns.
    func canRegister(_ hotkey: Hotkey) -> Bool {
        if hotkey == registeredHotkey { return true }
        guard let token = try? HotkeyRegistrar.shared.register(hotkey, handler: {}) else { return false }
        HotkeyRegistrar.shared.unregister(token)
        return true
    }

    private func applyHotkey(_ hotkey: Hotkey?) {
        guard hotkey != registeredHotkey else { return }
        if let hotkeyToken { HotkeyRegistrar.shared.unregister(hotkeyToken) }
        hotkeyToken = nil
        registeredHotkey = nil
        guard let hotkey else { return }
        do {
            hotkeyToken = try HotkeyRegistrar.shared.register(hotkey) { [weak self] in self?.toggle() }
            registeredHotkey = hotkey
        } catch {
            NSLog("Rivlet: could not register hotkey \(HotkeyFormatter.string(for: hotkey)): \(error)")
        }
    }

    // MARK: Icon

    /// The app's own icon at menu bar size. Not a template image: the
    /// site's colors are the point.
    private static func statusIcon() -> NSImage {
        let icon = (NSApp.applicationIconImage.copy() as? NSImage) ?? NSImage(size: NSSize(width: 18, height: 18))
        icon.size = NSSize(width: 18, height: 18)
        icon.isTemplate = false
        return icon
    }
}

/// The popover's content: a slim header with the site name and a detach
/// button, and a container the web view is dropped into.
@MainActor
final class PopoverContentController: NSViewController {
    var onDetach: (() -> Void)?
    var onEscape: (() -> Void)?
    private let container = NSView()
    private let header = PopoverHeaderView()
    private let appTitle: String

    init(title: String) {
        self.appTitle = title
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let root = NSView(frame: NSRect(origin: .zero, size: preferredContentSize))
        header.titleLabel.stringValue = appTitle
        header.detachButton.target = self
        header.detachButton.action = #selector(detachPressed(_:))
        header.onDragOut = { [weak self] in self?.onDetach?() }
        header.translatesAutoresizingMaskIntoConstraints = false
        container.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(header)
        root.addSubview(container)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: root.topAnchor),
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 28),
            container.topAnchor.constraint(equalTo: header.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])
        view = root
    }

    func host(_ webView: WKWebView) {
        _ = view
        webView.removeFromSuperview()
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    @objc private func detachPressed(_ sender: Any?) {
        onDetach?()
    }
}

/// Site name on the left, a detach button on the right. Dragging the
/// header a short distance detaches too.
@MainActor
final class PopoverHeaderView: NSView {
    let titleLabel = NSTextField(labelWithString: "")
    let detachButton = NSButton(image: NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: "Open in Window")!, target: nil, action: nil)
    var onDragOut: (() -> Void)?
    private var dragStart: NSPoint?

    override init(frame: NSRect) {
        super.init(frame: frame)
        titleLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        detachButton.isBordered = false
        detachButton.toolTip = "Open in Window"
        detachButton.contentTintColor = .secondaryLabelColor
        let stack = NSStackView(views: [titleLabel, detachButton])
        stack.orientation = .horizontal
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 8)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 1).fill()
    }

    override func mouseDown(with event: NSEvent) { dragStart = event.locationInWindow }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart else { return }
        let dx = event.locationInWindow.x - start.x, dy = event.locationInWindow.y - start.y
        if dx * dx + dy * dy > 20 * 20 {
            dragStart = nil
            onDragOut?()
        }
    }

    override func mouseUp(with event: NSEvent) { dragStart = nil }
}
