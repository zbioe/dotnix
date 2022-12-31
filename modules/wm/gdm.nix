{ pkgs, config, lib, options, ... }:
with lib;
with lib.my;
let cfg = config.modules.wm.gdm;
in {
  options.modules.wm.gdm = with types; { enable = mkBoolOpt false; };
  config =
    mkIf cfg.enable { services.xserver.displayManager.gdm.enable = true; };
}
