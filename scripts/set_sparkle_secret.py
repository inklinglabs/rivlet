#!/usr/bin/env python3

"""Set this repo's Sparkle signing secret from 1Password.

There is ONE Sparkle EdDSA key pair for all Inkling Labs apps. It already
exists in Matt's login keychain and in the 1Password item "Handybar Sparkle"
(fields private_key, public_key). This script reuses it: it sets the repo
secret SPARKLE_PRIVATE_KEY for inklinglabs/rivlet and checks that the
public key in Rivlet/Info.plist matches the one in 1Password.

It never generates a key (do NOT run generate_keys), never writes the
private key to disk, and never prints it. 1Password prompts (Touch ID)
when the script runs.

Usage:
    cd ~/Development/inkling-labs/projects/rivlet && python3 scripts/set_sparkle_secret.py

Requires the 1Password CLI with desktop app integration and gh authenticated
for the inklinglabs/rivlet repo.
"""

import logging
import plistlib
import subprocess
import sys
from pathlib import Path

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
log = logging.getLogger(__name__)

REPO = "inklinglabs/rivlet"
VAULT = "Inkling Labs"
ITEM = "Handybar Sparkle"
PRIVATE_KEY_REF = f"op://{VAULT}/{ITEM}/private_key"
PUBLIC_KEY_REF = f"op://{VAULT}/{ITEM}/public_key"
INFO_PLIST = Path(__file__).resolve().parent.parent / "Rivlet" / "Info.plist"


def op_read(reference):
    try:
        result = subprocess.run(["op", "read", reference], capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        log.error("op read failed for %s: %s", reference, e.stderr.strip())
        log.error("Check the vault/item/field names at the top of this script.")
        sys.exit(1)


def set_repo_secret(name, value):
    try:
        subprocess.run(
            ["gh", "secret", "set", name, "--repo", REPO],
            input=value, text=True, check=True, capture_output=True,
        )
        log.info("%s: %s set", REPO, name)
    except subprocess.CalledProcessError as e:
        log.error("%s failed: %s", name, e.stderr.strip())
        sys.exit(1)


def check_public_key(public_key):
    with open(INFO_PLIST, "rb") as f:
        committed = plistlib.load(f).get("SUPublicEDKey", "")
    if committed != public_key:
        log.error("SUPublicEDKey in %s does not match 1Password.", INFO_PLIST.name)
        log.error("Updates signed with this key would be rejected. Fix Info.plist before releasing.")
        sys.exit(1)
    log.info("Info.plist SUPublicEDKey matches 1Password")


def main():
    log.info("Pulling values from 1Password (expect a prompt)...")
    public_key = op_read(PUBLIC_KEY_REF)
    if len(public_key) != 44 or not public_key.endswith("="):
        log.error("public_key does not look like a base64 Ed25519 key (expected 44 characters)")
        sys.exit(1)
    check_public_key(public_key)
    set_repo_secret("SPARKLE_PRIVATE_KEY", op_read(PRIVATE_KEY_REF))
    log.info("Done. The next tagged release will ship a signed appcast.")


if __name__ == "__main__":
    main()
