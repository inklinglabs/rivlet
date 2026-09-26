# Rivlet

Give any website its own Mac app.

Rivlet turns a URL into a real app in your Applications folder. The app has
its own Dock icon, its own logins and cookies, a badge count, Notification
Center alerts, and your own scripts and CSS if you want them. It is a lean,
open source successor to Fluid, built on the WebKit that ships with macOS.
No Electron, no bundled browser, no subscription.

Requires macOS 26 or later. MIT licensed.

## How it works

Every app Rivlet makes is under a megabyte. It is a real bundle with its
own bundle ID, so macOS treats it as a separate app, but its executable is
a tiny stub that loads `RivletRuntime.framework` out of the installed
Rivlet.app. One Rivlet update updates every app the next time it opens.
If you delete Rivlet, the apps show a short message pointing you back to
the download.

Editable state (link rules, userscripts, custom CSS) lives in
`~/Library/Application Support/Rivlet/Apps/<bundle id>/`. Logins and site
data live where WebKit keeps them for any app, under `~/Library/WebKit/`.

## What it does

- Creates the app in seconds from a URL. Rivlet fetches the site's name
  and best icon; drop your own PNG to override.
- Keeps each app's cookies and storage separate from Safari and from every
  other Rivlet app.
- Opens links to the site itself inside the app and everything else in
  your default browser. Sign-in popups (Google, Microsoft, Apple, Okta,
  Auth0) work.
- Shows a Dock badge from counts in the page title, like `(3) Inbox`, or
  from the Badging API.
- Forwards the site's Web Notifications to Notification Center under the
  app's own name. Clicking one brings the app forward.
- Runs your userscripts and custom CSS per app, with Greasemonkey style
  `@include` headers.
- Downloads to your Downloads folder, camera and microphone prompts,
  find in page, zoom, print, full screen, and a toolbar you can hide.

## What it does not do

- Browser extensions. WKWebView cannot load them. Userscripts and CSS
  cover the common cases.
- Tabs. One site per app. Links that would open a tab open a window or
  your browser instead.
- Run on another Mac. Generated apps are signed locally for the Mac that
  made them. Make them again on the other Mac.
- Run without Rivlet installed. See above.

## Install

Download the latest DMG from
[Releases](https://github.com/inklinglabs/rivlet/releases/latest) and drag
Rivlet to Applications. Rivlet updates itself through Sparkle.

## Build from source

```bash
brew install xcodegen
xcodegen generate
xcodebuild -project Rivlet.xcodeproj -scheme Rivlet -configuration Debug build
xcodebuild -project Rivlet.xcodeproj -scheme Rivlet test
```

The design and acceptance criteria are in
[docs/specs/rivlet-v1.md](docs/specs/rivlet-v1.md). Releases follow
[docs/RELEASING.md](docs/RELEASING.md). Work happens on `dev`; `main` only
moves at release time.

## Privacy

Rivlet contacts the network twice on its own: once to fetch a site's name
and icon when you make an app, and to check GitHub Releases for updates.
Generated apps talk only to the site you gave them. There are no analytics.

Made by [Inkling Labs](https://inkling-labs.com).
