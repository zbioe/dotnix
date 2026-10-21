# Proton VPN's own app: every server, connected through NetworkManager, so the
# bar's VPN widget and `vpn` (home/ui/vpn.nix) see and stop it too
{
  config,
  lib,
  unstable,
  ...
}:
let
  cfg = config.modules.protonvpn;
in
{
  options.modules.protonvpn.enable = lib.mkEnableOption "the Proton VPN app";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ unstable.proton-vpn ];
    # WireGuard routes everything through the tunnel; strict rpfilter drops its replies
    networking.firewall.checkReversePath = "loose";
  };
}
