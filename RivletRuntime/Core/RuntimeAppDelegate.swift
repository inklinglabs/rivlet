import AppKit
import WebKit

@MainActor
final class RuntimeAppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    static var retained: RuntimeAppDelegate?

    let arguments: [String]
    private var context: RuntimeContext?
    private var settingsWindow: RuntimeSettingsWindowController?

    init(arguments: [String]) {
        self.arguments = arguments
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        guard let identity = AppIdentity(bundle: .main) else {
            let alert = NSAlert()
            alert.messageText = "This app is missing its Rivlet settings"
            alert.informativeText = "Its Info.plist has no RivletURL. Delete it and make it again in Rivlet."
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        let context = RuntimeContext(identity: identity)
        self.context = context
        NSApp.mainMenu = MenuBuilder.build(appName: identity.name)
        context.modes.start()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        context?.modes.showAtLaunch()
        if arguments.contains("--settings") {
            showSettings(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        (context?.modes.presenter as? MenuBarPresenter)?.reapplyActivationPolicy()
        if !flag { showMainWindow() }
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        (context?.modes.presenter as? MenuBarPresenter)?.reapplyActivationPolicy()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showMainWindow() {
        context?.windows.showMainWindow()
    }

    @objc func showSettings(_ sender: Any?) {
        guard let context else { return }
        if settingsWindow == nil {
            settingsWindow = RuntimeSettingsWindowController(context: context)
        }
        NSApp.activate()
        settingsWindow?.showWindow(nil)
        settingsWindow?.window?.makeKeyAndOrderFront(nil)
    }

    @objc func toggleMenuBarDetach(_ sender: Any?) {
        (context?.modes.presenter as? MenuBarPresenter)?.toggleDetached(nil)
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(toggleMenuBarDetach(_:)) {
            guard let presenter = context?.modes.presenter as? MenuBarPresenter else {
                item.isHidden = true
                return false
            }
            item.isHidden = false
            item.title = presenter.isDetached ? "Return to Menu Bar" : "Open in Window"
            return true
        }
        return true
    }

    @objc func openRivletSite(_ sender: Any?) {
        NSWorkspace.shared.open(RivletPaths.releasesURL)
    }
}
