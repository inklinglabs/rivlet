# Spec: Rivlet 1.2

**Repo:** rivlet
**Created:** 2026-11-12
**Status:** Asked for by Matt 2026-11-12 ("let's do all those bullets"). Ships as 1.2.0.

## 1. Problem

Five things the earlier specs left open are still open in 1.1.0:

- A menu bar app with a hidden Dock icon still shows in the Dock for a
  moment every time it launches, because the icon is hidden at runtime
  after launch.
- A generated app can only be moved to `/Applications` by hand in Finder,
  and when that is done the maker loses track of it, because the registry
  only scans `~/Applications`.
- The download folder can only be changed from inside the running app's
  Settings. The maker's detail view shows the mode but not where downloads
  go.
- The menu bar popover's size is two number fields in Settings. It cannot
  be dragged.
- The global keyboard shortcut only exists in Menu bar mode. A Window or
  Floating app has no shortcut to bring it forward.

## 2. Goals

1. A menu bar app can be set to never show in the Dock, launch included.
2. The maker moves an app between `~/Applications` and `/Applications`
   from the detail view, asks for an admin password only when macOS
   requires one, and keeps the app in its list afterwards.
3. The maker's detail view shows and changes an app's download folder.
4. The popover resizes by dragging its bottom corners, and the size
   sticks.
5. The app's keyboard shortcut works in every mode: it toggles the popover
   in Menu bar mode and brings the window forward (or hides the app if it
   is already in front) in Window and Floating mode.

## 3. Non-Goals

- **Creating new apps straight into `/Applications` for standard users.**
  The New App sheet keeps writing to the chosen folder with the user's own
  rights. Moving afterwards covers it.
- **A separate shortcut per mode.** One shortcut per app. It keeps the
  `menuBar.hotkey` key in `settings.json` so 1.1 files and 1.1 runtimes
  need no migration.
- **Resizing the popover from its top or side edges.** The popover hangs
  from the status item, so only the bottom corners move.
- **Baking anything other than `LSUIElement`.** Mode, shortcut, and every
  other option stay in `settings.json`.
- **A privileged helper tool.** The one admin action (a move a standard
  user cannot do) goes through the system password prompt each time.
- **Version bump, tag, and release.** Held for Matt (see checklist).

## 4. Proposed Approach

**Dock icon baked into the bundle.** `MenuBarOptions` gains
`bakeDockIcon: Bool`, default false, shown in the Mode pane under "Hide the
Dock icon" as "Skip the Dock at launch too". A new public
`BundleBaker` in `RivletRuntime/Core/` owns the one bundle edit: it reads
`LSUIElement` from the bundle's `Info.plist`, and when that differs from
what is wanted it rewrites the key, re-signs ad hoc, bumps the bundle's
modification date, and re-registers the bundle with LaunchServices. Wanted
is `mode == .menuBar && hideDockIcon && bakeDockIcon`; anything else
removes the key, so an app switched back to Window mode gets its normal
launch back. The runtime reconciles its own bundle from
`ModeCoordinator.apply()`, and the maker reconciles from `AppState` when it
changes the mode, so an app that is not running is fixed before its next
launch. If the edit or the signing fails, the option turns itself back off
and the Mode pane says why.

This is a deliberate deviation from the v2 rule that nothing editable
lives in the bundle. The trade: a launch with no Dock bounce needs
`LSUIElement` in `Info.plist` before the process starts, and nothing at
runtime can do that. The deviation is limited to this one key and is
derived from `settings.json`, which stays the source of truth.

**Move between Applications folders.** A new `AppMover` in
`Rivlet/Builder/` moves a bundle to a destination folder. It quits the app
if it is running, tries `FileManager.moveItem` first (an admin user can
write to `/Applications` without a prompt), and only when that fails with
a permission error runs `mv` and `chown` back to the user through
`do shell script ... with administrator privileges`, which puts up the
standard macOS password dialog. The bundle stays owned by the user either
way, so later bakes and Move to Trash keep working. The registry entry
gets the new path, and `AppRegistry.scanForForeignApps` scans
`/Applications` as well as `~/Applications`. The detail view's Location
row gets one button: "Move to Applications" or "Move to My Applications",
whichever applies; an app in any other folder is offered both.

**Download folder in the maker.** The folder logic the runtime Settings
pane uses (resolve, label, "is this just Downloads") moves into a public
`DownloadLocation` helper in `RivletRuntime/Web/` so both sides share it.
The detail view gets a Downloads row with the folder and a Choose button.
`AppState.setMode` is generalized to `updateSettings(for:_:)`, which writes
`settings.json` and posts the existing `settingsChanged` notification.

**Popover drag-resize.** `PopoverContentController` adds a 16 pt grip in
each bottom corner, above the web view. Dragging one sets
`popover.contentSize` live, measured in screen coordinates because the
popover window moves as it resizes. The popover is centered under the
status item, so a corner follows the pointer when the width changes by
twice the horizontal travel; when the popover is pinned against a screen
edge it changes by the travel itself. The size is clamped to
`PopoverSize.minimum` and to the screen's visible frame, and written to
`menuBar.popoverSize` on mouse up. The number fields in Settings stay and
follow along. The trade: the grips cover 16 pt of page in each bottom
corner, accepted because NSPopover offers no chrome of its own to put
them in.

**Shortcut in every mode.** Registration moves from `MenuBarPresenter` to
`ModeCoordinator`, which registers the app's one shortcut and calls the
current presenter's `toggle()`. `WindowPresenter` and `FloatingPresenter`
get a real `toggle()`: hide the app when it is frontmost with its window
showing, otherwise show and activate. The recorder row in the Mode pane
moves out of the Menu bar section so it shows for all three modes. Carbon
`RegisterEventHotKey` needs no permission, so the "permission story" the
v2 spec expected does not exist.

## 5. Alternatives Considered

- **Bake `LSUIElement` for every menu bar app with a hidden Dock icon, no
  option.** Rejected: it re-signs bundles of people who never asked, and
  an `LSUIElement` app switched to Window mode shows its menu bar late.
  An option keeps the v2 behavior as the default.
- **`SMAppService` or an XPC helper for the admin move.** Rejected: a
  daemon to move a folder is more moving parts than the feature, and it
  would need its own notarization and uninstall story.
- **A second, top level `hotkey` key.** Rejected: two keys for one
  shortcut need a migration and can disagree. Reusing `menuBar.hotkey`
  costs a slightly misleading JSON key name and nothing else.
- **Replacing NSPopover with a custom NSPanel to get real resize edges.**
  Rejected for this pass: it was the v2 fallback and v2 did not need it.
  Corner grips get drag-resize without reopening the popover's focus and
  keyboard behavior.

## 6. Acceptance Criteria

- GIVEN a menu bar app with "Hide the Dock icon" on WHEN "Skip the Dock at
  launch too" is turned on THEN the bundle's `Info.plist` has `LSUIElement`
  true, `codesign --verify` passes on the bundle, and the next launch
  shows no Dock icon at any point.
- GIVEN a baked app WHEN its mode is changed to Window, from the maker or
  from its own Settings, THEN `LSUIElement` is gone from `Info.plist` and
  `codesign --verify` passes.
- WHEN the bundle cannot be rewritten or signed THE SYSTEM SHALL turn
  `bakeDockIcon` back off, leave the bundle launchable, and show the
  reason in the Mode pane.
- GIVEN an app in `~/Applications` and an admin user WHEN Move to
  Applications is clicked THEN the bundle is in `/Applications`, no
  password dialog appeared, the app is still in the maker's list with the
  new Location, and it launches.
- GIVEN the same for a standard user THEN one system password dialog
  appears, and after it is answered the bundle is in `/Applications` owned
  by that user.
- WHEN an app with the same name already exists in the destination THE
  SYSTEM SHALL leave both bundles where they are and show an error naming
  the existing app.
- WHEN the password dialog is cancelled THE SYSTEM SHALL leave the bundle
  where it was and show no error.
- GIVEN an app selected in the maker WHEN a folder is chosen in the
  Downloads row THEN `settings.json` has that path in `downloadFolder`,
  and a running copy of the app saves its next download there without a
  restart. Choosing `~/Downloads` stores no path.
- GIVEN an open popover WHEN a bottom corner is dragged THEN the popover
  resizes while dragging, never below 280 by 200, and after mouse up
  `menuBar.popoverSize` holds the new size and the popover reopens at it.
- GIVEN a Window or Floating app with a shortcut WHEN the shortcut is
  pressed from another app THEN the app's window comes to the front and is
  key; pressed again while it is in front, the app hides.
- GIVEN a 1.1 `settings.json` with `menuBar.hotkey` set WHEN 1.2 reads it
  THEN the shortcut is unchanged and works in whatever mode the app is in.
- GIVEN a 1.2 `settings.json` WHEN a 1.1 runtime decodes it THEN the
  decode succeeds and the unknown `bakeDockIcon` key is ignored.

## 7. Scope and Boundaries

**Allowed write paths:**
- `RivletRuntime/Core/BundleBaker.swift` (new)
- `RivletRuntime/Web/DownloadLocation.swift` (new)
- `RivletRuntime/Modes/`, `RivletRuntime/Settings/AppMode.swift`,
  `RivletRuntime/Settings/AppSettings.swift`
- `RivletRuntime/UI/ModeSettingsPane.swift`,
  `RivletRuntime/UI/RuntimeSettingsView.swift`
- `RivletRuntime/Web/DownloadManager.swift`
- `Rivlet/Builder/AppMover.swift` (new), `Rivlet/AppState.swift`,
  `Rivlet/Models/AppRegistry.swift`, `Rivlet/Views/AppDetailView.swift`
- `RivletTests/`, `RivletRuntimeTests/`
- `README.md`, `CHANGELOG.md`, `CLAUDE.md`, this spec

**Read-only context:**
- `docs/specs/rivlet-v1.md`, `docs/specs/rivlet-v2.md`,
  `docs/specs/download-location.md`

**Do not touch:**
- `RivletStub/` and the template bundle layout. A stub built for 1.0 keeps
  working.
- `.github/workflows/release.yml`, the version in `project.yml`, tags.
- The website repo. The modes copy for inkling-labs.com is Matt's to pick
  and is tracked there.

If this spec conflicts with an ad-hoc prompt, this spec wins.

## 8. Verification

```bash
xcodegen generate
xcodebuild -project Rivlet.xcodeproj -scheme Rivlet -configuration Debug build
xcodebuild -project Rivlet.xcodeproj -scheme Rivlet test
```

The Dock, popover, shortcut, and password dialog criteria are checked by
hand on a real Mac; T007 is that pass.

## 9. Open Questions

| Question | Resolved by | Blocks implementation? |
|---|---|---|
| ~~Does re-signing a running app work?~~ Resolved: a throwaway menu bar app on the debug runtime baked itself at launch and unbaked on a live switch to Window mode; `codesign --verify --strict` passed both times and the app kept running (2026-11-12). | Implementation, 2026-11-12 | No |
| Does macOS App Management (TCC) stop the Developer ID signed maker from re-signing an ad hoc bundle it made earlier? The runtime re-signing its own bundle is the primary path either way. | T007, on a release build | No |
| Should "Skip the Dock at launch too" become the default for new menu bar apps once it has shipped for a release? | Matt, after 1.2 | No |

## Risks

- **Re-signing a running app.** `codesign` replaces the executable with a
  new file, so the running process keeps its mapped pages. The bake only
  takes effect at the next launch, which the Mode pane says.
- **`LSUIElement` and the main menu.** An `LSUIElement` app promoted to a
  regular app at runtime can show its menu bar late. The baker removes the
  key whenever the app is not a hidden-Dock menu bar app, so this is
  limited to the first launch after a mode change made while the app was
  not running and the maker was not the one changing it.
- **Scanning `/Applications`.** Reading `Info.plist` of every app there on
  each registry load is a few hundred small file reads. Bundles without
  the `RivletApp` key are skipped before anything else is read.
- **Shortcut that hides.** A user who expects "bring forward" only may be
  surprised by the hide on second press. It matches the popover toggle and
  every launcher people use this for.

## Acceptance checklist

- [x] T001 Settings model: bakeDockIcon, one shortcut for every mode, decode tests both directions
- [x] T002 [P] BundleBaker: LSUIElement reconcile and re-sign, called from runtime and maker, failure turns the option off
- [x] T003 [P] Shortcut in Window and Floating mode: registration in ModeCoordinator, show or hide toggle, Mode pane row for all modes
- [x] T004 [P] Popover drag-resize from the bottom corners, clamped and saved
- [x] T005 [P] Maker: Move to Applications and back with admin fallback, registry scans /Applications
- [x] T006 [P] Maker: Downloads row in app detail, shared DownloadLocation helper
- [x] T007 Hands-on pass on a release build: Dock at launch, popover drag, shortcut in each mode, password dialog as a standard user
- [x] T008 README, changelog, CLAUDE.md architecture lines
- [x] T009 Release prep held for Matt: version bump to 1.2.0, changelog date, dev-to-main PR
- [x] T010 Website: modes copy on the Rivlet page and in the copy context, from the options Matt picks

---

> Update this spec in the same commit as the code it describes. A spec that
> no longer matches the code is worse than no spec.
