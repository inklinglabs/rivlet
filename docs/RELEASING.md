# Releasing Rivlet

Follows the Inkling Labs standard flow (dev-standards STANDARDS.md): only
Matt pushes `main` and tags. The `v*` tag push runs
`.github/workflows/release.yml`, which builds, signs, notarizes, packages a
DMG, generates the Sparkle appcast, and creates the GitHub release.

Everything is hosted on GitHub Releases. There is no second publish step.

## How hosting works

- `SUFeedURL` is
  `https://github.com/inklinglabs/rivlet/releases/latest/download/appcast.xml`.
  GitHub redirects `latest/download/<asset>` to the newest release that is
  neither a draft nor a prerelease, and Sparkle follows redirects. The feed
  URL never changes.
- Each release carries three assets:
  - `Rivlet-<version>.dmg`: the enclosure the appcast points at, under
    `https://github.com/inklinglabs/rivlet/releases/download/v<version>/`.
  - `Rivlet.dmg`: a byte copy with no version in the name. It makes
    `https://github.com/inklinglabs/rivlet/releases/latest/download/Rivlet.dmg`
    a permanent download link for the README and the website.
  - `appcast.xml`: the feed, listing only that release. Sparkle only needs
    the newest entry.

Two rules follow, and breaking either one silently strands users:

1. **Never leave a real release as a draft or mark it a prerelease.**
   "latest" skips those, so nobody would be offered the update.
2. **Never delete or replace a published DMG.** The appcast's EdDSA
   signature is over the DMG's exact bytes. Ship a new version instead.

## One-time setup: the Sparkle secret

There is one Sparkle EdDSA key pair for all Inkling Labs apps. It lives in
Matt's login keychain and in the 1Password item "Handybar Sparkle" (fields
`private_key`, `public_key`). Do not run `generate_keys`; a new key would
orphan every installed copy of every app.

`SUPublicEDKey` in `Rivlet/Info.plist` is already the shared public key.
Set this repo's private-key secret once:

```bash
cd ~/Development/inkling-labs/projects/rivlet && python3 scripts/set_sparkle_secret.py
```

The script reads the key from 1Password (Touch ID prompt), checks that the
public key matches Info.plist, and sets the repo secret
`SPARKLE_PRIVATE_KEY`. It never prints or stores the private key. The
workflow fails at its first step if the secret is missing.

## Each release

1. On `dev`: bump `CFBundleShortVersionString` in `Rivlet/Info.plist` and
   add a `CHANGELOG.md` entry. Leave `CFBundleVersion` alone; the workflow
   sets it from the tag, because Sparkle compares that value, not the
   marketing version.
2. Open the dev-to-main PR and merge it.
3. Tag from `main`. The guard refuses to tag if the merge did not land:

   ```bash
   cd ~/Development/inkling-labs/projects/rivlet && git checkout main && git pull && [ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Rivlet/Info.plist)" = "X.Y.Z" ] && git tag vX.Y.Z && git push origin vX.Y.Z
   ```

4. When the workflow finishes, verify:

   ```bash
   cd ~/Development/inkling-labs/projects/rivlet && gh release view vX.Y.Z --json isDraft,isPrerelease,assets
   curl -sIL https://github.com/inklinglabs/rivlet/releases/latest/download/appcast.xml | grep -i '^HTTP'
   curl -sL https://github.com/inklinglabs/rivlet/releases/latest/download/appcast.xml | grep -E 'sparkle:(version|edSignature)|enclosure url'
   spctl -a -vv /Applications/Rivlet.app
   ```

   Expect three assets, not draft, not prerelease; a final `200`; the new
   version with an `edSignature`; and "Notarized Developer ID".

## What the workflow does that is easy to get wrong

- Sets `CFBundleVersion` from the tag.
- Re-signs Sparkle's nested helpers (Installer.xpc, Downloader.xpc,
  Autoupdate, Updater.app) inside out with Developer ID, `--timestamp` and
  `--options=runtime`, then the framework, then the app, and verifies each.
  Without this Apple returns notarization status Invalid.
- Reads the notarization status itself and prints `notarytool log` when it
  is not Accepted, instead of failing later at the staple.
- Checks that the appcast carries an `edSignature` and the versioned
  download URL before creating the release.

## Notes

- Generated apps never need updating: they load the runtime out of the installed Rivlet.app, so a Rivlet update reaches every app on next launch.
- A local build without the Developer ID will not update into a signed
  release cleanly. That is expected.
- This repo is public. The workflow's only trigger is a `v*` tag push.
  Never add `pull_request` or `pull_request_target` to it.
