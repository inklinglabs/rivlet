import AppKit

/// A window that stays above normal windows, optionally on every Space.
/// Same window class as Window mode with a different level, so menus,
/// toolbar, and find all keep working. Full screen is off: a floating
/// full-screen window is meaningless.
@MainActor
final class FloatingPresenter: ModePresenter {
    let mode: AppMode = .floating
    private unowned let context: RuntimeContext

    init(context: RuntimeContext) {
        self.context = context
    }

    func activate() {
        NSApp.setActivationPolicy(.regular)
        let controller = context.windows.ensureMain()
        guard let window = controller.window else { return }
        controller.embedWebView()
        WindowPresentation.reset(window)
        window.setFrameAutosaveName("RivletFloatingWindow")
        window.level = .floating
        window.hidesOnDeactivate = false
        window.collectionBehavior.remove(.fullScreenPrimary)
        if context.store.settings.floating.allSpaces {
            window.collectionBehavior.insert([.canJoinAllSpaces, .fullScreenAuxiliary])
        } else {
            window.collectionBehavior.remove([.canJoinAllSpaces, .fullScreenAuxiliary])
        }
    }

    func show() {
        let controller = context.windows.ensureMain()
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func showAtLaunch() { show() }
    func toggle() { show() }

    func deactivate() {
        guard let window = context.windows.main?.window else { return }
        window.setFrameAutosaveName("")
        WindowPresentation.reset(window)
    }
}
