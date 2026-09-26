import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        NavigationSplitView {
            List(selection: $state.selection) {
                Section("Apps") {
                    ForEach(state.registry.apps) { app in
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.name).font(.subheadline.weight(.semibold))
                                Text(app.url.host() ?? app.url.absoluteString).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundlePath))
                                .resizable().frame(width: 24, height: 24)
                        }
                        .tag(app.id)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } detail: {
            if let app = state.selectedApp {
                AppDetailView(app: app)
            } else if state.registry.apps.isEmpty {
                ContentUnavailableView {
                    Label("No apps yet", systemImage: "app.dashed")
                } description: {
                    Text("Turn any website into its own Mac app. It gets a Dock icon, its own logins, and its own notifications.")
                } actions: {
                    Button("New App\u{2026}") { state.showNewApp = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ContentUnavailableView("Select an app", systemImage: "sidebar.left")
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    state.showNewApp = true
                } label: {
                    Label("New App", systemImage: "plus")
                }
                .help("Make a new app from a website")
            }
        }
        .sheet(isPresented: $state.showNewApp) {
            NewAppSheet()
                .environment(state)
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } }
        )) {
            Button("OK") { state.errorMessage = nil }
        } message: {
            Text(state.errorMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state.registry.load()
        }
    }
}
