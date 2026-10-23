/* Static pages work without JavaScript; enhancement selects the preferred language. */
(() => {
  "use strict";
  const url = new URL(window.location.href);
  const explicit = url.searchParams.get("lang");
  const valid = value => value === "zh" || value === "en";
  let saved;
  try { saved = window.localStorage.getItem("wx-site-language"); } catch (_) { /* Storage may be blocked. */ }
  let preferred = valid(explicit) ? explicit : saved;
  if (valid(explicit)) {
    try { window.localStorage.setItem("wx-site-language", explicit); } catch (_) { /* Links still work. */ }
  }
  if (!valid(preferred)) {
    // Respect preference order; use the first language for which we have a translation.
    const supported = (navigator.languages || [navigator.language || "en"])
      .map(language => language.toLowerCase().split(/[-_]/)[0])
      .find(valid);
    preferred = supported || "en";
  }
  const current = document.documentElement.lang === "en" ? "en" : "zh";
  if (preferred !== current) {
    const destination = new URL(preferred === "en" ? "en.html" : "index.html", url);
    destination.search = url.search;
    destination.hash = url.hash;
    window.location.replace(destination.href);
  }
})();
