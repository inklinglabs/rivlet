import AppKit
import SwiftUI

/// Click, press a combination, done. Escape cancels. The control reports
/// every attempt, including refused ones, so the pane can say why.
final class HotkeyRecorderControl: NSView {
    enum Attempt {
        case recorded(Hotkey)
        case noModifier
        case reserved(Hotkey)
    }

    var hotkey: Hotkey? { didSet { needsDisplay = true } }
    var onAttempt: ((Attempt) -> Void)?
    private var recording = false { didSet { needsDisplay = true } }

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 160, height: 24) }
    override var focusRingMaskBounds: NSRect { bounds }
    override func drawFocusRingMask() { NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6).fill() }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        recording = true
    }

    override func becomeFirstResponder() -> Bool { true }

    override func resignFirstResponder() -> Bool {
        recording = false
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == 53, event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
            recording = false
            window?.makeFirstResponder(nil)
            return
        }
        guard let candidate = Hotkey.from(event: event) else {
            onAttempt?(.noModifier)
            return
        }
        if HotkeyFormatter.isReservedBySystem(candidate) {
            onAttempt?(.reserved(candidate))
            return
        }
        recording = false
        window?.makeFirstResponder(nil)
        onAttempt?(.recorded(candidate))
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording else { return false }
        keyDown(with: event)
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        (recording ? NSColor.controlAccentColor.withAlphaComponent(0.12) : NSColor.controlBackgroundColor).setFill()
        path.fill()
        (recording ? NSColor.controlAccentColor : NSColor.separatorColor).setStroke()
        path.stroke()
        let text: String
        let color: NSColor
        if recording {
            text = "Press keys\u{2026}"; color = .secondaryLabelColor
        } else if let hotkey {
            text = HotkeyFormatter.string(for: hotkey); color = .labelColor
        } else {
            text = "Click to record"; color = .secondaryLabelColor
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize), .foregroundColor: color]
        let size = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attributes)
    }
}

struct HotkeyRecorder: NSViewRepresentable {
    var hotkey: Hotkey?
    var onAttempt: (HotkeyRecorderControl.Attempt) -> Void

    func makeNSView(context: Context) -> HotkeyRecorderControl {
        let view = HotkeyRecorderControl()
        view.hotkey = hotkey
        view.onAttempt = onAttempt
        return view
    }

    func updateNSView(_ view: HotkeyRecorderControl, context: Context) {
        view.hotkey = hotkey
        view.onAttempt = onAttempt
    }
}
