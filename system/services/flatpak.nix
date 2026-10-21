{
  config,
  lib,
  unstable,
  ...
}:
{
  options.dotnix.services.flatpak.enable = lib.mkEnableOption "Flatpak";

  config = lib.mkIf config.dotnix.services.flatpak.enable {
    services.flatpak = {
      enable = true;
      package = unstable.flatpak;
    };
    fileSystems."/var/lib/flatpak" = {
      device = "/var/lib/nodatacow/flatpak";
      fsType = "none";
      options = [ "bind" ];
    };
  };
}
