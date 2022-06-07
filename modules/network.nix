{pkgs, config, lib, options, ...}:
with lib;
with lib.my;
let
  cfg = config.modules.network;
in {
  options.modules.network = with types; {
    enable = mkBoolOpt true;
    dns = mkOpt' (listOf str) [ "8.8.8.8" "1.1.1.1" ] "name servers";
  };
  config = mkIf cfg.enable {
    networking.hostName = config.host.name; # Define your hostname.
    networking.networkmanager.enable = true;  # Enables wireless support via wpa_supplicant.
    networking.nameservers = cfg.dns;
    networking.search = cfg.dns;
    users.users.${config.user.name}.extraGroups = [
      "networkmanager"
    ];
  };
}
