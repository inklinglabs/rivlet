import AppKit
import WebKit

/// A small find bar shown as a titlebar accessory, driven by WKWebView.find.
@MainActor
final class FindBarController: NSTitlebarAccessoryViewController, NSSearchFieldDelegate {
    weak var webView: WKWebView?
    private let field = NSSearchField()
    private let countLabel = NSTextField(labelWithString: "")
    private weak var host: BrowserWindowController?

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 34))
        field.placeholderString = "Find in page"
        field.delegate = self
        field.sendsSearchStringImmediately = true
        field.sendsWholeSearchString = false
        field.target = self
        field.action = #selector(searchChanged(_:))
        countLabel.textColor = .secondaryLabelColor
        countLabel.font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        let previous = NSButton(image: NSImage(systemSymbolName: "chevron.up", accessibilityDescription: "Previous")!, target: self, action: #selector(previousAction(_:)))
        let next = NSButton(image: NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "Next")!, target: self, action: #selector(nextAction(_:)))
        let done = NSButton(title: "Done", target: self, action: #selector(doneAction(_:)))
        for button in [previous, next, done] { button.bezelStyle = .accessoryBarAction }

        let stack = NSStackView(views: [field, countLabel, previous, next, done])
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
        ])
        view = container
        layoutAttribute = .bottom
    }

    func show(in controller: BrowserWindowController) {
        guard let window = controller.window else { return }
        host = controller
        if !window.titlebarAccessoryViewControllers.contains(self) {
            window.addTitlebarAccessoryViewController(self)
        }
        isHidden = false
        window.makeFirstResponder(field)
        field.selectText(nil)
    }

    func hide() {
        isHidden = true
        countLabel.stringValue = ""
        host?.window?.makeFirstResponder(webView)
    }

    func findNext() { find(backwards: false) }
    func findPrevious() { find(backwards: true) }

    private func find(backwards: Bool) {
        guard let webView, !field.stringValue.isEmpty else { return }
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.caseSensitive = false
        configuration.wraps = true
        let term = field.stringValue
        webView.find(term, configuration: configuration) { [weak self] result in
            MainActor.assumeIsolated {
                self?.countLabel.stringValue = result.matchFound ? "" : "Not found"
            }
        }
    }

    @objc private func searchChanged(_ sender: Any?) { find(backwards: false) }
    @objc private func nextAction(_ sender: Any?) { findNext() }
    @objc private func previousAction(_ sender: Any?) { findPrevious() }
    @objc private func doneAction(_ sender: Any?) { hide() }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.insertNewline(_:)):
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true { findPrevious() } else { findNext() }
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            hide()
            return true
        default:
            return false
        }
    }
}
