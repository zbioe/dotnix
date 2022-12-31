{ pkgs, config, lib, options, ... }:
with lib;
with lib.my;
let cfg = config.modules.wm.lightdm;
in {
  options.modules.wm.lightdm = with types; { enable = mkBoolOpt false; };
  config =
    mkIf cfg.enable { services.xserver.displayManager.lightdm.enable = true; };
}
