import AppKit

/// A normal window. What every app made with Rivlet 1.0 does.
@MainActor
final class WindowPresenter: ModePresenter {
    let mode: AppMode = .window
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
        window.setFrameAutosaveName("RivletMainWindow")
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
        context.windows.main?.window?.setFrameAutosaveName("")
    }
}
