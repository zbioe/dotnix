# Upstream packages with our patches (home packages)
{ noctalia }:
_final: prev: {
  # OSC 50: `theme font` changes the font of open windows (tmux inside too)
  foot = prev.foot.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ./patches/foot-osc50-font.patch ];
  });

  noctalia-shell = noctalia.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/noctalia-workspace-label-map.patch
      ./patches/noctalia-tray-menu.patch
      ./patches/noctalia-ctrl-h-backspace.patch
      ./patches/noctalia-glyph-override.patch
    ];
  });
}
