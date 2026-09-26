import SwiftUI

struct MakerSettingsView: View {
    @State private var appearance = MakerSettings.appearance
    @State private var folder = MakerSettings.appsFolder

    var body: some View {
        TabView {
            Form {
                Section {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppearanceOption.allCases) { Text($0.title).tag($0) }
                    }
                    .onChange(of: appearance) { _, value in MakerSettings.setAppearance(value) }
                }
                Section("New apps go in") {
                    HStack {
                        Text(folder.path(percentEncoded: false)).truncationMode(.middle).lineLimit(1)
                        Spacer()
                        Button("Change\u{2026}") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.canCreateDirectories = true
                            if panel.runModal() == .OK, let url = panel.url {
                                folder = url
                                MakerSettings.appsFolder = url
                            }
                        }
                    }
                    Text("Apps you already made stay where they are.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Privacy") {
                    Text("Rivlet talks to the network twice: once to fetch a site\u{2019}s name and icon when you make an app, and to check GitHub for updates. Nothing else leaves this Mac.")
                        .font(.callout)
                }
            }
            .formStyle(.grouped)
            .tabItem { Label("General", systemImage: "gearshape") }
        }
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
    }
}
