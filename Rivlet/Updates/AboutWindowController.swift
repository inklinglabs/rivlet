import Cocoa

/// About window (ported from Palilogy). The standard About panel cannot hold
/// a button, and this one needs Check for Updates, so it is built by hand.
@MainActor
final class AboutWindowController: NSWindowController {

    static let shared = AboutWindowController()
    static let repoURL = URL(string: "https://github.com/inklinglabs/rivlet")!

    private let updateButton = NSButton(title: "Check for Updates\u{2026}", target: nil, action: nil)

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 296),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "About Rivlet"
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
        buildUI()
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let info = Bundle.main.infoDictionary ?? [:]

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 96).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 96).isActive = true

        let name = NSTextField(labelWithString: "Rivlet")
        name.font = .systemFont(ofSize: 18, weight: .bold)

        let version = NSTextField(labelWithString: "Version \(info["CFBundleShortVersionString"] as? String ?? "")")
        version.font = .systemFont(ofSize: 12)
        version.isSelectable = true

        updateButton.target = self
        updateButton.action = #selector(checkForUpdates)
        updateButton.bezelStyle = .rounded
        updateButton.isEnabled = UpdaterManager.shared.isConfigured

        let repo = linkButton("github.com/inklinglabs/rivlet", #selector(openRepo))

        let copyright = NSTextField(wrappingLabelWithString: info["NSHumanReadableCopyright"] as? String ?? "")
        copyright.font = .systemFont(ofSize: 10)
        copyright.textColor = .secondaryLabelColor
        copyright.alignment = .center
        copyright.translatesAutoresizingMaskIntoConstraints = false
        copyright.widthAnchor.constraint(equalToConstant: 250).isActive = true

        let stack = NSStackView(views: [icon, name, version, updateButton, repo, copyright])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.setCustomSpacing(4, after: name)
        stack.setCustomSpacing(16, after: version)
        stack.setCustomSpacing(16, after: updateButton)
        stack.setCustomSpacing(14, after: repo)
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
    }

    private func linkButton(_ title: String, _ action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.isBordered = false
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.linkColor,
        ])
        return button
    }

    func show() {
        updateButton.isEnabled = UpdaterManager.shared.isConfigured
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func checkForUpdates() { UpdaterManager.shared.checkForUpdates() }
    @objc private func openRepo() { NSWorkspace.shared.open(Self.repoURL) }
}
