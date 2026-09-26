import SwiftUI
import UniformTypeIdentifiers

struct NewAppSheet: View {
    @Environment(AppState.self) private var state
    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var name = ""
    @State private var nameEdited = false
    @State private var siteIcon: NSImage?
    @State private var customIcon: NSImage?
    @State private var roundCorners = true
    @State private var destination = MakerSettings.appsFolder
    @State private var inspecting = false
    @State private var creating = false
    @State private var error: String?
    @State private var inspectTask: Task<Void, Never>?

    private var parsedURL: URL? {
        var text = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https", let host = url.host(), host.contains(".") || host == "localhost"
        else { return nil }
        return url
    }

    private var urlProblem: String? {
        urlText.isEmpty || parsedURL != nil ? nil : "Enter a web address starting with http:// or https://"
    }

    private var effectiveIcon: NSImage {
        let source = customIcon ?? siteIcon
        if let source { return IconRenderer.appIcon(from: source, roundCorners: roundCorners) }
        return IconRenderer.letterIcon(name: name.isEmpty ? (parsedURL?.host() ?? "R") : name, host: parsedURL?.host() ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("New App").font(.title2.weight(.semibold)).padding(.bottom, 16)
            Form {
                Section {
                    TextField("Web address", text: $urlText, prompt: Text("https://mail.google.com"))
                        .textContentType(.URL)
                        .onSubmit(inspectNow)
                        .onChange(of: urlText) { _, _ in scheduleInspect() }
                    if let urlProblem {
                        Text(urlProblem).font(.caption).foregroundStyle(.red)
                    } else if inspecting {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Looking up the site\u{2019}s name and icon").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    TextField("Name", text: $name)
                        .onChange(of: name) { _, _ in nameEdited = true }
                }
                Section("Icon") {
                    HStack(alignment: .top, spacing: 16) {
                        Image(nsImage: effectiveIcon)
                            .resizable().interpolation(.high)
                            .frame(width: 96, height: 96)
                            .shadow(radius: 2, y: 1)
                            .dropDestination(for: URL.self) { urls, _ in
                                guard let url = urls.first, let image = NSImage(contentsOf: url) else { return false }
                                customIcon = image
                                return true
                            }
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Button("Choose Image\u{2026}", action: chooseIcon)
                                Button("Use Site Icon") { customIcon = nil }.disabled(customIcon == nil)
                            }
                            Toggle("Round the corners", isOn: $roundCorners)
                            Text("Drop a PNG on the icon to use your own. Square images work best.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Location") {
                    HStack {
                        Text(destination.path(percentEncoded: false)).truncationMode(.middle).lineLimit(1)
                        Spacer()
                        Button("Change\u{2026}", action: chooseDestination)
                    }
                    Text("Your own Applications folder needs no password and shows up in Launchpad and Spotlight.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let error {
                    Section {
                        Text(error).foregroundStyle(.red).font(.callout)
                    }
                }
            }
            .formStyle(.grouped)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(creating ? "Creating\u{2026}" : "Create") { create() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(parsedURL == nil || name.trimmingCharacters(in: .whitespaces).isEmpty || creating)
            }
            .padding(.top, 12)
        }
        .padding(20)
        .frame(width: 520)
        .onDisappear { inspectTask?.cancel() }
    }

    private func scheduleInspect() {
        inspectTask?.cancel()
        guard let url = parsedURL else { return }
        inspectTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            await inspect(url)
        }
    }

    private func inspectNow() {
        inspectTask?.cancel()
        guard let url = parsedURL else { return }
        inspectTask = Task { await inspect(url) }
    }

    private func inspect(_ url: URL) async {
        inspecting = true
        defer { inspecting = false }
        let result = await SiteInspector.inspect(url)
        guard !Task.isCancelled else { return }
        if let png = result.iconPNG { siteIcon = NSImage(data: png) }
        if !nameEdited || name.isEmpty {
            name = result.suggestedName ?? Self.nameFromHost(url)
            nameEdited = false
        }
    }

    static func nameFromHost(_ url: URL) -> String {
        var host = url.host() ?? "App"
        if host.hasPrefix("www.") { host.removeFirst(4) }
        let first = host.split(separator: ".").first.map(String.init) ?? host
        return first.prefix(1).uppercased() + first.dropFirst()
    }

    private func chooseIcon() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .heic, .icns]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url, let image = NSImage(contentsOf: url) {
            customIcon = image
        }
    }

    private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = destination
        if panel.runModal() == .OK, let url = panel.url {
            destination = url
            MakerSettings.appsFolder = url
        }
    }

    private func create() {
        guard let url = parsedURL else { return }
        creating = true
        error = nil
        let png = IconRenderer.pngData(effectiveIcon, side: IconRenderer.canvas)
        let request = AppBundleRequest(name: name.trimmingCharacters(in: .whitespaces), url: url, iconPNG: png, destinationDirectory: destination)
        Task {
            do {
                _ = try await state.create(request)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            creating = false
        }
    }
}
