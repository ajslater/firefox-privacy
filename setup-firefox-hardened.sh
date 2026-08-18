#!/usr/bin/env bash
# Create a hardened Firefox profile on macOS:
#   - new profile named "hardened"
#   - arkenfox user.js (via its own updater.sh) + this repo's user-overrides.js
#   - uBlock Origin sideloaded into the profile
#
# Prereq: Firefox installed in /Applications. Safe to re-run (idempotent).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$REPO_DIR/lib.sh"

FIREFOX="/Applications/Firefox.app/Contents/MacOS/firefox"
UBLOCK_XPI_URL="https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi"
UBLOCK_XPI="uBlock0@raymondhill.net.xpi"

[ $# -eq 0 ] || die "Usage: $(basename "$0")"

[ -x "$FIREFOX" ] ||
  die "Firefox not found at /Applications/Firefox.app. Install it first: brew install --cask firefox"

# -CreateProfile hands off to an already-running instance, so provisioning needs
# every Firefox closed, not just this profile. (The update script is narrower.)
! pgrep -xq firefox || die "Quit Firefox before running setup."

if ! find_profile; then
  echo "Creating '$PROFILE_NAME' profile..."
  "$FIREFOX" -CreateProfile "$PROFILE_NAME"
  find_profile ||
    die "Firefox created no '$PROFILE_NAME' profile. If that name still appears in
about:profiles (a leftover entry whose directory was deleted), remove it there
and re-run — Firefox silently refuses to reuse a registered profile name."
fi
echo "Profile: $PROFILE"

echo "Installing arkenfox..."
install_arkenfox

echo "Installing uBlock Origin..."
mkdir -p "$PROFILE/extensions"
if [ -f "$PROFILE/extensions/$UBLOCK_XPI" ]; then
  echo "  Already installed — leaving it alone; Firefox keeps it updated."
else
  fetch "$UBLOCK_XPI_URL" "$PROFILE/extensions/$UBLOCK_XPI" is_zip
fi

cat <<EOF

Done. Next steps:
  1. Launch:  "$FIREFOX" -P $PROFILE_NAME
  2. Check about:addons — uBlock Origin should be installed and enabled, and
     worth turning on "Run in Private Windows" while you are there.
     (If it is missing, install it from https://addons.mozilla.org/firefox/addon/ublock-origin/)
  3. Optional: open about:profiles and click "Set as default profile" on $PROFILE_NAME.
  4. Keep it fresh with:  $REPO_DIR/update-firefox-hardened.sh
  5. Optional: get notified of new arkenfox releases:
     $REPO_DIR/check-arkenfox-update.sh --install
EOF
