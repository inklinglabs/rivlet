import AppKit

/// The menu bar of a generated app. Actions go through the responder chain
/// to the front BrowserWindowController or the app delegate.
@MainActor
enum MenuBuilder {
    static func build(appName: String) -> NSMenu {
        let bar = NSMenu()

        let app = NSMenu(title: appName)
        app.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Settings\u{2026}", action: #selector(RuntimeAppDelegate.showSettings(_:)), keyEquivalent: ",")
        app.addItem(.separator())
        let services = NSMenu(title: "Services")
        NSApp.servicesMenu = services
        app.addItem(withTitle: "Services", action: nil, keyEquivalent: "").submenu = services
        app.addItem(.separator())
        app.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = app.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        bar.addItem(withTitle: appName, action: nil, keyEquivalent: "").submenu = app

        let file = NSMenu(title: "File")
        file.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        file.addItem(.separator())
        let openInBrowser = file.addItem(withTitle: "Open in Browser", action: #selector(BrowserWindowController.openInBrowser(_:)), keyEquivalent: "o")
        openInBrowser.keyEquivalentModifierMask = [.command, .shift]
        let copyURL = file.addItem(withTitle: "Copy Link", action: #selector(BrowserWindowController.copyPageURL(_:)), keyEquivalent: "c")
        copyURL.keyEquivalentModifierMask = [.command, .shift]
        file.addItem(.separator())
        file.addItem(withTitle: "Print\u{2026}", action: #selector(BrowserWindowController.printPage(_:)), keyEquivalent: "p")
        bar.addItem(withTitle: "File", action: nil, keyEquivalent: "").submenu = file

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Find\u{2026}", action: #selector(BrowserWindowController.showFindBar(_:)), keyEquivalent: "f")
        edit.addItem(withTitle: "Find Next", action: #selector(BrowserWindowController.findNext(_:)), keyEquivalent: "g")
        let findPrevious = edit.addItem(withTitle: "Find Previous", action: #selector(BrowserWindowController.findPrevious(_:)), keyEquivalent: "g")
        findPrevious.keyEquivalentModifierMask = [.command, .shift]
        bar.addItem(withTitle: "Edit", action: nil, keyEquivalent: "").submenu = edit

        let view = NSMenu(title: "View")
        let toolbar = view.addItem(withTitle: "Show Toolbar", action: #selector(BrowserWindowController.toggleToolbar(_:)), keyEquivalent: "t")
        toolbar.keyEquivalentModifierMask = [.command, .option]
        view.addItem(.separator())
        view.addItem(withTitle: "Reload Page", action: #selector(BrowserWindowController.reload(_:)), keyEquivalent: "r")
        view.addItem(withTitle: "Stop", action: #selector(BrowserWindowController.stopLoading(_:)), keyEquivalent: ".")
        view.addItem(.separator())
        view.addItem(withTitle: "Actual Size", action: #selector(BrowserWindowController.zoomActualSize(_:)), keyEquivalent: "0")
        view.addItem(withTitle: "Zoom In", action: #selector(BrowserWindowController.zoomIn(_:)), keyEquivalent: "+")
        view.addItem(withTitle: "Zoom Out", action: #selector(BrowserWindowController.zoomOut(_:)), keyEquivalent: "-")
        view.addItem(.separator())
        let fullScreen = view.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullScreen.keyEquivalentModifierMask = [.command, .control]
        bar.addItem(withTitle: "View", action: nil, keyEquivalent: "").submenu = view

        let history = NSMenu(title: "History")
        history.addItem(withTitle: "Back", action: #selector(BrowserWindowController.goBack(_:)), keyEquivalent: "[")
        history.addItem(withTitle: "Forward", action: #selector(BrowserWindowController.goForward(_:)), keyEquivalent: "]")
        history.addItem(.separator())
        let home = history.addItem(withTitle: "Home", action: #selector(BrowserWindowController.goHome(_:)), keyEquivalent: "h")
        home.keyEquivalentModifierMask = [.command, .shift]
        bar.addItem(withTitle: "History", action: nil, keyEquivalent: "").submenu = history

        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        window.addItem(.separator())
        window.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = window
        bar.addItem(withTitle: "Window", action: nil, keyEquivalent: "").submenu = window

        let help = NSMenu(title: "Help")
        help.addItem(withTitle: "\(appName) is made with Rivlet", action: #selector(RuntimeAppDelegate.openRivletSite(_:)), keyEquivalent: "")
        NSApp.helpMenu = help
        bar.addItem(withTitle: "Help", action: nil, keyEquivalent: "").submenu = help

        return bar
    }
}
