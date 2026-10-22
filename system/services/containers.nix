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
  daemon = {
    # `-p 3000:3000` binds to localhost unless an address is given: docker's
    # own iptables rules bypass the firewall, so 0.0.0.0 meant the whole LAN
    ip = "127.0.0.1";
    dns = [
      "1.1.1.1"
      "8.8.8.8"
    ];
  };
in
{
  options.dotnix.services.containers = {
    enable = lib.mkEnableOption "containers";
    docker = {
      enable = dotlib.mkItem cfg "Docker";
      rootless = lib.mkEnableOption "Docker as your user (images in ~/.local/share/docker)";
    };
    distrobox.enable = dotlib.mkItem cfg "Distrobox";
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.docker.enable && !cfg.docker.rootless) {
      virtualisation.docker = {
        enable = true;
        package = unstable.docker;
        daemon.settings = daemon // {
          storage-driver = "btrfs";
        };
      };
      fileSystems."/var/lib/docker" = {
        device = "/var/lib/nodatacow/docker";
        fsType = "none";
        options = [ "bind" ];
      };
      users.users.${config.dotnix.core.user.name}.extraGroups = [ "docker" ];
    })
    # the docker group is root in all but name; rootless runs the daemon as you
    (lib.mkIf (cfg.docker.enable && cfg.docker.rootless) {
      virtualisation.docker.rootless = {
        enable = true;
        package = unstable.docker;
        setSocketVariable = true;
        daemon.settings = daemon;
      };
    })
    (lib.mkIf cfg.distrobox.enable {
      environment.systemPackages = [ pkgs.distrobox ];
    })
  ];
}
