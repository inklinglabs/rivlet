import AppKit

/// One way of showing a generated app: a window, a floating window, or a
/// status item with a popover. Every presenter shows the same main
/// `BrowserWindowController` and its web view; switching presenters never
/// creates a second web view, so the page keeps its state.
@MainActor
protocol ModePresenter: AnyObject {
    var mode: AppMode { get }

    /// Takes over presentation. Called once after construction and again
    /// whenever settings that affect this mode change.
    func activate()

    /// Shows the app to the user: a reopen from the Dock, a notification
    /// click, the maker's Open button.
    func show()

    /// What launch does. Window modes show the window; the menu bar
    /// presenter only puts up its status item.
    func showAtLaunch()

    /// What the global hotkey does. Window modes bring the app forward, or
    /// hide it when it is already in front; the menu bar presenter toggles
    /// its popover.
    func toggle()

    /// Gives the main window back in a neutral state so the next presenter
    /// can take it over.
    func deactivate()
}

/// Shared window configuration for the two window-based modes.
@MainActor
enum WindowPresentation {
    /// Resets a main window to its plain v1 shape.
    static func reset(_ window: NSWindow) {
        window.level = .normal
        window.hidesOnDeactivate = false
        window.collectionBehavior.remove([.canJoinAllSpaces, .fullScreenAuxiliary])
        window.collectionBehavior.insert(.fullScreenPrimary)
    }

    /// The shortcut in a window mode: hide the app when it is in front
    /// with its window showing, otherwise bring it forward.
    static func toggle(_ presenter: ModePresenter, window: NSWindow?) {
        if NSApp.isActive, let window, window.isVisible, !window.isMiniaturized {
            NSApp.hide(nil)
        } else {
            presenter.show()
        }
    }
}
