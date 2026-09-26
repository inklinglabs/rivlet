import SwiftUI

/// Settings for one generated app: General, Links, Scripts.
struct RuntimeSettingsView: View {
    let context: RuntimeContext

    var body: some View {
        TabView {
            GeneralSettingsPane(context: context)
                .tabItem { Label("General", systemImage: "gearshape") }
            LinksSettingsPane(context: context)
                .tabItem { Label("Links", systemImage: "link") }
            ScriptsSettingsPane(context: context)
                .tabItem { Label("Scripts", systemImage: "curlybraces") }
        }
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct GeneralSettingsPane: View {
    let context: RuntimeContext
    @State private var userAgent = ""

    var body: some View {
        @Bindable var store = context.store
        Form {
            Section {
                Toggle("Show navigation toolbar", isOn: $store.settings.showToolbar)
                    .onChange(of: store.settings.showToolbar) { _, _ in
                        for controller in context.windows.all { controller.applySettings() }
                    }
                Toggle("Keep running when the window closes", isOn: $store.settings.keepRunningWhenWindowCloses)
                Text("Badges and notifications keep arriving while the app runs in the Dock. Quit from the Dock or with Command-Q.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Dock badge") {
                Toggle("From the page title", isOn: $store.settings.badgeFromTitle)
                    .onChange(of: store.settings.badgeFromTitle) { _, value in
                        context.badge.setTitleBadging(enabled: value)
                    }
                Text("Reads counts like \u{201C}(3) Inbox\u{201D} out of the window title.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("From the site itself", isOn: $store.settings.badgeFromAPI)
                    .onChange(of: store.settings.badgeFromAPI) { _, _ in context.reloadUserContent() }
                Text("Sites that use the Badging API set the number directly. Changing this reloads the page.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Notifications") {
                Toggle("Show the site\u{2019}s notifications in Notification Center", isOn: $store.settings.notificationsEnabled)
                    .onChange(of: store.settings.notificationsEnabled) { _, _ in context.reloadUserContent() }
                Text("The site still has to ask for permission. Focus modes hide banners the same way they do for any app.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Browser identity") {
                TextField("Custom user agent", text: $userAgent, prompt: Text("Safari on this Mac"))
                    .onSubmit(saveUserAgent)
                Text("Leave empty to look like Safari, which is what sign-in pages expect. Changing this reloads the page.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Apply", action: saveUserAgent)
                        .disabled(userAgent == (store.settings.userAgent ?? ""))
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { userAgent = context.store.settings.userAgent ?? "" }
    }

    private func saveUserAgent() {
        let trimmed = userAgent.trimmingCharacters(in: .whitespacesAndNewlines)
        context.store.settings.userAgent = trimmed.isEmpty ? nil : trimmed
        context.reloadUserContent()
    }
}

private struct LinksSettingsPane: View {
    let context: RuntimeContext
    @State private var newHost = ""
    @State private var selection: String?

    var body: some View {
        @Bindable var store = context.store
        Form {
            Section {
                Text("Links to \(NavigationPolicy(appURL: context.identity.url, allowedHosts: []).appDomain) and the hosts below open inside this app. Every other link opens in your default browser.")
                    .font(.callout)
                List(selection: $selection) {
                    ForEach(store.settings.allowedHosts, id: \.self) { host in
                        Text(host).tag(host)
                    }
                }
                .frame(minHeight: 140)
                HStack {
                    TextField("example.com or .example.com", text: $newHost)
                        .onSubmit(addHost)
                    Button("Add", action: addHost).disabled(newHost.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Remove") {
                        if let selection { store.settings.allowedHosts.removeAll { $0 == selection } }
                        selection = nil
                    }
                    .disabled(selection == nil)
                }
                Text("Start with a dot to include every subdomain. Common sign-in hosts are always allowed.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func addHost() {
        let host = newHost.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !host.isEmpty, !context.store.settings.allowedHosts.contains(host) else { return }
        context.store.settings.allowedHosts.append(host)
        newHost = ""
    }
}

private struct ScriptsSettingsPane: View {
    let context: RuntimeContext
    @State private var files: [URL] = []
    @State private var selected: URL?
    @State private var source = ""
    @State private var css = ""
    @State private var dirty = false

    var body: some View {
        Form {
            Section("Userscripts") {
                HStack(alignment: .top) {
                    List(selection: $selected) {
                        ForEach(files, id: \.self) { url in
                            Text(url.deletingPathExtension().lastPathComponent).tag(url)
                        }
                    }
                    .frame(width: 160, height: 180)
                    TextEditor(text: $source)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 180)
                        .onChange(of: source) { _, _ in dirty = selected != nil }
                }
                HStack {
                    Button("New Script", action: newScript)
                    Button("Delete", action: deleteScript).disabled(selected == nil)
                    Spacer()
                    Button("Save and Reload", action: saveScript).disabled(!dirty)
                }
                Text("Scripts run after the page loads and can do anything the page can. Use a // ==UserScript== header with @include to limit them to some pages.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Custom CSS") {
                TextEditor(text: $css)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 120)
                HStack {
                    Spacer()
                    Button("Save and Reload") {
                        try? context.store.writeUserCSS(css)
                        context.reloadUserContent()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: refresh)
        .onChange(of: selected) { _, url in
            source = url.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
            dirty = false
        }
    }

    private func refresh() {
        files = context.store.userScriptFiles()
        css = context.store.userCSS() ?? ""
    }

    private func newScript() {
        let name = "script-\(files.count + 1)"
        let template = """
        // ==UserScript==
        // @name        \(name)
        // @include     *
        // ==/UserScript==

        """
        try? context.store.writeUserScript(named: name, source: template)
        refresh()
        selected = files.first { $0.lastPathComponent == "\(name).js" }
    }

    private func deleteScript() {
        guard let selected else { return }
        try? context.store.deleteUserScript(at: selected)
        self.selected = nil
        source = ""
        refresh()
        context.reloadUserContent()
    }

    private func saveScript() {
        guard let selected else { return }
        try? source.write(to: selected, atomically: true, encoding: .utf8)
        dirty = false
        context.reloadUserContent()
    }
}
