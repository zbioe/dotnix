# Less to track on other people's networks (privsec.dev): a MAC address of
# its own for each network, and no hostname in DHCP requests
{ config, lib, ... }:
let
  cfg = config.dotnix.network.privacy;
in
{
  options.dotnix.network.privacy = {
    macAddress.enable = lib.mkEnableOption "a different, stable MAC address per network (random while scanning)";
    hideHostname.enable = lib.mkEnableOption "keeping the hostname out of DHCP";
  };

  config = {
    networking.networkmanager = lib.mkMerge [
      (lib.mkIf cfg.macAddress.enable {
        # stable: derived from each connection, so a network keeps its lease
        wifi.macAddress = "stable";
        wifi.scanRandMacAddress = true;
        ethernet.macAddress = "stable";
      })
      (lib.mkIf cfg.hideHostname.enable {
        settings.connection = {
          "ipv4.dhcp-send-hostname" = false;
          "ipv6.dhcp-send-hostname" = false;
        };
      })
    ];
  };
}
