# `vpn` (vpn.sh) and the bar's VPN widget and panel (./plugin)
{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.desktop.vpn;
  vpn = pkgs.writeShellApplication {
    name = "vpn";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      gnugrep
      jq
      networkmanager
      util-linux
    ];
    text = ''
      FAVORITES=(${lib.escapeShellArgs cfg.favorites})
      ${builtins.readFile ./vpn.sh}
    '';
  };
in
{
  options.dotnix.desktop.vpn = {
    enable = lib.mkEnableOption "`vpn` and the bar's VPN widget";
    favorites = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "fastest" ];
      example = [
        "fastest"
        "BR"
        "US#120"
        "securecore"
      ];
      description = "The first quick connections; the panel adds and removes more (`vpn fav`).";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ vpn ];

    dotnix.desktop.noctalia.plugins.vpn = {
      src = ./plugin;
      manifest = {
        name = "VPN";
        icon = "shield";
        description = "VPN state and connections of the dotnix `vpn` command.";
        widget = [
          {
            id = "vpn";
            entry = "widget.luau";
            actions.left = "panel-toggle dotnix/vpn:panel";
          }
        ];
        panel = [
          {
            id = "panel";
            entry = "panel.luau";
            width = 420;
            height = 520;
            placement = "attached";
            position = "auto";
          }
        ];
      };
      files."vpn.json" = (pkgs.formats.json { }).generate "vpn.json" {
        command = "${config.home.profileDirectory}/bin/vpn";
      };
    };
  };
}
