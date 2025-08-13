{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.stylix;
  inherit (lib) mkIf mkOption types;
in
{
  options.modules.stylix = with types; {
    enable = mkOption {
      type = bool;
      default = false;
      description = ''
        Enable color support by stylix.
      '';
    };
    theme = mkOption {
      type = str;
      default = "gruvbox-dark-medium";
      example = "solarized-light";
      description = ''
        The base16 theme to use.
        only support themes in pkgs.base16-schemes
      '';
    };
    image = mkOption {
      type = nullOr (coercedTo package toString path);
      default =
        let
          theme = "${pkgs.base16-schemes}/share/themes/${cfg.theme}.yaml";
          wallpaper = pkgs.runCommand "image.png" { } ''
            COLOR=$(${pkgs.yq}/bin/yq -r .palette.base00 ${theme})
            ${pkgs.imagemagick}/bin/magick -size 1920x1080 xc:#$COLOR $out
          '';
        in
        wallpaper;
      example = "./path/to/image";
      description = ''
        The image to use as background.
      '';
    };
    polarity = mkOption {
      type = str;
      default = "dark";
      example = "light";
      description = ''
        The polarity of the theme.
      '';
    };
  };
  config = mkIf cfg.enable {
    stylix = {
      enable = cfg.enable;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/${cfg.theme}.yaml";
      inherit (cfg) polarity image;
    };
  };
}
