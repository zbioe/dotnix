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
  };
}
