import AppKit

/// Picks the presenter for the app's mode and swaps it live when the mode
/// changes, from the app's own Settings window or from the maker over a
/// distributed notification.
@MainActor
final class ModeCoordinator {
    private unowned let context: RuntimeContext
    private(set) var presenter: ModePresenter?
    private var observer: NSObjectProtocol?
    private var hotkeyToken: HotkeyRegistrar.Token?
    private var registeredHotkey: Hotkey?
    /// Why the last attempt to keep the app out of the Dock at launch
    /// failed, for the Mode pane to show. nil when it worked.
    private(set) var bakeFailure: String?

    init(context: RuntimeContext) {
        self.context = context
    }

    var mode: AppMode { presenter?.mode ?? .window }

    /// Builds the presenter for the stored mode. Call once at launch, before
    /// the first window shows.
    func start() {
        apply()
        observer = DistributedNotificationCenter.default().addObserver(
            forName: RivletPaths.settingsChangedNotification,
            object: context.identity.bundleIdentifier,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.context.store.load()
                self.apply()
                self.context.reloadUserContent(reloadPage: false)
            }
        }
    }

    /// Applies the current settings. Swaps presenters when the mode changed
    /// and otherwise lets the presenter re-read its options.
    func apply() {
        let wanted = context.store.settings.mode
        applyHotkey(context.store.settings.hotkey)
        reconcileBundle()
        if let presenter, presenter.mode == wanted {
            presenter.activate()
            return
        }
        let wasRunning = presenter != nil
        presenter?.deactivate()
        let next = make(wanted)
        presenter = next
        next.activate()
        // A switch into a window mode shows the window so the change is
        // visible; a switch into menu bar mode leaves the popover closed.
        if wasRunning, wanted != .menuBar { next.show() }
    }

    func show() { presenter?.show() }
    func showAtLaunch() { presenter?.showAtLaunch() }
    func toggle() { presenter?.toggle() }

    // MARK: Shortcut

    /// Tries the combination for real and lets it go again, so the
    /// Settings pane can refuse one another app already owns.
    func canRegister(_ hotkey: Hotkey) -> Bool {
        if hotkey == registeredHotkey { return true }
        guard let token = try? HotkeyRegistrar.shared.register(hotkey, handler: {}) else { return false }
        HotkeyRegistrar.shared.unregister(token)
        return true
    }

    /// One shortcut per app, whatever the mode. The presenter decides what
    /// it does.
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

    // MARK: Bundle

    /// Writes or removes `LSUIElement` in this app's own bundle to match
    /// the settings. A failure turns the option back off so the toggle
    /// never claims something the bundle does not do.
    private func reconcileBundle() {
        let wanted = context.store.settings.wantsBakedDockIcon
        if wanted { bakeFailure = nil }
        do {
            try BundleBaker.reconcile(context.identity.bundleURL, wanted: wanted)
        } catch {
            NSLog("Rivlet: could not update the bundle: \(error.localizedDescription)")
            if wanted {
                bakeFailure = error.localizedDescription
                context.store.settings.menuBar.bakeDockIcon = false
            }
        }
    }

    private func make(_ mode: AppMode) -> ModePresenter {
        switch mode {
        case .window: return WindowPresenter(context: context)
        case .floating: return FloatingPresenter(context: context)
        case .menuBar: return MenuBarPresenter(context: context)
        }
    }
}
