#!/usr/bin/env bash
# Refresh the hardened Firefox profile:
#   - re-sync user-overrides.js from this repo into the profile
#   - fetch the latest arkenfox updater/prefsCleaner and run the updater
#     (downloads latest user.js and re-appends the overrides)
#   - with --clean, also run prefsCleaner.sh to purge stale prefs from prefs.js
#
# uBlock Origin updates itself through Firefox's normal add-on updates.
set -euo pipefail

PROFILES_DIR="$HOME/Library/Application Support/Firefox/Profiles"
PROFILE_NAME="hardened"
ARKENFOX_RAW="https://raw.githubusercontent.com/arkenfox/user.js/master"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if pgrep -xq firefox; then
  echo "Quit Firefox before updating (it rewrites prefs.js on exit)." >&2
  exit 1
fi

shopt -s nullglob
profiles=("$PROFILES_DIR"/*."$PROFILE_NAME")
if [ ${#profiles[@]} -eq 0 ]; then
  echo "No *.$PROFILE_NAME profile found — run setup-firefox-hardened.sh first." >&2
  exit 1
elif [ ${#profiles[@]} -gt 1 ]; then
  echo "Multiple *.$PROFILE_NAME profiles found:" >&2
  printf '  %s\n' "${profiles[@]}" >&2
  exit 1
fi
PROFILE="${profiles[0]}"
echo "Profile: $PROFILE"

cp "$REPO_DIR/user-overrides.js" "$PROFILE/user-overrides.js"

for f in updater.sh prefsCleaner.sh; do
  curl -fsSL "$ARKENFOX_RAW/$f" -o "$PROFILE/$f"
  chmod +x "$PROFILE/$f"
done
bash "$PROFILE/updater.sh" -p "$PROFILE" -s -d

if [ "${1:-}" = "--clean" ]; then
  # prefsCleaner works on the profile in its own directory; -s skips the prompt
  (cd "$PROFILE" && bash prefsCleaner.sh -s)
fi

echo "Update complete."
