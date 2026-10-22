import AppKit

/// Picks the presenter for the app's mode and swaps it live when the mode
/// changes, from the app's own Settings window or from the maker over a
/// distributed notification.
@MainActor
final class ModeCoordinator {
    private unowned let context: RuntimeContext
    private(set) var presenter: ModePresenter?
    private var observer: NSObjectProtocol?

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

    private func make(_ mode: AppMode) -> ModePresenter {
        switch mode {
        case .window: return WindowPresenter(context: context)
        case .floating: return FloatingPresenter(context: context)
        case .menuBar: return MenuBarPresenter(context: context)
        }
    }
}
