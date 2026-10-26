# Brave in the palette (home/theme), without GTK mode: GTK mode paints the
# focused address bar's rounded corners white (Brave rounds its dropdown less
# than the frame around it), a theme extension paints them with its
# omnibox_background. Each palette is a theme extension, and a seed color
# tints what a theme cannot reach (menus, dialogs, bubbles).
#
# The two fight: installing a theme clears the seed, setting a seed drops
# the theme. They live together when neither is installed while Brave runs:
#  - the theme extension is installed once per profile as a persistent
#    unpacked extension at a fixed path (install.py), not with
#    --load-extension, which reinstalls it on every start;
#  - Brave reads the theme from the theme pack in that folder ("Cached
#    Theme.pak", built here per palette by a headless Brave), and the seed
#    from Preferences, written by `prelaunch` before Brave starts.
# Switching live: `theme` copies the new pack into the folder and Brave
# rereads it when its BrowserThemeColor policy is unset (the reload service
# in system/desktop/browsers/brave.nix sets it for a moment). The seed changes on the
# next start; the color scheme (dark/light) follows the portal live.
{
  lib,
  runCommand,
  writeShellScript,
  python3,
  jq,
  brave,
  inotify-tools,
}:
let
  # fixed extension id: pffajedgapdnpkofjjgjdhaipfdigfnd
  key = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4pdjk1bSt5kBpAB+ddtBQ5aCn4aSwF4l7VqKx15bUmdMQG32HKcds7qwuGk5+2ZKxWp3DT1SezdDfv9lEU6QRpXtHTxnr5xL6iOmN4qAJl9f/PE24MATTNr++9ZZ4/C9uiLM/XCW7VVQ+Y/o8UCnvPwxWJTbI3lT5QxvJqm6RU1MBgypaSb72sMMvlvFM0q3tSp0vbPdqrE7zRSWe7Amdi8gxVBawL4eYTi47AMAZj3kiC4u2fM8uGFQsI6qI3L5x5SPWpBM+/qWzYJOXDD/EQLcZn/TiQsQOkD0mpNv5SY4nmQopVoLfvYSmsSj5EfCctpC2JZkGRdVrvLznm0+1QIDAQAB";
  id = "pffajedgapdnpkofjjgjdhaipfdigfnd";

  rgb =
    hex:
    let
      n = lib.fromHexString (lib.removePrefix "#" hex);
    in
    [
      (n / 65536)
      (lib.mod (n / 256) 256)
      (lib.mod n 256)
    ];
in
{
  inherit id;

  # the theme extension of one palette (colors: theme color name -> #rrggbb)
  # and its theme pack, as the installed Brave builds it
  theme =
    name: colors:
    runCommand "brave-theme-${name}"
      {
        nativeBuildInputs = [
          brave
          inotify-tools
        ];
        manifest = builtins.toJSON {
          manifest_version = 3;
          name = "nix theme";
          version = "1.0";
          inherit key;
          theme.colors = lib.mapAttrs (_: rgb) colors;
        };
        passAsFile = [ "manifest" ];
      }
      ''
        mkdir -p $out home
        cp $manifestPath $out/manifest.json
        name=""
        export HOME=$PWD/home
        # the pack once written whole, watched before Brave starts
        exec {events}< <(exec inotifywait -m -e close_write,moved_to --format %f $out 2>&1)
        watch=$!
        until [ "$name" = "Watches established." ]; do read -r name <&"$events"; done
        brave --headless=new --no-sandbox --disable-gpu --user-data-dir=$PWD/profile \
          --no-first-run --load-extension=$out \
          --disable-features=DisableLoadExtensionCommandLineSwitch about:blank >/dev/null 2>&1 &
        while read -r -t 60 name <&"$events" && [ "$name" != "Cached Theme.pak" ]; do :; done
        kill $! $watch || true
        wait || true
        [ -s "$out/Cached Theme.pak" ] || { echo "brave-theme: no theme pack" >&2; exit 1; }
        # the address bar dropdown's window (omnibox_background, color 10)
        # shows only at its corners, where Brave rounds it less than the page
        # it holds: transparent, so the page's outline is its outer edge
        ${python3}/bin/python3 -I ${./clear-color.py} "$out/Cached Theme.pak" 10
      '';

  # the profile settings of a palette (base16, #rrggbb): the seed (opaque
  # ARGB as a signed int) and its Material variant, and the color scheme
  # from the portal. Menus take tone 10/99 of the seed's hue: the background
  # when it has one (tonal spot: chroma 6), else the text or accent color at
  # chroma 2 (neutral), a grey only leaning to the palette.
  prefs =
    c:
    let
      colorful = hex: lib.foldl' lib.max 0 (rgb hex) - lib.foldl' lib.min 255 (rgb hex) >= 8;
      seed = lib.findFirst colorful c.base0D [
        c.base00
        c.base05
      ];
    in
    {
      user_color2 = lib.fromHexString (lib.removePrefix "#" seed) - 16777216;
      color_variant2 = if seed == c.base00 then 1 else 2; # tonal spot, neutral
      color_scheme2 = 0;
      follows_system_colors = false;
    };

  # run by Brave's launcher (webui-theme) before it starts: unless Brave
  # already runs, install the theme extension where missing and write the
  # seed of the current palette. $1: the launcher itself.
  prelaunch = writeShellScript "brave-theme-prelaunch" ''
    [ -z "''${NIX_BRAVE_THEME:-}" ] || exit 0
    export NIX_BRAVE_THEME=1 # the installer's own Brave skips this
    state=''${XDG_STATE_HOME:-$HOME/.local/state}/theme
    ext=$state/brave-theme
    prefs=$state/current/brave.json
    [ -f "$ext/manifest.json" ] && [ -f "$prefs" ] || exit 0
    root=''${XDG_CONFIG_HOME:-$HOME/.config}/BraveSoftware/Brave-Browser
    # already running: this launch only opens a window there
    if lock=$(readlink "$root/SingletonLock" 2>/dev/null) && kill -0 "''${lock##*-}" 2>/dev/null; then
      exit 0
    fi
    mkdir -p "$root/Default"
    for dir in "$root"/Default "$root"/Profile\ *; do
      [ -d "$dir" ] || continue
      if [ "$(${jq}/bin/jq -r '.extensions.theme.id // ""' "$dir/Preferences" 2>/dev/null)" != ${id} ]; then
        ${python3}/bin/python3 -I ${./install.py} "$1" "$root" "''${dir##*/}" "$ext" ${id} || continue
      fi
      # rounded page corners: the page's outline divides it from the toolbar,
      # instead of a line the address bar's dropdown would cover
      ${jq}/bin/jq --slurpfile p "$prefs" '.browser.theme += $p[0] | .brave.web_view_rounded_corners = true' \
        "$dir/Preferences" > "$dir/Preferences.nix-theme" &&
        mv "$dir/Preferences.nix-theme" "$dir/Preferences"
    done
  '';
}
