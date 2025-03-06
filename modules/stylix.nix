{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.stylix;
  inherit (lib) mkOption types;
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
      default = "gruvbox-material-dark-medium";
      example = "solarized-light";
      description = ''
        The base16 theme to use.
        only support themes in pkgs.base16-schemes
      '';
    };
  };
  config = {
    stylix = {
      enable = cfg.enable;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/${cfg.theme}.yaml";
    };
  };
}
