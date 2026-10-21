# Fonts switched live by `theme font` (font.sh): the role families and sizes
# live in ~/.local/state/theme/font/state, and every app reads a file written
# from them (or gets them over dconf, qtct, its extension...)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  catalog = import ./catalog.nix { inherit pkgs; };
  dir = "${config.xdg.stateHome}/theme/font";
  lines = lib.concatStringsSep "\n";
in
{
  options.dotnix.theme.fonts.script = lib.mkOption {
    type = lib.types.lines;
    readOnly = true;
    description = "Shell code of `theme font`, included in `theme`.";
    default = ''
      FONT_DEFAULTS=${lib.escapeShellArg (lines (lib.mapAttrsToList (k: v: "${k}=${v}") catalog.default))}
      FONT_CATALOG=${
        lib.escapeShellArg (
          lines (lib.concatLists (lib.mapAttrsToList (role: map (f: "${role}\t${f.name}")) catalog.roles))
        )
      }
      FONT_PRESETS=${
        lib.escapeShellArg (
          lines (
            lib.concatLists (
              lib.mapAttrsToList (preset: lib.mapAttrsToList (k: v: "${preset}\t${k}=${v}")) catalog.presets
            )
          )
        )
      }
      ${builtins.readFile ./font.sh}
    '';
  };

  config = lib.mkIf config.dotnix.theme.enable {
    # sans-serif, serif, monospace and emoji for every app that asks fontconfig
    xdg.configFile."fontconfig/conf.d/60-theme-fonts.conf".text = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <fontconfig>
        <include ignore_missing="yes">${dir}/fontconfig.conf</include>
      </fontconfig>
    '';
    programs.foot.settings.main.include = [ "${dir}/foot.ini" ];
    programs.kitty.extraConfig = "include ${dir}/kitty.conf";
    programs.ghostty.settings.config-file = [ "?${dir}/ghostty" ];
    programs.alacritty.settings.general.import = [ "${dir}/alacritty.toml" ];
  };
}
