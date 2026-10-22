import SwiftUI

/// The Mode tab: window, menu bar, or floating, with each mode's options.
struct ModeSettingsPane: View {
    let context: RuntimeContext
    @State private var hotkeyMessage: String?
    @State private var width = ""
    @State private var height = ""

    var body: some View {
        @Bindable var store = context.store
        Form {
            Section {
                Picker("Show this app as", selection: $store.settings.mode) {
                    ForEach(AppMode.allCases) { mode in Text(mode.title).tag(mode) }
                }
                .pickerStyle(.segmented)
                .onChange(of: store.settings.mode) { _, _ in context.modes.apply() }
                Text(modeHelp).font(.caption).foregroundStyle(.secondary)
            }
            switch store.settings.mode {
            case .menuBar:
                Section("Menu bar") {
                    Toggle("Hide the Dock icon", isOn: $store.settings.menuBar.hideDockIcon)
                        .onChange(of: store.settings.menuBar.hideDockIcon) { _, _ in context.modes.apply() }
                    Text("The app lives in the menu bar only. It still shows for a moment in the Dock while it launches.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        Text("Keyboard shortcut")
                        Spacer()
                        HotkeyRecorder(hotkey: store.settings.menuBar.hotkey, onAttempt: handle(attempt:))
                            .frame(width: 160, height: 24)
                        Button("Clear") {
                            store.settings.menuBar.hotkey = nil
                            hotkeyMessage = nil
                            context.modes.apply()
                        }
                        .disabled(store.settings.menuBar.hotkey == nil)
                    }
                    Text(hotkeyMessage ?? "Opens and closes the popover from any app. Click the box and press a combination with Command, Option, Control, or Shift.")
                        .font(.caption).foregroundStyle(hotkeyMessage == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                    HStack(spacing: 12) {
                        Text("Popover size")
                        Spacer()
                        TextField("Width", text: $width).frame(width: 64).multilineTextAlignment(.trailing)
                        Text("\u{00D7}").foregroundStyle(.secondary)
                        TextField("Height", text: $height).frame(width: 64).multilineTextAlignment(.trailing)
                        Button("Apply", action: applySize).disabled(!sizeChanged)
                    }
                    Text("Points, at least \(Int(PopoverSize.minimum.width)) by \(Int(PopoverSize.minimum.height)). Sign-in windows the site opens appear as normal windows and close the popover; open it again when you are done.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            case .floating:
                Section("Floating") {
                    Toggle("Show on every Space", isOn: $store.settings.floating.allSpaces)
                        .onChange(of: store.settings.floating.allSpaces) { _, _ in context.modes.apply() }
                    Text("The window follows you between Spaces and sits over full screen apps.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            case .window:
                EmptyView()
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: loadSize)
        .onChange(of: store.settings.menuBar.popoverSize) { _, _ in loadSize() }
    }

    private var modeHelp: String {
        switch context.store.settings.mode {
        case .window: return "A normal window with its own Dock icon."
        case .menuBar: return "An icon in the menu bar. Click it or press a shortcut to open the page in a popover."
        case .floating: return "A window that stays above other windows while you work."
        }
    }

    private func handle(attempt: HotkeyRecorderControl.Attempt) {
        switch attempt {
        case .noModifier:
            hotkeyMessage = "Add Command, Option, Control, or Shift"
        case .reserved(let hotkey):
            hotkeyMessage = "\(HotkeyFormatter.string(for: hotkey)) belongs to macOS"
        case .recorded(let hotkey):
            if let presenter = context.modes.presenter as? MenuBarPresenter, !presenter.canRegister(hotkey) {
                hotkeyMessage = "Already used by another app"
                return
            }
            hotkeyMessage = nil
            context.store.settings.menuBar.hotkey = hotkey
            context.modes.apply()
        }
    }

    private var sizeChanged: Bool {
        let current = context.store.settings.menuBar.popoverSize
        return Double(width) != current.width || Double(height) != current.height
    }

    private func loadSize() {
        let size = context.store.settings.menuBar.popoverSize
        width = String(Int(size.width))
        height = String(Int(size.height))
    }

    private func applySize() {
        guard let w = Double(width), let h = Double(height) else { loadSize(); return }
        context.store.settings.menuBar.popoverSize = PopoverSize(
            width: max(PopoverSize.minimum.width, w.rounded()),
            height: max(PopoverSize.minimum.height, h.rounded())
        )
        context.modes.apply()
        loadSize()
    }
}
