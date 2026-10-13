// Applies the active `theme` (dotnix home/theme) to the browser UI and to
// Dark Reader. The nix_theme native host sends the theme on startup and
// again every time it changes.
const DARK_READER = "addon@darkreader.org";

let last = null;
let darkreader = null;
let retries = 0;

function toDarkReader() {
  if (!last) return;
  try {
    if (!darkreader) {
      darkreader = browser.runtime.connect(DARK_READER);
      darkreader.onDisconnect.addListener(() => {
        darkreader = null;
        // Dark Reader may still be starting up: try again a few times
        if (retries++ < 5) setTimeout(toDarkReader, 2000);
      });
    }
    // the theme is the point: switched off as a whole it would apply nowhere
    // (sites can still be turned off one by one in Dark Reader)
    darkreader.postMessage({ type: "changeSettings", data: { enabled: true } });
    darkreader.postMessage({ type: "setTheme", data: last.darkreader });
  } catch (e) {
    darkreader = null;
    console.warn("nix-theme: Dark Reader unavailable", e);
  }
}

// pages start in the theme's colors before Dark Reader gets to them (it
// recolors the page's own stylesheets a little after the first paint); the
// "darkreader" class keeps Dark Reader from recoloring this style itself
let fallback = null;
async function pageFallback({ mode, darkSchemeBackgroundColor, darkSchemeTextColor,
                              lightSchemeBackgroundColor, lightSchemeTextColor }) {
  const bg = mode === 1 ? darkSchemeBackgroundColor : lightSchemeBackgroundColor;
  const fg = mode === 1 ? darkSchemeTextColor : lightSchemeTextColor;
  const code = `(() => {
    const style = document.createElement("style");
    style.className = "darkreader darkreader--nix-fallback";
    style.textContent = "html, body, body :not(iframe) { background-color: ${bg} !important; color: ${fg} !important; }";
    document.documentElement.append(style);
    const done = () => style.remove();
    const later = () => setTimeout(done, 800);
    if (document.readyState === "complete") later();
    else addEventListener("load", later, { once: true });
    setTimeout(done, 6000);
  })();`;
  if (fallback) await fallback.unregister();
  fallback = await browser.contentScripts.register({
    js: [{ code }],
    // page scrollbars in the palette, thin (Firefox has no ::-webkit-scrollbar
    // to shape them as Chromium does; Dark Reader's own are left off)
    css: [{ code: `html { scrollbar-color: color-mix(in oklab, ${fg}, ${bg} 62%) transparent !important; scrollbar-width: thin !important; }` }],
    matches: ["<all_urls>"],
    runAt: "document_start",
    allFrames: true,
  });
}

function apply(theme) {
  last = theme;
  retries = 0;
  browser.theme.update(theme.browser);
  toDarkReader();
  pageFallback(theme.darkreader).catch((e) => console.warn("nix-theme: fallback", e));
}

function connect() {
  const host = browser.runtime.connectNative("nix_theme");
  host.onMessage.addListener(apply);
  host.onDisconnect.addListener(() => setTimeout(connect, 5000));
}

connect();
