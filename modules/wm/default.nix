{ pkgs, config, lib, options, ... }:
with lib;
with lib.my;
let cfg = config.modules.wm;
in {
  imports = [ ./herbstluft.nix ./gdm.nix ./leftwm.nix ./lightdm.nix ];
  options.modules.wm = with types; {
    enable = mkBoolOpt true;
    # wayland = mkOpt' bool false "use wayland";
  };
  config = mkIf cfg.enable {
    hardware.opengl.driSupport32Bit = true;
    hardware.opengl.driSupport = true;
    hardware.opengl = { enable = true; };
    hardware.opengl.extraPackages = with pkgs; [ intel-compute-runtime ];

    services.xserver.enable = true;
    services.dbus.enable = true;

    xdg.portal.enable = true;
    xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    services.xserver.libinput.enable = true;
    environment.systemPackages = with pkgs; [
      # search bar
      rofi
      # window information
      xdotool
      # notify
      dunst
      # wifi tools
      wirelesstools
    ];

  };
}
