# Changelog

## 1.2.0 (2026-11-25)

- New: the keyboard shortcut works in every mode. In Window and Floating
  mode it brings the app to the front from anywhere, and hides it when it
  is already in front. A shortcut you set for a menu bar app carries over.
- New: drag a bottom corner of a menu bar app's popover to resize it. The
  size sticks.
- New: a menu bar app can skip the Dock while it launches, not only after.
  Turn on "Skip the Dock at launch too" in the app's Settings under Mode.
  This is the one setting that changes the app itself, so Rivlet signs
  the app again on your Mac when you switch it.
- New: move an app to the Mac's Applications folder, or back to your own,
  from Rivlet. You are asked for an administrator password only if your
  account needs one. Apps in /Applications now show up in Rivlet's list.
- New: choose an app's download folder from Rivlet, without opening the
  app's own Settings.
- Fixed: an app's Settings window was taller than a 13 inch screen.
  General is now three tabs: General, Alerts for the Dock badge and
  notifications, and Advanced for the custom user agent.
- Fixed: in New App, changing the web address after the first lookup
  updated the icon but left the old name. The name now follows the
  address until you type your own.

## 1.1.0 (2026-10-21)

- New: every app has a mode. Window is what you had. Menu bar puts the
  app in the menu bar with the page in a popover, with a global keyboard
  shortcut, an optional hidden Dock icon, and Open in Window when you
  want a real window for a while. Floating keeps the window above
  everything else and can follow you across Spaces. Pick the mode when
  you make the app or change it later, in Rivlet or in the app's own
  Settings. Changes take effect while the app runs; nothing is rebuilt.
- New: each app can save downloads to a folder you pick, or ask where to
  put every file. Set it in the app's Settings under General. Downloads
  still go to your Downloads folder unless you change it.
- Fixed: opening an app no longer rewrites its settings file when nothing
  changed.

## 1.0.2 (2026-10-05)

- Fixed: switching away from Rivlet and back no longer loses the app you
  had selected.
- Fixed: apps kept outside your Applications folder no longer drop out of
  the list. If one went missing, it is still on disk and still runs.

## 1.0.1 (2026-10-05)

- Fixed: a new app that reused the name of an earlier one could show the
  earlier app's icon in the Dock instead of the icon you chose.

## 1.0.0 (2026-09-28)

- First version. Make a Mac app from any website: own Dock icon, own logins
  and cookies, Dock badge from the page title or the Badging API, Web
  Notifications forwarded to Notification Center, per-app userscripts and
  custom CSS, and a link rule that keeps the site in the app and sends
  everything else to your default browser. Generated apps are under 1 MB
  and share one runtime, so updating Rivlet updates all of them.
