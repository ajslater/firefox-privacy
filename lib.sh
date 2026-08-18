#!/usr/bin/env bash
# Shared helpers for setup-firefox-hardened.sh and update-firefox-hardened.sh.
# Sourced, not executed. Callers set REPO_DIR and use set -euo pipefail.

PROFILES_DIR="$HOME/Library/Application Support/Firefox/Profiles"
PROFILE_NAME="hardened"
ARKENFOX_RAW="https://raw.githubusercontent.com/arkenfox/user.js/master"
BACKUPS_KEPT=5

die() {
  echo "$*" >&2
  exit 1
}

# Locate the single *.hardened profile and set PROFILE. Firefox prefixes
# profile directories with a random salt, hence the glob. Returns 1 if there
# is none, so callers can decide whether that is fatal.
find_profile() {
  shopt -s nullglob
  local profiles=("$PROFILES_DIR"/*."$PROFILE_NAME")
  case ${#profiles[@]} in
  1) PROFILE="${profiles[0]}" ;;
  0) return 1 ;;
  *)
    printf 'Multiple *.%s profiles found:\n' "$PROFILE_NAME" >&2
    printf '  %s\n' "${profiles[@]}" >&2
    die "Remove the one you don't want in about:profiles, then re-run."
    ;;
  esac
}

# Firefox holds the profile's .parentlock open for as long as it has that
# profile loaded. The file itself persists after exit, so only the open handle
# is evidence. Scoped to this profile, so an unrelated Firefox running another
# profile (e.g. a VPN one) doesn't block us.
require_profile_closed() {
  if [ -e "$PROFILE/.parentlock" ] && lsof -- "$PROFILE/.parentlock" >/dev/null 2>&1; then
    die "Firefox has the '$PROFILE_NAME' profile open — quit it first (Firefox rewrites prefs.js on exit)."
  fi
}

# curl -f rejects HTTP error statuses, but a captive portal or a CDN hiccup can
# still hand back 200 with an HTML page or a truncated body.
is_arkenfox_script() { bash -n "$1" 2>/dev/null && grep -q arkenfox "$1"; }
is_zip() { [ "$(head -c 2 "$1")" = PK ]; }

# Download to a temp file beside the destination and rename into place, so an
# interrupted transfer can never leave a truncated file where something will
# later run it. Rename within one directory is atomic.
fetch() {
  local url=$1 dest=$2 validate=${3:-} tmp
  tmp=$(mktemp "$dest.XXXXXX") || die "Could not create a temp file next to $dest"
  if ! curl -fsSL --retry 3 --connect-timeout 15 --max-time 300 -o "$tmp" "$url"; then
    rm -f "$tmp"
    die "Download failed: $url"
  fi
  if [ "$validate" != "" ] && ! "$validate" "$tmp"; then
    rm -f "$tmp"
    die "Download failed its $validate check (truncated, or not the file we asked for): $url"
  fi
  mv "$tmp" "$dest"
}

# The arkenfox updater writes a fresh ~80K backup on every run, including runs
# that change nothing.
prune_backups() {
  local dir=$1 files=() i
  [ -d "$dir" ] || return 0
  shopt -s nullglob
  # Backups are named <file>.backup.YYYY-MM-DD_HHMM, so the glob's
  # lexicographic order is chronological: keep the tail, drop the rest.
  files=("$dir"/*)
  for ((i = 0; i < ${#files[@]} - BACKUPS_KEPT; i++)); do
    rm -f "${files[i]}"
  done
}

# Fetch the arkenfox scripts and this repo's overrides into the profile, run the
# updater, then prove it actually worked: the updater has no `set -e` and exits
# 0 even when its own user.js download fails, so a caller's set -e cannot catch
# a failed update. A successful run always rewrites user.js and ends it with
# user-overrides.js.
install_arkenfox() {
  local f before after
  for f in updater.sh prefsCleaner.sh; do
    fetch "$ARKENFOX_RAW/$f" "$PROFILE/$f" is_arkenfox_script
    chmod +x "$PROFILE/$f"
  done
  cp "$REPO_DIR/user-overrides.js" "$PROFILE/user-overrides.js"

  before=$(stat -f %Fm "$PROFILE/user.js" 2>/dev/null || echo none)
  # -s: update without confirmation. -d: skip the updater's self-update check,
  # since we just fetched it. Appends user-overrides.js to user.js on its own.
  bash "$PROFILE/updater.sh" -p "$PROFILE" -s -d
  after=$(stat -f %Fm "$PROFILE/user.js" 2>/dev/null || echo none)

  [ "$after" != none ] && [ "$after" != "$before" ] ||
    die "arkenfox updater wrote no new user.js — its download failed. Profile left as it was; re-run when the network is healthy."
  tail -c "$(wc -c <"$REPO_DIR/user-overrides.js")" "$PROFILE/user.js" |
    cmp -s - "$REPO_DIR/user-overrides.js" ||
    die "user.js was written but does not end with user-overrides.js — check the updater output above."

  prune_backups "$PROFILE/userjs_backups"
}
