import SwiftUI

struct AppDetailView: View {
    @Environment(AppState.self) private var state
    let app: GeneratedApp
    @State private var confirmTrash = false

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
                        Text("Location").foregroundStyle(.secondary)
                        Text(app.bundleURL.deletingLastPathComponent().path(percentEncoded: false))
                            .textSelection(.enabled)
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
                Text("Logins, cookies, and site data for this app stay separate from Safari and from every other Rivlet app. Scripts, custom CSS, and link rules are in the app\u{2019}s own Settings.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: 640, alignment: .leading)
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .confirmationDialog("Move \(app.name) to the Trash?", isPresented: $confirmTrash, titleVisibility: .visible) {
            Button("Move to Trash", role: .destructive) {
                Task { await state.trash(app) }
            }
        } message: {
            Text("The app quits if it is running. Its logins and settings stay on disk until you remove them.")
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
