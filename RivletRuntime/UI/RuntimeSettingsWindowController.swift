import AppKit
import SwiftUI

@MainActor
final class RuntimeSettingsWindowController: NSWindowController {
    init(context: RuntimeContext) {
        let hosting = NSHostingController(rootView: RuntimeSettingsView(context: context))
        let window = NSWindow(contentViewController: hosting)
        window.title = "\(context.identity.name) Settings"
        window.styleMask = [.titled, .closable]
        window.setFrameAutosaveName("RivletSettingsWindow")
        super.init(window: window)
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }
}
