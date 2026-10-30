{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.dotnix.services.kdeconnect.enable = lib.mkEnableOption "KDE Connect";

  config = lib.mkIf config.dotnix.services.kdeconnect.enable {
    programs.kdeconnect.enable = true;
    environment.systemPackages = [ pkgs.kdePackages.kdeconnect-kde ];

    # the phone's mouse and keyboard go through the RemoteDesktop portal, which
    # wlr lacks: luminous has it (wlroots virtual pointer and keyboard)
    xdg.portal = {
      extraPortals = [ pkgs.xdg-desktop-portal-luminous ];
      config.mango."org.freedesktop.impl.portal.RemoteDesktop" = [ "luminous" ];
    };
  };
}
