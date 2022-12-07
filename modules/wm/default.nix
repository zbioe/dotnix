{ pkgs, config, lib, options, ... }:
with lib;
with lib.my;
let cfg = config.modules.wm;
in {
  imports = [ ./herbstluft.nix ./gdm.nix ];
  options.modules.wm = with types; { enable = mkBoolOpt true; };
  config = mkIf cfg.enable {
    services.xserver.enable = true;
    services.dbus.enable = true;

    xdg.portal.enable = true;
    xdg.portal.extraPortals =
      [ pkgs.xdg-desktop-portal-gtk ];

    hardware.opengl.driSupport32Bit = true;
    hardware.opengl = { enable = true; };
    services.xserver.libinput.enable = true;
  };
}
