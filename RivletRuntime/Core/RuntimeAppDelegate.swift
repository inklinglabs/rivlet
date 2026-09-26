import AppKit
import WebKit

@MainActor
final class RuntimeAppDelegate: NSObject, NSApplicationDelegate {
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
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        showMainWindow()
        NSApp.activate()
        if arguments.contains("--settings") {
            showSettings(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
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

    @objc func openRivletSite(_ sender: Any?) {
        NSWorkspace.shared.open(RivletPaths.releasesURL)
    }
}
