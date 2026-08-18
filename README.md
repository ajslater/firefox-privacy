# firefox-privacy

Portable setup for a privacy-hardened Firefox profile on macOS:
[arkenfox user.js](https://github.com/arkenfox/user.js) + personal
`user-overrides.js` + uBlock Origin, in a dedicated profile named `hardened`.

## Files

| File                         | Purpose                                                                                             |
| ---------------------------- | --------------------------------------------------------------------------------------------------- |
| `setup-firefox-hardened.sh`  | One-shot provisioning: creates the profile, installs arkenfox + overrides + uBlock Origin           |
| `update-firefox-hardened.sh` | Regular maintenance: re-syncs overrides, updates arkenfox user.js                                   |
| `user-overrides.js`          | Canonical copy of the overrides, appended to user.js by the arkenfox updater                        |
| `check-arkenfox-update.sh`   | Optional: daily launchd check that fires a macOS notification when arkenfox publishes a new user.js |
| `lib.sh`                     | Shared helpers for the two scripts above (profile discovery, verified downloads, arkenfox install)  |

## New machine runbook

1. Install Firefox:

    ```bash
    brew install --cask firefox
    ```

    Launch it once so macOS registers the app, then quit it.

2. Get this repo onto the machine (git clone or copy the directory).

3. Run the setup script:

    ```bash
    ./setup-firefox-hardened.sh
    ```

4. Launch the hardened profile:

    ```bash
    /Applications/Firefox.app/Contents/MacOS/firefox -P hardened
    ```

5. First-launch checks:
    - `about:addons` — uBlock Origin is installed and enabled. If the sideload
      didn't take (Mozilla occasionally tightens this), install it manually from
      [addons.mozilla.org](https://addons.mozilla.org/firefox/addon/ublock-origin/)
      — one click, done.
    - `about:config` — spot-check `privacy.fingerprintingProtection` is `true`
      and `privacy.resistFingerprinting` is `false` (confirms user.js +
      overrides loaded).
    - `about:profiles` — click **Set as default profile** on `hardened` so plain
      launches (Dock, default-browser links) use it.

## Maintenance

Run every few weeks, or after Firefox major updates (quit Firefox first):

```bash
./update-firefox-hardened.sh
```

This copies the repo's `user-overrides.js` into the profile, downloads the
latest arkenfox `updater.sh`/`prefsCleaner.sh`, and runs the updater, which
fetches the current `user.js` and re-appends the overrides. Afterwards it
verifies the update actually happened — arkenfox's updater exits 0 even when its
download fails — and prunes `userjs_backups/` to the 5 newest.

Only the `hardened` profile needs to be closed; another Firefox running a
different profile (say the VPN one) doesn't block an update.

A couple of times a year, also purge stale prefs left behind in `prefs.js` by
removed or renamed arkenfox entries:

```bash
./update-firefox-hardened.sh --clean
```

### Update notifications

arkenfox releases irregularly (roughly 2–4 times a year). To get a macOS
notification when a new version lands, install the daily check once per machine:

```bash
./check-arkenfox-update.sh --install
```

It compares the profile's `user.js` version header against arkenfox master at
noon daily (or at wake), notifies once per new version, and stays silent
offline. The first notification may need a one-time allow for **Script Editor**
under System Settings → Notifications. Remove with `--uninstall`; logs in
`~/Library/Logs/arkenfox-update-check.log`. Passive alternative: subscribe to
<https://github.com/arkenfox/user.js/releases.atom> in an RSS reader, or GitHub
Watch → Custom → Releases.

## Changing settings

- Edit `user-overrides.js` **in this repo**, commit, then run the update script
  on each machine (git pull first). Don't edit the copy in the profile — it gets
  overwritten.
- To relax an arkenfox pref, add a `user_pref(...)` line here rather than
  flipping it in `about:config`; changes made in about:config to prefs that
  user.js sets are reset on every Firefox start.
- The arkenfox wiki's
  [common overrides page](https://github.com/arkenfox/user.js/wiki/3.2-Overrides-%5BCommon%5D)
  is the reference when a site breaks.

## Current overrides, and why

- `privacy.sanitize.sanitizeOnShutdown = false` — arkenfox wipes cookies and
  site data on every exit; we keep logins/sessions.
- `privacy.resistFingerprinting = false` +
  `privacy.fingerprintingProtection = true` — trade RFP (UTC timezone, forced
  light mode, letterboxing) for FPP, Firefox's per-feature fingerprinting
  protection. A defensible compromise for a logged-in daily-driver profile.

## Troubleshooting

- **"Firefox has the 'hardened' profile open"**: quit that window. Firefox
  rewrites `prefs.js` on exit, which can clobber a concurrent update.
- **"Quit Firefox before running setup"**: setup needs _every_ Firefox closed,
  because `-CreateProfile` otherwise hands off to the running instance.
- **"arkenfox updater wrote no new user.js"**: the download failed (offline,
  captive portal, GitHub hiccup). The profile is untouched — re-run later.
- **"Multiple \*.hardened profiles found"**: a stale duplicate exists in
  `~/Library/Application Support/Firefox/Profiles/`. Open `about:profiles`,
  remove the one you don't want, re-run.
- **Setup says it created no profile**: the name is still registered in
  `about:profiles` from a deleted directory. Remove that entry there and re-run
  — Firefox silently refuses to reuse a registered profile name.
- **Site broken?** Try uBlock's toolbar button first (disable on that site),
  then check the arkenfox overrides wiki linked above. Worst case, use the
  default (non-hardened) profile for that one site.
- **Start over**: `about:profiles` → remove the `hardened` profile (with "Delete
  Files"), then re-run `setup-firefox-hardened.sh`.
