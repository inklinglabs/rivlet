# Changelog

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
