// Chromium side of nix-theme (see ../background.js): no theme API for the
// browser UI here (it follows GTK), so only Dark Reader is driven. The open
// native port keeps this service worker alive.
const DARK_READER = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; // pkgs/darkreader (Web Store id)

let last = null;
let darkreader = null;
let backoff = 1000;

function post() {
  if (!last || !darkreader) return;
  // the theme is the point: switched off as a whole it would apply nowhere
  // (sites can still be turned off one by one in Dark Reader)
  darkreader.postMessage({ type: "changeSettings", data: { enabled: true } });
  darkreader.postMessage({ type: "setTheme", data: last.darkreader });
}

// Dark Reader's service worker takes the port before it is ready to apply a
// theme, and is restarted by the browser now and then: send again shortly
// after every (re)connection, and reconnect whenever it goes away
function toDarkReader() {
  if (!last) return;
  if (!darkreader) {
    try {
      darkreader = chrome.runtime.connect(DARK_READER);
    } catch (e) {
      console.warn("nix-theme: Dark Reader unavailable", e);
      return;
    }
    darkreader.onDisconnect.addListener(() => {
      darkreader = null;
      setTimeout(toDarkReader, backoff);
      backoff = Math.min(backoff * 2, 60000);
    });
    for (const ms of [1500, 5000]) setTimeout(post, ms);
  }
  post();
}

// pages start in the theme's colors, before Dark Reader gets to them, and
// get their scrollbars in the palette (Dark Reader's own are left off)
async function fallback(id) {
  await chrome.scripting.unregisterContentScripts({ ids: ["fallback", "scrollbar"] }).catch(() => {});
  await chrome.scripting.registerContentScripts([
    {
      id: "fallback",
      js: [`fallback/${id}.js`],
      matches: ["<all_urls>"],
      runAt: "document_start",
      allFrames: true,
    },
    {
      id: "scrollbar",
      css: [`scrollbar/${id}.css`],
      matches: ["<all_urls>"],
      runAt: "document_start",
      allFrames: true,
    },
  ]);
}

// the page fonts of `theme font`: pages that name no font, or a generic one
function fonts({ ui, serif, mono, size, fixedSize }) {
  const set = (genericFamily, fontId) =>
    chrome.fontSettings.setFont({ genericFamily, script: "Zyyy", fontId });
  set("standard", serif);
  set("serif", serif);
  set("sansserif", ui);
  set("fixed", mono);
  chrome.fontSettings.setDefaultFontSize({ pixelSize: size });
  chrome.fontSettings.setDefaultFixedFontSize({ pixelSize: fixedSize });
}

function connect() {
  const host = chrome.runtime.connectNative("nix_theme");
  host.onMessage.addListener((theme) => {
    if (theme.font) {
      fonts(theme.font);
      return;
    }
    last = theme;
    backoff = 1000;
    toDarkReader();
    if (theme.id) fallback(theme.id).catch((e) => console.warn("nix-theme: fallback", e));
  });
  host.onDisconnect.addListener(() => setTimeout(connect, 5000));
}

// a service worker only runs on events: these start it with the browser
// (the open native port then keeps it alive)
chrome.runtime.onStartup.addListener(() => {});
chrome.runtime.onInstalled.addListener(() => {});

connect();
