{ pkgs, config, lib, options, ... }:
with lib;
with lib.my;
let
  cfg = config.modules.wm.leftwm;
  leftwm = pkgs.callPackage ../../nixpkgs/leftwm.nix { };
in {
  options.modules.wm.leftwm = with types; { enable = mkBoolOpt false; };
  config = mkIf cfg.enable {
    environment.systemPackages = [
      leftwm
      # wallpaper
      pkgs.feh
      pkgs.picom
    ];
    services.xserver.windowManager.session = singleton {
      name = "leftwm";
      start = ''
        ${leftwm}/bin/leftwm &
        waitPID=$!
        ${leftwm}/bin/lefthk-worker &
      '';
    };
  };
}
