# Spec: Rivlet v1

**Repo:** rivlet
**Created:** 2026-09-25

## 1. Problem

Fluid turned a website into a Mac app with its own Dock icon, cookies, and
badge, and has not shipped an update since 2019. Its replacements either
bundle a Chromium or Electron runtime per app (hundreds of megabytes each,
one copy per site), charge a subscription, or ride inside Chrome or Safari
where the site keeps browser chrome and shares the browser's cookies.
Safari's own Web Apps cannot hide their toolbar, cannot run userscripts,
and cannot isolate logins per app. There is no maintained, open source,
Mac-native tool that does what Fluid did.

## 2. Goals

1. From a URL, produce a real `.app` in under ten seconds that appears in
   Launchpad, the Dock, Spotlight, and Cmd-Tab under its own name and icon.
2. Each generated app has its own cookies, local storage, and logins. Signing
   in to Gmail in one app does not sign you in anywhere else.
3. Generated apps weigh under 1 MB on disk and share one runtime, so a
   Rivlet update updates every app the next time it launches.
4. Dock badge counts, Notification Center alerts, and per-app userscripts
   and CSS work, matching the Fluid features people actually used.
5. The whole project builds from a clean checkout with `xcodegen generate`
   and `xcodebuild`, ships as a notarized DMG from the standard release
   workflow, and updates through Sparkle.

## 3. Non-Goals

- **Tabs inside a generated app.** A site-specific app is one site. Links
  that would open a tab open a second window or the default browser.
- **Menu bar (popover) mode and float-on-top.** Deferred to a v2 spec so v1
  ships. Nothing in v1 blocks adding them.
- **Ad blocking.** WebKit content rules are a whole feature. Userscripts and
  user CSS cover the basic cases in v1.
- **Browser extensions.** WKWebView cannot load them. Stated plainly in the
  README so nobody files the issue.
- **Cross-platform.** Mac only. The design depends on AppKit and WebKit.
- **App Store distribution.** Writing app bundles into `~/Applications` and
  ad-hoc signing them does not work sandboxed. Developer ID and a notarized
  DMG, same as Palilogy.
- **Pre-made app catalog.** No curated list of sites with icons. The user
  supplies a URL; Rivlet fetches the site's own icon.

## 4. Proposed Approach

Three build products, one Xcode project generated from `project.yml`:

| Product | Kind | Purpose |
|---|---|---|
| `Rivlet.app` | SwiftUI app | The maker. Lists generated apps, creates new ones, hosts the shared runtime and Sparkle. Bundle ID `com.inklinglabs.rivlet`. |
| `RivletRuntime.framework` | Swift framework embedded in `Rivlet.app` | Everything a generated app does at runtime: window, WKWebView, menus, badge, notifications, userscripts, settings window. |
| `RivletStub` | C command-line tool, packaged as `Rivlet.app/Contents/Helpers/RivletTemplate.app` | The executable every generated app runs. Under 100 lines. |

**Generated app anatomy.** A generated app is a copy of `RivletTemplate.app`
with three things changed: `Info.plist` (bundle ID
`com.inklinglabs.rivlet.app.<slug>-<6 hex>`, display name, `RivletURL`,
`RivletApp = true`), `Resources/AppIcon.icns`, and an ad-hoc re-sign
(`codesign --force --deep --sign -`). Each app is its own bundle with its
own bundle ID, so macOS gives it its own Dock icon, Cmd-Tab entry,
Notification Center identity, and its own WebKit data directory under
`~/Library/WebKit/<bundle id>/` without Rivlet doing anything. Default
location `~/Applications/`, chosen in the New App sheet.

**Stub.** On launch the stub asks LaunchServices for the app with bundle ID
`com.inklinglabs.rivlet`, `dlopen`s
`Contents/Frameworks/RivletRuntime.framework/RivletRuntime` inside it,
`dlsym`s one C-ABI entry point `RivletRuntimeMain(argc, argv)`, and calls
it. The runtime reads the host bundle's `Info.plist` for identity, then runs
`NSApplicationMain`. If Rivlet is missing, the stub shows a
`CFUserNotificationDisplayAlert` with "This app needs Rivlet" and a button
that opens the GitHub Releases page, then exits. The stub has no hardened
runtime and therefore no library validation, so an ad-hoc signed stub can
load the Developer ID signed framework. The entry point signature never
changes; new capabilities go behind it, so a stub built for 1.0 runs the
2.0 runtime.

**Two kinds of state.** Identity that never changes after creation lives in
the bundle (URL, name, icon, bundle ID). Everything editable lives in
`~/Library/Application Support/Rivlet/Apps/<bundle id>/` as `settings.json`,
`userscripts/*.js`, and `user.css`, so changing a setting never invalidates
the bundle signature and never requires a re-sign. The maker's registry of
apps is `~/Library/Application Support/Rivlet/apps.json`, verified against
the filesystem on every launch; entries whose bundle is gone are dropped.

**Runtime window.** One `NSWindow` hosting a `WKWebView`, titlebar hidden
with traffic lights inset over the page, and an optional slim toolbar
(back, forward, reload, address readout) that the user can toggle from the
View menu. Standard menu bar: back and forward on Cmd-[ and Cmd-], reload
Cmd-R, zoom Cmd-plus and Cmd-minus, find Cmd-F via `WKWebView.find`,
print, copy page URL, open in default browser. Window frame is saved per
app. `WKWebView` is used directly through `NSViewRepresentable` rather than
the macOS 26 SwiftUI `WebView`, because v1 needs the UI and navigation
delegates for popups, downloads, media permission, and the JavaScript
bridge.

**Navigation policy.** A link stays in the app if its host matches the
app's registrable domain or a host in the per-app allowed list (Google
sign-in domains are seeded for any Google property). Everything else opens
in the default browser. `createWebViewWith` (popups, `target=_blank`) opens
a second runtime window when the target host is allowed, so OAuth popups
work, otherwise the default browser. Downloads go through `WKDownload` to
`~/Downloads` and bounce the Dock icon. Camera and microphone requests are
granted after the system prompt; the template `Info.plist` carries the
usage strings. User agent defaults to the current Safari string for the
running macOS so Google and Microsoft do not refuse the "embedded browser",
overridable per app.

**Badge.** Two sources, both per-app settings, default on: a regex on
`document.title` (`\((\d+)\)` or a leading count) and a JavaScript shim for
`navigator.setAppBadge` and `clearAppBadge`. Either sets
`NSApp.dockTile.badgeLabel`.

**Notifications.** WKWebView does not implement the Web Notifications API.
A `WKUserScript` injected at document start replaces `window.Notification`
with a class whose constructor posts `{title, body, tag, icon}` over a
`WKScriptMessageHandler`; the runtime delivers it through
`UNUserNotificationCenter` under the generated app's identity. Clicking the
notification activates the app and dispatches the `click` event back to the
page's handler. `Notification.permission` reports the real system status.

**Userscripts and CSS.** Files in the per-app support folder are wrapped in
`WKUserScript` at document end, main frame only by default, with an
`@include` glob header honored the way Greasemonkey does. `user.css` is
injected as a `<style>` element by a generated script. The generated app's
Settings window edits them in a plain text view and reloads on save.

**Maker window.** Single window, `NavigationSplitView` per the styling
guide: sidebar lists apps, detail shows the selected app's URL, location,
size, and buttons for Open, Reveal in Finder, Settings (opens the generated
app's own settings window), and Move to Trash. Toolbar New App opens a
sheet: URL field, name auto-filled from the page `<title>`, icon auto
fetched from the highest resolution `apple-touch-icon` or `icon` link, drop
zone for a PNG, location picker. Create writes the bundle and opens it.

**Trade-offs.**

- Shared runtime instead of standalone copies: generated apps break if
  Rivlet is uninstalled, in exchange for a sub-megabyte footprint and one
  update path. Fluid's standalone model made sense when it could not update
  itself. The missing-runtime alert with a download link is the mitigation.
- Ad-hoc signing generated apps: they are not notarized and would be blocked
  if copied to another Mac. They are created locally with no quarantine
  flag, so Gatekeeper never evaluates them on the Mac that made them. The
  README says so. Notarizing per-user output is impossible by design.
- WKWebView over a bundled engine: no extensions, and sites that sniff for
  Chrome may degrade. In exchange the app is a few megabytes and uses the
  system WebKit that gets security fixes with macOS.

## 5. Alternatives Considered

- **Standalone bundles (Fluid's model).** Rejected: every generated app
  carries a full copy of the runtime and only updates when the user
  rebuilds it. With Sparkle available there is no reason to give up the
  single update path. Matt confirmed 2026-09-25.
- **Thin launcher that only opens Rivlet.app with a URL.** Rejected: every
  app would run under Rivlet's bundle ID, so the Dock would show one icon,
  Cmd-Tab one entry, and Notification Center one sender. The per-process
  identity is the whole feature.
- **Tauri or Pake.** Rejected: on macOS they render with the same WKWebView
  but put a Rust toolchain and a plugin layer between the app and AppKit,
  and the Fluid features (badge, Notification Center identity, per-app
  settings window) are exactly what the abstraction hides. Pake also has no
  host app; it is a build command.
- **SwiftUI `WebView` and `WebPage` (macOS 26).** Deferred, not rejected.
  The v1 delegate needs (popups, downloads, media capture, script messages)
  are only exposed on `WKWebView` today. Revisit when the SwiftUI API covers
  them.
- **Do nothing and use Flotato.** Rejected: closed source, and the stated
  goal is an open source tool that outlives one maintainer.

## 6. Acceptance Criteria

- GIVEN Rivlet is installed WHEN the user enters `https://mail.google.com`,
  accepts the fetched name and icon, and clicks Create THEN a bundle exists
  at `~/Applications/Gmail.app` within 10 seconds, `codesign -dv` reports a
  valid ad-hoc signature, the bundle is under 1 MB, and the app is running
  and showing the page.
- GIVEN two generated apps for the same site WHEN the user signs in to one
  THEN the other still shows the signed-out page after reload.
- GIVEN a generated app WHEN the user clicks a link whose host is outside
  the app's domain and allowed list THEN the default browser opens the link
  and the app's page does not navigate.
- GIVEN a generated Google app WHEN the site opens its sign-in popup THEN a
  second Rivlet window shows the popup and the sign-in completes in the
  original window.
- GIVEN a page whose title becomes `(3) Inbox` WHEN the title changes THEN
  the Dock badge shows `3`; WHEN the title loses the count THEN the badge
  clears.
- GIVEN a page that calls `new Notification("Hi", {body: "there"})` after
  permission is granted WHEN it runs THEN Notification Center shows a banner
  from the generated app, not from Rivlet, and clicking it activates the
  generated app.
- GIVEN a userscript file saved in the generated app's Settings WHEN the
  page reloads THEN the script has run on the main frame and not in iframes.
- GIVEN Rivlet.app has been moved to the Trash WHEN the user launches a
  generated app THEN an alert names Rivlet as required and offers a button
  that opens the Releases page; the process exits with code 1 and no window.
- GIVEN Rivlet is updated to a new version WHEN an existing generated app
  launches THEN it runs the new runtime with no rebuild of the bundle.
- WHEN the URL field contains text that does not parse as an http or https
  URL THE SYSTEM SHALL disable Create and show "Enter a web address
  starting with http:// or https://" under the field.
- WHEN the site has no icon link and no `/favicon.ico` THE SYSTEM SHALL use
  a generated icon with the site's first letter and still allow Create.
- WHEN a generated app's bundle is deleted in Finder THE SYSTEM SHALL drop
  it from the maker's list on the next launch with no error dialog.
- GIVEN a page that requests the camera WHEN the user allows the system
  prompt THEN the video stream starts; WHEN the user denies THEN the page
  receives `NotAllowedError` and the app does not crash.

## 7. Scope and Boundaries

**Allowed write paths:**
- `project.yml`, `Rivlet/`, `RivletRuntime/`, `RivletStub/`,
  `RivletTests/`, `RivletRuntimeTests/` (all to be created)
- `docs/specs/rivlet-v1.md` (this file), `docs/RELEASING.md`, `README.md`
- `CLAUDE.md` (Commands and Architecture as they solidify)
- `icons/` (app icon sources)
- At runtime: `~/Applications/` or the location the user picks,
  `~/Library/Application Support/Rivlet/`, `~/Downloads/` for downloads

**Read-only context:**
- Mac app styling conventions (dev-standards repo, `docs/mac-app-styling.md`)
- Palilogy `Palilogy/Updates/` for the Sparkle and About window pattern
- `.github/workflows/release.yml` (defines scheme and product names; do not
  edit except to add the framework and template to the signing step)

**Do not touch:**
- Any bundle the user did not create with Rivlet (never modify or delete
  foreign apps in `~/Applications` or `/Applications`)
- The Sparkle feed of any other Inkling Labs app
- `main` branch, tags, releases (per CLAUDE.md)

If this spec conflicts with an ad-hoc prompt, this spec wins.

## 8. Verification

Project does not exist yet; commands assume the XcodeGen setup from T001
and match the names in `.github/workflows/release.yml`.

```bash
xcodegen generate
xcodebuild -project Rivlet.xcodeproj -scheme Rivlet -configuration Debug build
xcodebuild -project Rivlet.xcodeproj -scheme Rivlet test
```

Generated app checks after a manual Create:

```bash
codesign -dv --verbose=2 ~/Applications/Gmail.app
du -sh ~/Applications/Gmail.app
/usr/libexec/PlistBuddy -c 'Print RivletURL' ~/Applications/Gmail.app/Contents/Info.plist
```

Manual pass: create apps for Gmail and a second Gmail, sign in to one and
confirm the other is signed out, trigger a badge and a notification, add a
userscript that changes the page background, quit Rivlet and confirm the
apps still run, move Rivlet to the Trash and confirm the alert, restore it.

## 9. Open Questions

| Question | Resolved by | Blocks implementation? |
|---|---|---|
| Does `UNUserNotificationCenter` deliver for an ad-hoc signed bundle on macOS 26, or does it need a stable Team ID in the designated requirement? Test on day one with a throwaway bundle. | During implementation, T002 | Yes for T007 only |
| Minimum macOS: 26.0 per Matt, since Liquid Glass and the toolbar style depend on it. Drop to 15 only if a tester needs it. | Matt, 2026-09-25 | No |
| Should the maker offer "Move to /Applications" with an admin prompt, or stay in `~/Applications` only? | After v1 | No |
| ~~Todoist project name~~ Resolved: App - Rivlet, created 2026-09-25 | Matt, 2026-09-25 | No |

## Security and Privacy

Generated apps hold real logins: session cookies and local storage for
whatever site the user chose, stored by WebKit under
`~/Library/WebKit/<bundle id>/` with the same protection as Safari's data.
Rivlet never reads, copies, or syncs that data. Userscripts run with full
access to the page and are written by the user; the Settings editor says so
in one sentence. Nothing leaves the Mac except the page's own traffic, the
icon fetch at creation time (a GET to the site the user typed), and the
Sparkle appcast check against GitHub Releases. No analytics. The privacy
page on inkling-labs.com gets a Rivlet entry saying exactly that in the
same week the first release ships.

## Acceptance checklist

- [ ] T001 XcodeGen scaffold: app, runtime framework, stub tool, template bundle, tests, macOS 26, Swift 6
- [ ] T002 C stub: locate Rivlet, dlopen runtime, call entry point, missing-runtime alert
- [ ] T003 AppConfig model and bundle writer: Info.plist, icns, ad-hoc sign, registry, with tests
- [ ] T004 Runtime window: WKWebView host, hidden titlebar, toolbar toggle, menus, navigation and find shortcuts
- [ ] T005 [P] Navigation policy: registrable domain match, allowed hosts, popups as windows, default browser handoff
- [ ] T006 [P] Downloads to ~/Downloads, camera and microphone permission, Safari user agent with override
- [ ] T007 [P] Web Notifications shim to Notification Center with click-through
- [ ] T008 [P] Dock badge from title pattern and Badging API shim
- [ ] T009 Userscripts and user CSS: support folder, include globs, injection, editor
- [ ] T010 Maker window: app list, New App sheet, icon fetch and drop, open, reveal, trash
- [ ] T011 Generated app Settings window: toolbar, badge, notifications, allowed hosts, user agent, scripts
- [ ] T012 Sparkle updater, About window, app icon, light and dark verification
- [ ] T013 README, RELEASING.md, privacy page entry, first tagged release prep

---

> Update this spec in the same commit as the code it describes. A spec that
> no longer matches the code is worse than no spec.
