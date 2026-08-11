// user-overrides.js
// Appended to arkenfox user.js by updater.sh. This repo copy is the source
// of truth; setup/update scripts copy it into the profile before updating.

// arkenfox clears cookies/site data on shutdown by default; keep sessions
user_pref("privacy.sanitize.sanitizeOnShutdown", false);

// arkenfox enables RFP. It's the gold standard, but on a daily driver the
// UTC-timezone reporting, forced light mode, and letterboxing get old.
// Trading down to FPP (Firefox's per-feature successor) is a defensible
// compromise for a logged-in profile:
user_pref("privacy.resistFingerprinting", false);
user_pref("privacy.fingerprintingProtection", true);
