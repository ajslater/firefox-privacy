#!/usr/bin/env bash
# Create a hardened Firefox profile on macOS:
#   - new profile named "hardened"
#   - arkenfox user.js (via its own updater.sh) + this repo's user-overrides.js
#   - uBlock Origin sideloaded into the profile
#
# Prereq: Firefox installed in /Applications. Safe to re-run (idempotent).
set -euo pipefail

FIREFOX="/Applications/Firefox.app/Contents/MacOS/firefox"
PROFILES_DIR="$HOME/Library/Application Support/Firefox/Profiles"
PROFILE_NAME="hardened"
ARKENFOX_RAW="https://raw.githubusercontent.com/arkenfox/user.js/master"
UBLOCK_XPI_URL="https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ ! -x "$FIREFOX" ]; then
  echo "Firefox not found at /Applications/Firefox.app" >&2
  echo "Install it first:  brew install --cask firefox" >&2
  exit 1
fi

if pgrep -xq firefox; then
  echo "Quit Firefox before running setup." >&2
  exit 1
fi

# Create the profile only if it doesn't already exist. Firefox prefixes
# profile directories with a random salt, hence the glob.
shopt -s nullglob
profiles=("$PROFILES_DIR"/*."$PROFILE_NAME")
if [ ${#profiles[@]} -eq 0 ]; then
  echo "Creating '$PROFILE_NAME' profile..."
  "$FIREFOX" -CreateProfile "$PROFILE_NAME"
  profiles=("$PROFILES_DIR"/*."$PROFILE_NAME")
fi
if [ ${#profiles[@]} -ne 1 ]; then
  echo "Expected exactly one *.$PROFILE_NAME profile in $PROFILES_DIR, found ${#profiles[@]}" >&2
  exit 1
fi
PROFILE="${profiles[0]}"
echo "Profile: $PROFILE"

echo "Installing arkenfox..."
for f in updater.sh prefsCleaner.sh; do
  curl -fsSL "$ARKENFOX_RAW/$f" -o "$PROFILE/$f"
  chmod +x "$PROFILE/$f"
done
cp "$REPO_DIR/user-overrides.js" "$PROFILE/user-overrides.js"
# -s: update user.js without confirmation; -d: skip updater self-update check
# (we just downloaded the latest). Appends user-overrides.js automatically.
bash "$PROFILE/updater.sh" -p "$PROFILE" -s -d

echo "Installing uBlock Origin..."
mkdir -p "$PROFILE/extensions"
curl -fsSL "$UBLOCK_XPI_URL" -o "$PROFILE/extensions/uBlock0@raymondhill.net.xpi"

cat <<EOF

Done. Next steps:
  1. Launch:  "$FIREFOX" -P $PROFILE_NAME
  2. Check about:addons — uBlock Origin should be installed and enabled.
     (If it isn't, install it from https://addons.mozilla.org/firefox/addon/ublock-origin/)
  3. Optional: open about:profiles and click "Set as default profile" on $PROFILE_NAME.
  4. Keep it fresh with:  $REPO_DIR/update-firefox-hardened.sh
EOF
