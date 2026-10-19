# Browser side of `theme` (home/theme): an extension that recolors the
# browser UI and drives Dark Reader (pkgs/darkreader), plus the native host
# that feeds it the active theme. Firefox gets the xpi; Chromium browsers an
# unpacked MV3 copy (chromium/, fixed id from its `key`) and the host manifest
# under etc/chromium.
{
  lib,
  runCommandLocal,
  writers,
  writeText,
  inotify-tools,
  jq,
  zip,
  # themes as in home/theme/themes.nix and a base16 scheme loader (stylix's
  # mkSchemeAttrs): every theme/mode gets a page fallback and the page
  # scrollbars for Chromium
  themeSet ? { },
  mkSchemeAttrs ? null,
}:
let
  # chromium/fallback/<theme>-<mode>.js: paints the page in the theme until
  # Dark Reader's own style is in, so pages never flash white while loading
  fallbacks = lib.concatLists (
    lib.mapAttrsToList (
      name: theme:
      lib.mapAttrsToList (
        mode: scheme:
        let
          c = (mkSchemeAttrs scheme).withHashtag;
        in
        {
          name = "${name}-${mode}.js";
          text = builtins.replaceStrings [ "@bg@" "@fg@" ] [ c.base00 c.base05 ] (
            builtins.readFile ./chromium/fallback.js
          );
        }
      ) theme.schemes
    ) themeSet
  );
  # "#rrggbb" of `from` mixed `ratio` (0..1) of the way towards `to` (sRGB)
  mix =
    from: to: ratio:
    let
      channel =
        i:
        let
          get = hex: lib.fromHexString (builtins.substring (1 + i) 2 hex);
          n = builtins.floor (get from + (get to - get from) * ratio + 0.5);
        in
        lib.fixedWidthString 2 "0" (lib.toLower (lib.toHexString n));
    in
    "#${channel 0}${channel 2}${channel 4}";
  # chromium/scrollbar/<theme>-<mode>.css: the page scrollbars in the palette
  scrollbars = lib.concatLists (
    lib.mapAttrsToList (
      name: theme:
      lib.mapAttrsToList (
        mode: scheme:
        let
          c = (mkSchemeAttrs scheme).withHashtag;
        in
        {
          name = "${name}-${mode}.css";
          # mixed here: color-mix() is not honoured on ::-webkit-scrollbar-*
          text =
            builtins.replaceStrings
              [ "@thumb@" "@hover@" "@accent@" ]
              [
                (mix c.base05 c.base00 0.62)
                (mix c.base05 c.base00 0.38)
                c.base0D
              ]
              (builtins.readFile ./chromium/scrollbar.css);
        }
      ) theme.schemes
    ) themeSet
  );
  # E501: the interpolated store path is long
  host = writers.writePython3 "nix-theme-host" { flakeIgnore = [ "E501" ]; } (
    lib.replaceStrings [ "@inotifywait@" ] [ "${inotify-tools}/bin/inotifywait" ] (
      builtins.readFile ./host.py
    )
  );
  chromiumId = "fafnnenadbigcbhmihefjbaiggflgefj";
  chromiumManifest = writeText "nix_theme.json" (
    builtins.toJSON {
      name = "nix_theme";
      description = "Active dotnix theme";
      path = "${host}";
      type = "stdio";
      allowed_origins = [ "chrome-extension://${chromiumId}/" ];
    }
  );
  manifest = writeText "nix_theme.json" (
    builtins.toJSON {
      name = "nix_theme";
      description = "Active dotnix theme";
      path = "${host}";
      type = "stdio";
      allowed_extensions = [ "nix-theme@dotnix" ];
    }
  );
in
runCommandLocal "nix-theme"
  {
    nativeBuildInputs = [ zip ];
    passthru = {
      addonId = "nix-theme@dotnix";
      inherit chromiumId;
    };
  }
  ''
    mkdir -p $out/lib/mozilla/native-messaging-hosts
    cp ${manifest} $out/lib/mozilla/native-messaging-hosts/nix_theme.json
    cp ${./manifest.json} manifest.json
    cp ${./background.js} background.js
    zip -q $out/nix-theme.xpi manifest.json background.js
    cp -r ${./chromium} $out/chromium
    chmod -R u+w $out/chromium
    rm $out/chromium/fallback.js $out/chromium/scrollbar.css
    # Chromium keeps running a cached copy of an extension's service worker
    # until both its address and the extension version change: both follow
    # the build's hash
    hash=$(cat $out/chromium/*.js $out/chromium/fallback/*.js | sha256sum | cut -c1-12)
    sw=background-$hash.js
    mv $out/chromium/background.js $out/chromium/$sw
    ${lib.getExe jq} --arg sw "$sw" --arg v "1.0.$((16#''${hash:4:4}))" \
      '.version = $v | .background.service_worker = $sw' \
      $out/chromium/manifest.json > manifest.chromium.json
    mv manifest.chromium.json $out/chromium/manifest.json
    mkdir $out/chromium/fallback
    ${lib.concatMapStrings (f: ''
      cp ${writeText f.name f.text} $out/chromium/fallback/${f.name}
    '') fallbacks}
    mkdir $out/chromium/scrollbar
    ${lib.concatMapStrings (f: ''
      cp ${writeText f.name f.text} $out/chromium/scrollbar/${f.name}
    '') scrollbars}
    mkdir -p $out/etc/chromium/native-messaging-hosts
    cp ${chromiumManifest} $out/etc/chromium/native-messaging-hosts/nix_theme.json
  ''
