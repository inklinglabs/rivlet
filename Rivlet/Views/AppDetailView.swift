import RivletRuntime
import SwiftUI

struct AppDetailView: View {
    @Environment(AppState.self) private var state
    let app: GeneratedApp
    @State private var confirmTrash = false
    @State private var mode: AppMode = .window
    @State private var downloadFolder: String?
    @State private var moving = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 20) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundlePath))
                        .resizable().frame(width: 96, height: 96)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(app.name).font(.title.weight(.semibold))
                        Link(app.url.absoluteString, destination: app.url)
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                HStack(spacing: 12) {
                    Button("Open") { state.open(app) }.buttonStyle(.borderedProminent)
                    Button("Settings\u{2026}") { state.openSettings(for: app) }
                    Button("Show in Finder") { state.reveal(app) }
                    Spacer()
                    Button("Move to Trash", role: .destructive) { confirmTrash = true }
                }
                Divider()
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Mode").foregroundStyle(.secondary)
                        Picker("Mode", selection: $mode) {
                            ForEach(AppMode.allCases) { mode in Text(mode.title).tag(mode) }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 320)
                        .onChange(of: mode) { _, value in state.setMode(value, for: app) }
                    }
                    GridRow {
                        Text("Downloads").foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Text(DownloadLocation.label(for: downloadFolder))
                                .lineLimit(1).truncationMode(.middle)
                                .textSelection(.enabled)
                            Button("Choose\u{2026}", action: chooseDownloadFolder)
                                .controlSize(.small)
                        }
                    }
                    GridRow {
                        Text("Location").foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Text(app.bundleURL.deletingLastPathComponent().path(percentEncoded: false))
                                .lineLimit(1).truncationMode(.middle)
                                .textSelection(.enabled)
                            ForEach(moveDestinations, id: \.url) { destination in
                                Button(destination.title) { move(to: destination.url) }
                                    .controlSize(.small)
                                    .disabled(moving)
                            }
                        }
                    }
                    GridRow {
                        Text("Bundle ID").foregroundStyle(.secondary)
                        Text(app.bundleIdentifier).textSelection(.enabled)
                    }
                    GridRow {
                        Text("Created").foregroundStyle(.secondary)
                        Text(app.createdAt, style: .date)
                    }
                    GridRow {
                        Text("Size").foregroundStyle(.secondary)
                        Text(sizeDescription)
                    }
                }
                .font(.callout)
                Text("Logins, cookies, and site data for this app stay separate from Safari and from every other Rivlet app. Scripts, custom CSS, link rules, and the keyboard shortcut are in the app\u{2019}s own Settings. Moving the app to Applications makes it available to every user of this Mac; it quits first if it is running. Changing the mode takes effect right away, even while the app runs.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: 640, alignment: .leading)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear(perform: loadSettings)
        .onChange(of: app.id) { _, _ in loadSettings() }
        .confirmationDialog("Move \(app.name) to the Trash?", isPresented: $confirmTrash, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) {
                Task { await state.trash(app) }
            }
        } message: {
            Text("The app quits if it is running. Its logins and settings stay on disk until you remove them.")
        }
    }

    private func loadSettings() {
        let settings = state.settings(of: app)
        mode = settings.mode
        downloadFolder = settings.downloadFolder
    }

    private func chooseDownloadFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Where \(app.name) saves downloads"
        panel.directoryURL = DownloadLocation.resolve(downloadFolder)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let stored = DownloadLocation.storedValue(for: url)
        downloadFolder = stored
        state.updateSettings(for: app) { $0.downloadFolder = stored }
    }

    /// The Applications folders this app is not already in.
    private var moveDestinations: [(title: String, url: URL)] {
        let here = app.bundleURL.deletingLastPathComponent().standardizedFileURL
        var out: [(title: String, url: URL)] = []
        if here != RivletPaths.systemApplications.standardizedFileURL {
            out.append(("Move to Applications", RivletPaths.systemApplications))
        }
        if here != RivletPaths.userApplications.standardizedFileURL {
            out.append(("Move to My Applications", RivletPaths.userApplications))
        }
        return out
    }

    private func move(to directory: URL) {
        moving = true
        Task {
            await state.move(app, to: directory)
            moving = false
        }
    }

    private var sizeDescription: String {
        let enumerator = FileManager.default.enumerator(at: app.bundleURL, includingPropertiesForKeys: [.fileSizeKey])
        var total = 0
        while let url = enumerator?.nextObject() as? URL {
            total += (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        }
        return ByteCountFormatter.string(fromByteCount: Int64(total), countStyle: .file)
    }
}
