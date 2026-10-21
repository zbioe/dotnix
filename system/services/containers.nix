{
  config,
  lib,
  pkgs,
  unstable,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.services.containers;
in
{
  options.dotnix.services.containers = {
    enable = lib.mkEnableOption "containers";
    docker.enable = dotlib.mkItem cfg "Docker";
    distrobox.enable = dotlib.mkItem cfg "Distrobox";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.docker.enable {
      virtualisation.docker = {
        enable = true;
        package = unstable.docker;
        daemon.settings = {
          # `-p 3000:3000` binds to localhost unless an address is given: docker's
          # own iptables rules bypass the firewall, so 0.0.0.0 meant the whole LAN
          ip = "127.0.0.1";
          dns = [
            "1.1.1.1"
            "8.8.8.8"
          ];
          storage-driver = "btrfs";
        };
      };
      fileSystems."/var/lib/docker" = {
        device = "/var/lib/nodatacow/docker";
        fsType = "none";
        options = [ "bind" ];
      };
    })
    (lib.mkIf cfg.distrobox.enable {
      environment.systemPackages = [ pkgs.distrobox ];
    })
  ];
}
