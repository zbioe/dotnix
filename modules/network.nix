{
  pkgs,
  config,
  lib,
  options,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.network;
in
{
  options.modules.network = with types; {
    enable = mkBoolOpt true;
    dns = mkOpt' (listOf str) [
      "1.1.1.1"
      "8.8.8.8"
      "8.8.4.4"
    ] "name servers";
  };
  config = mkIf cfg.enable {
    networking.hostName = config.host.name; # Define your hostname.
    networking.networkmanager = {
      dns = "systemd-resolved";
      enable = true; # Enables wireless support via wpa_supplicant.
    };
    networking.wireless.iwd.enable = true;
    networking.wireless.userControlled.enable = true;
    networking.search = cfg.dns;
    networking.nameservers = cfg.dns;
    users.users.${config.user.name}.extraGroups = [ "networkmanager" ];
  };
}
