{
  config,
  lib,
  unstable,
  ...
}:

{
  fileSystems."/var/lib/flatpak" = {
    device = "/var/lib/nodatacow/flatpak";
    fsType = "none";
    options = [ "bind" ];
  };
  services.flatpak = {
    enable = true;
    package = unstable.flatpak;
  };
}
