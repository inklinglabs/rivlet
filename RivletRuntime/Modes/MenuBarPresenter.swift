import AppKit

/// Placeholder until T003: behaves as a window.
@MainActor
final class MenuBarPresenter: ModePresenter {
    let mode: AppMode = .menuBar
    private let inner: WindowPresenter
    init(context: RuntimeContext) { inner = WindowPresenter(context: context) }
    func activate() { inner.activate() }
    func show() { inner.show() }
    func toggle() { inner.toggle() }
    func deactivate() { inner.deactivate() }
}
