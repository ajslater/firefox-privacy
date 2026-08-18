#!/usr/bin/env bash
# Notify (macOS notification) when a new arkenfox user.js version is published.
#
#   check-arkenfox-update.sh              run one check (what the LaunchAgent runs)
#   check-arkenfox-update.sh --install    install + start a daily launchd check
#   check-arkenfox-update.sh --uninstall  remove the launchd check
#
# Zero dependencies: bash + curl + osascript all ship with macOS. Compares the
# version header of the hardened profile's user.js against raw master (which is
# exactly what update-firefox-hardened.sh would install), notifies once per new
# version, and stays silent on network failure.
set -euo pipefail

PROFILES_DIR="$HOME/Library/Application Support/Firefox/Profiles"
PROFILE_NAME="hardened"
ARKENFOX_URL="https://raw.githubusercontent.com/arkenfox/user.js/master/user.js"
STATE_FILE="$HOME/Library/Caches/arkenfox-update-check.last"
LABEL="net.slater.arkenfox-update-check"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/arkenfox-update-check.log"
SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

case "${1:-}" in
--install)
  mkdir -p "$HOME/Library/LaunchAgents"
  cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SCRIPT</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key><integer>12</integer>
    <key>Minute</key><integer>0</integer>
  </dict>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "Installed $LABEL: daily check at 12:00 (runs at wake if the Mac was asleep)."
  echo "Note: the first notification may need a one-time allow for Script Editor"
  echo "under System Settings > Notifications."
  exit 0
  ;;
--uninstall)
  launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
  rm -f "$PLIST"
  echo "Removed $LABEL."
  exit 0
  ;;
"") ;;
*)
  echo "Usage: $(basename "$0") [--install|--uninstall]" >&2
  exit 2
  ;;
esac

shopt -s nullglob
profiles=("$PROFILES_DIR"/*."$PROFILE_NAME")
[ ${#profiles[@]} -eq 1 ] || exit 0 # no (or ambiguous) profile: nothing to check
local_v=$(grep -m1 '\* version:' "${profiles[0]}/user.js" 2>/dev/null) || exit 0
# buffer the download before grepping: grep -m1 quitting early would otherwise
# kill curl mid-write (exit 23) and pipefail would abort the comparison
remote_js=$(curl -fsSL --max-time 30 "$ARKENFOX_URL") || exit 0 # offline: stay silent
remote_v=$(grep -m1 '\* version:' <<<"$remote_js") || exit 0

if [ "$remote_v" = "$local_v" ]; then
  echo "arkenfox up to date (v${local_v#*: })"
  exit 0
fi

# notify once per new upstream version
if [ -f "$STATE_FILE" ] && [ "$(cat "$STATE_FILE")" = "$remote_v" ]; then
  exit 0
fi
printf '%s' "$remote_v" >"$STATE_FILE"
osascript -e "display notification \"Profile has v${local_v#*: }, upstream is v${remote_v#*: }. Run update-firefox-hardened.sh\" with title \"arkenfox update available\""
echo "notified: local v${local_v#*: } -> upstream v${remote_v#*: }"
