# Spec: Download Location

**Repo:** rivlet
**Created:** 2026-10-21

## 1. Problem
Every generated app saves downloads to the user's Downloads folder. There is
no way to point an app at a different folder and no way to be asked where a
file should go. Someone who makes a Rivlet app for a tool that produces
exports or invoices has to move every file by hand afterward.

## 2. Goals
- Each generated app can save downloads to a folder the user picks.
- Each generated app can instead ask for a destination on every download,
  with the folder and filename both editable.
- Apps made before this change keep saving to Downloads with no change in
  behavior and no settings migration.
- The choice is made in the generated app's own Settings window and takes
  effect on the next download, without a restart.

## 3. Non-Goals
- A Rivlet-wide default seeded into new apps. Per-app only, as decided.
  Every other setting is per-app and the maker has no global settings yet.
- Exposing the setting in the maker's app detail view. It is a runtime
  concern, like badges and the user agent, which the maker also leaves
  alone.
- A download list or progress UI. Finder's Downloads stack bounce covers the
  common case today and this pass does not change that.
- Sandboxing or security-scoped bookmarks. Generated apps are not sandboxed
  (`ENABLE_APP_SANDBOX: false` in `project.yml`), so a plain path works.

## 4. Proposed Approach
`AppSettings` gains one field:

```swift
/// nil means ~/Downloads. Added in 1.1; older runtimes ignore it.
public var downloadFolder: String?
/// Ask for folder and filename on every download. Added in 1.1.
public var askWhereToSaveDownloads = false
```

Two flat keys rather than an enum with a payload, because the existing
decoder pattern (decodeIfPresent with a default per key) handles them with
no custom coding, and an old runtime reading a new file ignores both. The
path is stored as written by the open panel, home expanded, no tilde.

`DownloadManager.decideDestinationUsing` becomes:

1. If `askWhereToSaveDownloads`, show an `NSSavePanel` with
   `nameFieldStringValue` set to the suggested filename and
   `directoryURL` set to the resolved download folder. Cancel returns nil,
   which WebKit treats as cancelling the download. The panel is attached to
   the key window as a sheet when one exists, otherwise run modally.
2. Otherwise resolve the folder: `downloadFolder` if it is set and is an
   existing directory, else `~/Downloads`. Save with the existing
   `uniqueURL` naming.

`DownloadManager` gets a reference to `SettingsStore` through
`RuntimeContext` so it reads the live setting on each download.

`downloadDidFinish` posts the `com.apple.DownloadFileFinished` notification
only when the saved file's parent is the real Downloads folder. Finder's
stack bounce means nothing for other folders. The `requestUserAttention`
call stays for every download.

Settings UI: a "Downloads" section in the General pane of
`RuntimeSettingsView`, between Notifications and Browser identity:

- Picker (radio style): "Save to folder" and "Ask where to save each file".
- Under "Save to folder": the current folder path (Downloads when nil) and a
  "Choose..." button that opens an `NSOpenPanel` for directories. Choosing
  the real Downloads folder stores nil so the default stays the default.
- A caption: "Applies to the next download."

Trade-off: the save panel runs on the main actor while WebKit waits for the
async destination callback. WebKit tolerates this (Safari does the same),
but a second download starting while a panel is up queues behind it. That is
acceptable; a stack of panels would be worse.

## 5. Alternatives Considered
- **One `downloads` enum with an associated path.** Cleaner model, but it
  needs custom Codable and a custom "unknown case" fallback like `mode`
  has. Two flat keys get the same behavior for free. Rejected.
- **Ask for the folder only, keep the filename.** Safari's "Ask for each
  download" gives both, users expect both, and `NSSavePanel` is the same
  amount of code as `NSOpenPanel`. Rejected.
- **Do nothing and tell users to change Safari's download folder.**
  Rivlet apps do not read Safari's preference and should not. Rejected.

## 6. Acceptance Criteria
- GIVEN a 1.0 `settings.json` with neither new key WHEN the runtime decodes
  it THEN `downloadFolder` is nil and `askWhereToSaveDownloads` is false.
- GIVEN `downloadFolder` set to an existing directory WHEN a download
  finishes THEN the file is in that directory and no
  `com.apple.DownloadFileFinished` notification is posted.
- GIVEN `downloadFolder` set to a path that no longer exists WHEN a download
  starts THEN the file is saved to `~/Downloads` and a line is logged with
  the missing path.
- GIVEN `askWhereToSaveDownloads` true WHEN a download starts THEN a save
  panel appears with the suggested filename filled in, and the file is
  written where the user confirms.
- GIVEN the save panel is up WHEN the user cancels THEN no file is written
  and the download ends without an error dialog.
- GIVEN the Settings window WHEN the user picks the real Downloads folder in
  Choose... THEN `settings.json` has no `downloadFolder` key.
- GIVEN the user changes the setting WHEN the next download starts THEN the
  new setting is used without restarting the app.

## 7. Scope and Boundaries
**Allowed write paths:**
- `RivletRuntime/Settings/AppSettings.swift`
- `RivletRuntime/Web/DownloadManager.swift`
- `RivletRuntime/Core/RuntimeContext.swift`
- `RivletRuntime/UI/RuntimeSettingsView.swift`
- `RivletRuntimeTests/BadgeAndSettingsTests.swift`
- `CHANGELOG.md`, `README.md`, `docs/specs/download-location.md`

**Read-only context:**
- `docs/specs/rivlet-v2.md` (the settings compatibility rules this follows)

**Do not touch:**
- The maker app (`Rivlet/`), the stub, `project.yml`, the bundle format.
- Website, copy, or privacy page. Downloads never leave the machine.

If this spec conflicts with an ad-hoc prompt, this spec wins.

## 8. Verification
```bash
xcodegen generate
xcodebuild -project Rivlet.xcodeproj -scheme Rivlet -configuration Debug build
xcodebuild -project Rivlet.xcodeproj -scheme Rivlet test
```
Then by hand in a generated app: set a folder, download a file, confirm
the location; switch to ask, download, cancel once and confirm once.

## 9. Open Questions
| Question | Resolved by | Blocks implementation? |
|---|---|---|
| Should the folder picker also appear in the maker's detail view later? | After v1 | No |

## Acceptance checklist

- [x] T001 Settings model: downloadFolder and askWhereToSaveDownloads with decode tests
- [x] T002 DownloadManager: resolve folder, missing folder fallback, save panel, cancel, bounce only for Downloads
- [x] T003 Downloads section in the General settings pane with folder chooser
- [x] T004 Changelog and README line

---

> Update this spec in the same commit as the code it describes. A spec that
> no longer matches the code is worse than no spec.
