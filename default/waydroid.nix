{
  config,
  lib,
  pkgs,
  ...
}:

{

  fileSystems."/var/lib/waydroid" = {
    device = "/var/lib/nodatacow/waydroid";
    fsType = "none";
    options = [ "bind" ];
  };

  # Waydroid
  virtualisation.waydroid = {
    enable = true;
    package = pkgs.waydroid-nftables;
  };
  environment.systemPackages = with pkgs; [
    waydroid-helper
  ];
  networking.firewall.trustedInterfaces = [ "waydroid0" ];
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.forwarding" = 1;
  };

}
