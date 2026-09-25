# CLAUDE.md

This file provides guidance to Claude Code when working with code in this
repository.

## What this is

Rivlet: give any website its own Mac app. A lean, open source successor to
Fluid built on WKWebView. Rivlet.app is the maker; each generated app is a
tiny stub bundle that loads the shared `RivletRuntime.framework` out of
Rivlet.app, so one update updates every app.

## Standards

This repo follows the Inkling Labs standards
(github.com/inklinglabs/inkling-labs-dev-standards, STANDARDS.md). The short version:

- Work on `dev` or a feature branch. PRs into `dev` are fine.
- Never push to `main`, merge into `main`, or push tags. Matt does those.
- Releases: prepare the version bump, changelog, and dev-to-main PR, then
  print the tag commands for Matt. The `v*` tag triggers the release
  workflow.
- Secrets use the canonical names from STANDARDS.md. Never print or store
  secret values.
- No em dashes in any prose or docs.

## Styling

UI design language and Mac app patterns live in the dev-standards repo at
`docs/mac-app-styling.md` (locally
`~/Development/inkling-labs/dev-standards/docs/mac-app-styling.md`). Follow
it for colors, typography, window layout, and settings. Bundle ID:
`com.inklinglabs.rivlet`. Generated apps use
`com.inklinglabs.rivlet.app.<slug>-<hex>`.

## Commands

- `xcodegen generate` regenerates `Rivlet.xcodeproj` from `project.yml`
  (the `.xcodeproj` is gitignored; rerun after changing `project.yml` or
  adding files).
- Build: `xcodebuild -project Rivlet.xcodeproj -scheme Rivlet -configuration Debug build`
- Test: `xcodebuild -project Rivlet.xcodeproj -scheme Rivlet test`

## Architecture

- SwiftUI maker app, Swift 6 strict concurrency, macOS 26.0 minimum, no
  sandbox (writes app bundles into `~/Applications` and ad-hoc signs them).
- `Rivlet/` maker app, `RivletRuntime/` framework (everything a generated
  app does at runtime), `RivletStub/` C stub, tests in `RivletTests/` and
  `RivletRuntimeTests/` (Swift Testing).
- The v1 design, including the stub-plus-shared-framework model and the
  bundle anatomy, lives in [docs/specs/rivlet-v1.md](docs/specs/rivlet-v1.md).
- Updates: Sparkle 2 via SPM in the maker only, feed on GitHub Releases,
  following Palilogy's `Updates/` pattern.
- Free and MIT. No licensing code.

## Specs and Todoist

Spec checklists mirror into the Todoist project "App - Rivlet" under the
global Spec-to-Todoist sync rule in `~/.claude/CLAUDE.md`.
