# Spec: Rivlet v2

**Repo:** rivlet
**Created:** 2026-10-06
**Status:** Approved by Matt 2026-10-06. Ships as 1.1.0.

## 1. Problem

Every app Rivlet makes is a normal window. People who turn a chat, a music
player, a notes page, or a dashboard into an app want it one keystroke away
without a Cmd-Tab round trip, or want it to stay visible above the editor
or browser they are working in. Today the only way to glance at such an app
is to switch to it, and the only way to keep it visible is to tile windows
by hand. Fluid had both a menu bar mode and a float-on-top option, and the
v1 spec deferred both to a v2 spec.

## 2. Goals

1. Each generated app has a mode, chosen in the New App sheet and
   changeable afterwards: Window (v1 behavior), Menu bar, or Floating. The
   mode lives in the app's editable config and the runtime reads it at
   launch.
2. Menu bar mode: a status item showing the site's icon; clicking it
   toggles a popover that hosts the app's WKWebView; a global hotkey
   toggles the same popover; the Dock icon can be hidden; the popover can
   be detached into a normal window and reattached.
3. Floating mode: the window sits above normal windows, can optionally
   stay visible on every Space, and remembers its position and size per
   app, separately from the Window mode frame.
4. Changing the mode, the hotkey, or any mode option never rewrites or
   re-signs the app bundle. A running app picks the change up without
   being remade; at most it relaunches itself.

## 3. Non-Goals

- **Tabs, ad blocking, browser extensions, App Store distribution, a
  pre-made catalog.** All still out, for the reasons in the v1 spec.
- **Changing how the stub loads the runtime.** The stub, the
  `RivletRuntimeMain` entry point, and the template bundle layout stay as
  v1 shipped them. Everything in v2 happens behind the entry point.
- **Intel builds.** Apple silicon only, as v1.
- **Baking `LSUIElement` into generated bundles.** Hiding the Dock icon is
  done at runtime with the activation policy so the bundle stays untouched
  (see Open Questions for the launch-bounce consequence).
- **Resizing the popover by dragging its edge.** NSPopover has no resize
  affordance; v2 sets the size from Settings. Live drag-resize can come
  later if people ask.
- **More than one mode at once.** An app is in exactly one mode. A menu
  bar app that is detached is temporarily a window, not a second mode.
- **Hotkeys for Window or Floating mode.** A global "bring this app
  forward" hotkey is a separate feature with its own permission story.

## 4. Proposed Approach

Everything new lives in `RivletRuntime/` plus two maker touch points. No
new build products, no new SPM packages in the runtime.

**Mode in settings, not in the bundle.** `AppSettings` gains:

```
mode: "window" | "menuBar" | "floating"   default "window"
menuBar:
  hideDockIcon: Bool                     default true
  hotkey: { keyCode: Int, modifiers: Int }?   default nil
  popoverSize: { width: Double, height: Double }  default 420 x 640
floating:
  allSpaces: Bool                        default false
```

It is written to the existing `settings.json` in
`~/Library/Application Support/Rivlet/Apps/<bundle id>/` by the same
`SettingsStore`. The v1 decoder already defaults every missing key, so a
1.x runtime reading a 2.x file ignores the new keys and a 2.x runtime
reading a 1.x file gets Window mode. Bundle `Info.plist` is not touched,
which is what keeps Goal 4 true and keeps the v1 "identity in the bundle,
everything editable in the support folder" rule intact.

**One web view, three presenters.** Today `WindowManager` owns the main
`BrowserWindowController`. v2 introduces a `ModePresenter` protocol in
`RivletRuntime/Modes/` with three implementations that all present the
same main `BrowserWindowController` and its `WKWebView`:

- `WindowPresenter`: what v1 does. `RivletMainWindow` autosave name,
  `.normal` level.
- `FloatingPresenter`: the same window class with `level = .floating`,
  autosave name `RivletFloatingWindow` so the two frames do not collide,
  `collectionBehavior` adds `.canJoinAllSpaces` and `.fullScreenAuxiliary`
  when `allSpaces` is on, and `hidesOnDeactivate = false`. Full screen is
  disabled in this mode (a floating full-screen window is meaningless).
- `MenuBarPresenter`: an `NSStatusItem` whose button image is the app's
  own `AppIcon.icns` rendered at 18 by 18 points, not a template, so the
  site's colors show. Left click toggles an `NSPopover`
  (`behavior = .transient`) whose content view controller hosts the web
  view; right click shows a small menu (Open in Window, Settings, Quit).
  The popover's `contentSize` comes from `popoverSize`. Detach: the
  presenter implements `detachableWindow(for:)` and hands back the main
  `BrowserWindowController` window, so a detached popover is the v1 window
  with menus, toolbar toggle and find bar intact. Reattach is a View menu
  item and a status item menu item; it moves the web view back into the
  popover content and closes the window. Hiding the Dock icon calls
  `NSApp.setActivationPolicy(.accessory)`; the policy is applied in
  `applicationWillFinishLaunching` after settings load, which moves the
  `.regular` call out of `Entry.swift` and into the delegate.

The runtime picks the presenter in `RuntimeAppDelegate` from
`store.settings.mode` before the first window shows. `WindowManager`
keeps owning popups (sign-in windows) unchanged in every mode.

**Global hotkey.** Carbon `RegisterEventHotKey`, in
`RivletRuntime/Modes/HotkeyRegistrar.swift`. It needs no Accessibility or
Input Monitoring permission, which an `NSEvent` global monitor would. The
recorder is a small `NSView` subclass that captures the next key down with
modifiers and shows it in the Settings pane. A hotkey registers only in
Menu bar mode. Two generated apps can register the same combination; the
second registration gets `eventHotKeyExistsErr` and the Settings pane shows
"Already used by another app" instead of saving it.

**Keyboard and focus in the popover.** The popover is shown with
`NSApp.activate()` first so the generated app is active, then the web view
is made first responder. Because the app has a main menu even as an
accessory app, Cmd-C, Cmd-V, Cmd-A, Cmd-F and the rest keep working inside
the popover through the existing `MenuBuilder` menu. Escape closes the
popover (a key equivalent on the popover's content view, only when the web
view did not consume the event). `.transient` closes it on an outside
click; when the user has started typing in a field it still closes, which
is the same as every system popover and is accepted.

**Live mode change.** Three paths write the mode, and all end in the same
place:

1. The generated app's own Settings window (new Mode pane) writes
   `settings.json` and calls `ModeCoordinator.apply(mode:)` directly. The
   coordinator tears down the current presenter, builds the new one, and
   presents the same web view, so the page keeps its state. Switching the
   Dock icon on or off calls `setActivationPolicy` live.
2. The maker's app detail view writes `settings.json` through
   `SettingsStore` and posts a `DistributedNotificationCenter` notification
   named `com.inklinglabs.rivlet.settingsChanged` with the bundle ID in
   the user info. A running generated app observes it, reloads
   `settings.json`, and applies the mode.
3. The New App sheet seeds `settings.json` with the chosen mode at create
   time, next to the seeded allowed hosts.

**Maker changes.** `NewAppSheet` gets a Mode picker (segmented, three
options, one line of help each). `AppDetailView` shows the mode next to
Location and offers the same picker. `GeneratedApp` does not change; the
mode is read from `SettingsStore` when the detail view appears so the
registry never duplicates editable state.

**Trade-offs.**

- `NSPopover` over a custom panel: free arrow, transient dismissal, system
  look, and native detach, in exchange for no drag-resize and the
  popover's own focus quirks. The quirks are listed under Risks with the
  mitigation; drag-resize is a non-goal.
- Activation policy over `LSUIElement`: the bundle stays untouched and the
  mode flips live, in exchange for the Dock icon showing for a fraction of
  a second at launch while the stub loads the runtime. Fluid-era apps did
  the same.
- Carbon hotkeys over an SPM package: no new dependency inside the
  `dlopen`ed framework and no permission prompt, in exchange for about 120
  lines of Carbon glue and a hand-written recorder view.

## 5. Alternatives Considered

- **Third-party popover packages (status item plus popover wrappers).**
  Rejected: they wrap `NSPopover` or a borderless `NSPanel` and add an SPM
  dependency to a framework that is loaded by `dlopen` from a stub with no
  library validation. Every extra dylib is another thing the ad-hoc
  signed stub must be able to load, and the win is a few hundred lines
  Rivlet can own.
- **Custom borderless `NSPanel` anchored under the status item instead of
  `NSPopover`.** Rejected for v2: it gives drag-resize and reuses
  `BrowserWindowController` directly, but loses the system popover look,
  the arrow, the transient dismissal, and native detach, and every one of
  those must then be reimplemented and kept consistent with macOS. If
  drag-resize turns out to matter, this is the path, and the
  `ModePresenter` protocol keeps it a one-file swap.
- **`NSPanel` with `.nonactivatingPanel` for Floating mode.** Rejected:
  a non-activating panel lets you click it without switching apps, which
  sounds right for float-on-top, but a web app needs to be key to accept
  typing and WebKit's text input is unreliable in a non-activating panel.
  `NSWindow` at `.floating` level with normal activation is what
  float-on-top meant in Fluid and what people expect.
- **`MenuBarExtra` (SwiftUI) for the status item.** Rejected: the runtime
  is an AppKit app driven by `NSApplicationMain`, not a SwiftUI `App`
  scene, and `MenuBarExtra` cannot host an existing `WKWebView` instance
  without wrapping it again. The styling guide's `MenuBarExtra` advice is
  for maker-style SwiftUI apps.
- **`NSEvent.addGlobalMonitorForEvents` for the hotkey.** Rejected: it
  needs Input Monitoring permission per generated app, which is a system
  prompt per app and a Privacy page entry. Carbon hotkeys need nothing.
- **Store the mode in `Info.plist` and re-sign on change.** Rejected: it
  is the only design that makes the Dock icon hide from the first frame,
  but it breaks the v1 rule that the bundle is immutable after creation
  and makes every mode change a `codesign` run. Goal 4 says no.
- **Do nothing.** Rejected: both features are in the v1 Non-Goals as
  deferred, not dropped, and they are the two Fluid features people ask
  about first.

## 6. Acceptance Criteria

- GIVEN the New App sheet WHEN the user picks Menu bar and clicks Create
  THEN `settings.json` for the new app contains `"mode": "menuBar"`, the
  app launches with a status item showing the site's icon, and no window
  is open.
- GIVEN a Menu bar app with the Dock icon hidden WHEN it is running THEN
  it has no Dock tile and no Cmd-Tab entry, and clicking the status item
  shows a popover with the page.
- GIVEN the popover is open WHEN the user clicks anywhere outside it THEN
  it closes; WHEN the user presses the configured hotkey THEN it opens;
  WHEN the user presses the hotkey again THEN it closes.
- GIVEN the popover is open on a page with a text field WHEN the user
  clicks the field and types THEN the characters appear in the field;
  WHEN the user presses Cmd-A then Cmd-C THEN the field's text is on the
  pasteboard.
- GIVEN the popover is open WHEN the user drags its title area out or
  chooses Open in Window THEN a normal window shows the same page without
  reloading (scroll position and typed text preserved); WHEN the user
  chooses Reattach THEN the window closes and the next status item click
  shows the popover with the same page.
- GIVEN a Floating app WHEN another normal window is activated THEN the
  Floating app's window remains visible above it; GIVEN All Spaces is on
  WHEN the user switches Spaces THEN the window is on the new Space.
- GIVEN a Floating app positioned at the top right WHEN it is quit and
  relaunched THEN it reopens at the same frame; WHEN the mode is switched
  to Window THEN the window uses the Window mode frame, not the floating
  one.
- GIVEN a running Window app WHEN the user changes its mode to Menu bar in
  the maker THEN within 2 seconds the window closes, a status item
  appears, and `codesign -dv` on the bundle shows the same signature as
  before; the bundle's modification date is unchanged.
- GIVEN a 1.x `settings.json` with no `mode` key WHEN the 2.x runtime
  launches the app THEN it behaves as Window mode and rewrites nothing
  until a setting changes.
- GIVEN a 2.x `settings.json` with `"mode": "menuBar"` WHEN a 1.x runtime
  (simulated with the decoder test) reads it THEN decoding succeeds and
  every 1.x field keeps its value.
- WHEN the user records a hotkey already registered by another running
  Rivlet app THE SYSTEM SHALL leave the previous hotkey in place and show
  "Already used by another app" under the recorder.
- WHEN the user records a hotkey with no modifier (a bare letter) THE
  SYSTEM SHALL refuse it and show "Add Command, Option, Control, or Shift".
- GIVEN a Menu bar app WHEN the status item cannot be created (menu bar
  full, `NSStatusBar` returns an item with no button) THEN the app falls
  back to Window mode for this launch and logs one line; it does not
  crash and does not rewrite the mode.
- GIVEN a Menu bar app WHEN a popup (sign-in window) is requested THEN it
  opens as a normal window exactly as in v1 and the popover stays open.

## 7. Scope and Boundaries

**Allowed write paths:**
- `RivletRuntime/Settings/AppSettings.swift` (new fields)
- `RivletRuntime/Modes/` (new: `ModePresenter.swift`,
  `WindowPresenter.swift`, `FloatingPresenter.swift`,
  `MenuBarPresenter.swift`, `HotkeyRegistrar.swift`,
  `HotkeyRecorderView.swift`, `ModeCoordinator.swift`)
- `RivletRuntime/Core/Entry.swift`, `RivletRuntime/Core/RuntimeAppDelegate.swift`,
  `RivletRuntime/Core/RuntimeContext.swift`, `RivletRuntime/Web/WindowManager.swift`,
  `RivletRuntime/Web/BrowserWindowController.swift`
- `RivletRuntime/UI/MenuBuilder.swift`, `RivletRuntime/UI/RuntimeSettingsView.swift`
- `Rivlet/Views/NewAppSheet.swift`, `Rivlet/Views/AppDetailView.swift`,
  `Rivlet/Builder/AppBundleWriter.swift` (seed the mode), `Rivlet/AppState.swift`
- `RivletRuntimeTests/`, `RivletTests/`
- `README.md`, `CHANGELOG.md`, `CLAUDE.md` (Architecture line for modes),
  `docs/specs/rivlet-v2.md`
- `project.yml` only if a new source folder needs a group (XcodeGen picks
  up `RivletRuntime/Modes/` automatically; expect no edit)

**Read-only context:**
- `docs/specs/rivlet-v1.md` (the model this builds on)
- Mac app styling conventions in the dev-standards repo
  (`docs/mac-app-styling.md`, Menu bar apps section)
- `RivletStub/`, `RivletStub/Template/Info.plist`, `scripts/assemble-template.sh`
  (the stub and template are frozen; a diff here is a spec violation)
- `projects/inkling-labs-website/docs/copy/rivlet.md` (copy context; any
  change goes through Matt per the Context note below)

**Do not touch:**
- The stub, the entry point signature, the template bundle layout, or the
  `RivletTemplateVersion` value
- Any generated app's `Info.plist` or signature
- `.github/workflows/release.yml`, the Sparkle feed, `main`, tags, releases
- inkling-labs.com (no copy, download, or privacy page change without Matt)

If this spec conflicts with an ad-hoc prompt, this spec wins.

## 8. Verification

Commands from `CLAUDE.md`:

```bash
xcodegen generate
xcodebuild -project Rivlet.xcodeproj -scheme Rivlet -configuration Debug build
xcodebuild -project Rivlet.xcodeproj -scheme Rivlet test
```

Bundle untouched by a mode change (run before and after switching an app's
mode in the maker; both outputs must match):

```bash
codesign -dv --verbose=2 ~/Applications/Gmail.app 2>&1 | grep -E 'CDHash|Signature'
stat -f '%m' ~/Applications/Gmail.app
cat "$HOME/Library/Application Support/Rivlet/Apps/$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' ~/Applications/Gmail.app/Contents/Info.plist)/settings.json"
```

Manual pass: make a Menu bar app for a chat site, set a hotkey, hide the
Dock icon, type in the popover, copy and paste, detach, reattach, quit and
relaunch and confirm the hotkey still works. Make a Floating app for a
music site, pin it across Spaces, move it, relaunch, confirm the frame.
Switch the chat app to Window from the maker while it runs. Launch a 1.0.2
generated app against the 2.0 runtime and a 2.0 settings file against the
1.0.2 decoder test.

## 9. Open Questions

| Question | Resolved by | Blocks implementation? |
|---|---|---|
| ~~Dock icon bounce at launch of a hidden-Dock app~~ Resolved: accepted for 1.1.0. A "bake into bundle" option that sets `LSUIElement` and re-signs is a later spec if people complain. | Matt, 2026-10-06 | No |
| ~~Popover header or bare~~ Resolved: 28 pt header with the site name and a detach button. | Matt, 2026-10-06 | No |
| ~~Hotkey while detached~~ Resolved: brings the detached window forward. | Matt, 2026-10-06 | No |
| ~~Version number~~ Resolved: 1.1.0. Settings stay compatible both ways, so this is additive. | Matt, 2026-10-06 | No |
| Does the website's Rivlet page or copy context need a "modes" line? Held until Matt says the website can change. | Matt | No |

## Risks

- **Popover focus and keyboard.** `NSPopover` content does not always
  become first responder on open, and WebKit's input handling inside a
  child window has a history of dropped key equivalents. Mitigation: make
  the web view first responder on `popoverDidShow`; keep the main menu
  installed in accessory mode so key equivalents route through it; one
  acceptance criterion exercises typing, Cmd-A, Cmd-C directly. If it
  cannot be made solid in T003, the fallback is the custom `NSPanel`
  alternative behind the same `ModePresenter` protocol.
- **Runtime version skew.** Stubs never change, so the real skew cases
  are (a) a new runtime reading an old `settings.json` and (b) an old
  runtime reading a new one. Both are covered by the decoder defaults and
  by two acceptance criteria. A third case: Sparkle replaces `Rivlet.app`
  while a generated app has the old framework `dlopen`ed. The running app
  keeps its mapped pages and the runtime has no lazily loaded resources, so
  it keeps working until relaunch; this is already v1 behavior.
- **Accessory activation and the maker.** When the Dock icon is hidden,
  `NSWorkspace.openApplication` with `activates = true` from the maker
  still works, but the app shows no window; "Open" in the maker for a Menu
  bar app should open the popover instead. Handled in T008.
- **Hotkey collisions with system shortcuts.** Carbon registration
  succeeds even for combos the system owns (Cmd-Space). The recorder
  refuses a short list of known system combos and otherwise lets the user
  decide.
- **Transient popover versus OAuth popups.** A sign-in popup opened from
  the popover is a separate window, so the popover closes when the popup
  takes focus. The sign-in still completes in the web view; the user
  reopens the popover. Acceptable, and noted in the Mode pane help text.

## Acceptance checklist

- [x] T001 Settings model: mode, menu bar and floating options, hotkey, decode tests both directions
- [x] T002 ModePresenter protocol, WindowPresenter, ModeCoordinator with live switch and distributed notification
- [ ] T003 MenuBarPresenter: status item with site icon, popover hosting the web view, click toggle, right-click menu, Escape
- [ ] T004 [P] Global hotkey registrar and recorder view with collision and no-modifier handling
- [ ] T005 [P] Detach popover to the main window and reattach, state preserved
- [ ] T006 [P] FloatingPresenter: floating level, all Spaces option, separate frame autosave
- [ ] T007 Runtime Settings Mode pane with per-mode options and help text
- [ ] T008 Maker: mode picker in New App sheet and app detail, seed on create, notify running app, Open behavior for menu bar apps
- [ ] T009 README, changelog, CLAUDE.md architecture line, release prep held for Matt

---

> Update this spec in the same commit as the code it describes. A spec that
> no longer matches the code is worse than no spec.
