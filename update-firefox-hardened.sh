#!/usr/bin/env bash
# Refresh the hardened Firefox profile:
#   - re-sync user-overrides.js from this repo into the profile
#   - fetch the latest arkenfox updater/prefsCleaner and run the updater
#     (downloads latest user.js and re-appends the overrides)
#   - with --clean, also run prefsCleaner.sh to purge stale prefs from prefs.js
#
# uBlock Origin updates itself through Firefox's normal add-on updates.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "$REPO_DIR/lib.sh"

CLEAN=false
case "${1:-}" in
"") ;;
--clean) CLEAN=true ;;
*) die "Usage: $(basename "$0") [--clean]" ;;
esac
[ $# -le 1 ] || die "Usage: $(basename "$0") [--clean]"

find_profile ||
  die "No *.$PROFILE_NAME profile found — run setup-firefox-hardened.sh first."
echo "Profile: $PROFILE"
require_profile_closed

install_arkenfox

if $CLEAN; then
  # prefsCleaner's own in-use check waits on a 'lock' file that Firefox never
  # creates on macOS, so it will rewrite prefs.js right under a running browser.
  # Re-check here: the guard above is two downloads and an updater run old.
  require_profile_closed
  # -s: skip the prompt. -d: skip its self-update, we just fetched it.
  (cd "$PROFILE" && bash prefsCleaner.sh -s -d)
  prune_backups "$PROFILE/prefsjs_backups"
fi

echo "Update complete."
