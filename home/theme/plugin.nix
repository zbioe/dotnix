# the theme panels (picker and fonts) and the control center tile
{
  config,
  lib,
  pkgs,
  base16,
  ...
}:
let
  swatchesOf =
    scheme:
    let
      c = ((base16.lib { inherit pkgs lib; }).mkSchemeAttrs scheme).withHashtag;
    in
    [
      c.base00
      c.base05
      c.base08
      c.base0A
      c.base0B
      c.base0D
      c.base0E
    ];
  themesJson = (pkgs.formats.json { }).generate "themes.json" {
    theme = lib.getExe config.dotnix.theme.package;
    state = "${config.xdg.stateHome}/theme";
    themes = lib.mapAttrsToList (
      name: theme: { inherit name; } // lib.mapAttrs (_: swatchesOf) theme.schemes
    ) config.dotnix.theme.themes;
  };
  catalog = import ./fonts/catalog.nix { inherit pkgs; };
  fontsJson = (pkgs.formats.json { }).generate "fonts.json" {
    theme = lib.getExe config.dotnix.theme.package;
    state = "${config.xdg.stateHome}/theme";
    roles = lib.mapAttrs (_: map (f: f.name)) catalog.roles;
    inherit (catalog) default;
    presets = lib.mapAttrsToList (name: p: p // { inherit name; }) catalog.presets;
    inherit emojiPreviews;
    iconIndex = config.dotnix.theme.icons.index;
    apps = config.dotnix.theme.icons.apps;
    appsDefault = "papirus";
    appPreviews = "${config.dotnix.theme.icons.appPreviews}/previews.json";
  };
  # emoji go through the generic "emoji" family, whatever a label asks: each
  # emoji font's preview drawn here, alone (pango, as the panel would)
  emojiPreviews =
    let
      sample = pkgs.writeText "emoji-sample" "😀🫠🪿👍🏽❤️✨🇧🇷";
    in
    pkgs.runCommand "emoji-previews" { } ''
      mkdir $out
      ${lib.concatMapStrings (f: ''
        printf '<fontconfig><dir>%s</dir><cachedir>%s</cachedir></fontconfig>' \
          ${f.package}/share/fonts "$TMPDIR/cache" > fonts.conf
        FONTCONFIG_FILE=$PWD/fonts.conf ${pkgs.pango.bin}/bin/pango-view --no-display \
          --background=transparent --foreground='#9aa0a6' --font=${lib.escapeShellArg "${f.name} 40"} \
          -o raw.png ${sample}
        # same height, left-aligned on one canvas: every preview lines up
        ${lib.getExe pkgs.imagemagick} raw.png -trim +repage -resize x96 -background none \
          -gravity west -extent 960x96 $out/${lib.replaceStrings [ " " ] [ "-" ] f.name}.png
      '') catalog.roles.emoji}
    '';
in
{
  dotnix.desktop.noctalia.plugins.theme = lib.mkIf config.dotnix.theme.enable {
    src = ./plugin;
    manifest = {
      name = "Themes";
      icon = "palette";
      description = "Theme picker for the dotnix `theme` command.";
      panel = [
        {
          id = "picker";
          entry = "picker.luau";
          width = 420;
          height = 640;
          placement = "attached";
          position = "auto";
        }
        {
          id = "fonts";
          entry = "fonts.luau";
          width = 540;
          height = 720;
          placement = "attached";
          position = "auto";
        }
      ];
      shortcut = [
        {
          id = "theme";
          entry = "shortcut.luau";
        }
      ];
    };
    files = {
      "themes.json" = themesJson;
      "fonts.json" = fontsJson;
    };
  };
}
