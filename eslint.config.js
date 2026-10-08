import baseConfig from "./cfg/eslint.config.base.js";

const config = Object.freeze([
  ...baseConfig,
  {
    // Firefox prefs syntax, appended to arkenfox's user.js: Firefox's pref
    // parser supplies user_pref. Still linted, because a syntax error here
    // makes Firefox silently skip every override after it.
    files: ["user-overrides.js"],
    languageOptions: { globals: { user_pref: "readonly" } },
    name: "firefox-privacy/prefs",
  },
]);

export default config;
