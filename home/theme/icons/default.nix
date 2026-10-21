# Icons switched live by `theme icons` (icons.sh): the bar's pack, any tag's
# or glyph's own icon and the app icon theme live in ~/.local/state/theme/icons
{
  config,
  lib,
  pkgs,
  noctalia,
  ...
}:
let
  catalog = import ./catalog.nix { inherit pkgs noctalia; };
in
{
  options.dotnix.theme.icons = {
    index = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = catalog.index;
      description = "Every pack's icons by name, read from the fonts.";
    };
    apps = lib.mkOption {
      type = lib.types.listOf lib.types.attrs;
      readOnly = true;
      description = "App icon themes for the panel: name and title.";
      default = lib.mapAttrsToList (name: a: {
        inherit name;
        inherit (a) title;
      }) catalog.apps;
    };
    appPreviews = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = catalog.appPreviews;
      description = "A few icons of every app theme (previews.json: { name: [paths] }).";
    };
    script = lib.mkOption {
      type = lib.types.lines;
      readOnly = true;
      description = "Shell code of `theme icons`, included in `theme`.";
      default = ''
        ICON_INDEX=${catalog.index}
        ICON_DEFAULT=${catalog.default}
        ICON_APPS_DEFAULT=${catalog.appsDefault}
        ICON_APPS=${
          lib.escapeShellArg (
            lib.concatStringsSep "\n" (
              lib.mapAttrsToList (name: a: "${name}\t${a.title}\t${a.dark}\t${a.light}") catalog.apps
            )
          )
        }
        ${builtins.readFile ./icons.sh}
      '';
    };
  };

  config.home.packages = lib.mkIf config.dotnix.theme.enable [ catalog.appThemes ];
}
