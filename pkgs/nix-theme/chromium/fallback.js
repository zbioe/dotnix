// Page fallback (one copy per theme, colors filled in by pkgs/nix-theme):
// runs before the first paint and keeps the page in the theme's colors
// while it loads. Dark Reader puts its base style in right away but recolors
// the page's own stylesheets a little later, so this stays until the page
// has loaded (and a moment more), then steps aside.
(() => {
  const style = document.createElement("style");
  // Dark Reader leaves its own styles alone instead of recoloring them
  style.className = "darkreader darkreader--nix-fallback";
  // every element, not just the page: bars and footers paint their own
  // light backgrounds before Dark Reader gets to them
  style.textContent =
    "html, body, body :not(iframe) { background-color: @bg@ !important; color: @fg@ !important; }";
  document.documentElement.append(style);
  const done = () => style.remove();
  const later = () => setTimeout(done, 800);
  if (document.readyState === "complete") later();
  else addEventListener("load", later, { once: true });
  setTimeout(done, 6000);
})();
