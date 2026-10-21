# Proton VPN's app: every server, through NetworkManager, so `vpn` and the
# bar's widget (home) see it too
{
  config,
  lib,
  unstable,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.network.vpn;
in
{
  options.dotnix.network.vpn = {
    enable = lib.mkEnableOption "VPNs";
    proton.enable = dotlib.mkItem cfg "Proton VPN";
    warp.enable = dotlib.mkItem cfg "Cloudflare WARP";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.proton.enable {
      environment.systemPackages = [ unstable.proton-vpn ];
      # WireGuard routes everything through the tunnel; strict rpfilter drops its replies
      networking.firewall.checkReversePath = "loose";
    })
    (lib.mkIf cfg.warp.enable {
      services.cloudflare-warp = {
        enable = true;
        package = unstable.cloudflare-warp;
      };
      environment.systemPackages = with unstable; [
        cloudflared # cloudflare tunnel
        cloudflare-cli # cloudflare api from the terminal
      ];
      systemd.user.services.warp-taskbar.wantedBy = [ "graphical.target" ];
      fileSystems."/var/lib/cloudflare-warp" = {
        device = "/var/lib/nodatacow/cloudflare-warp";
        fsType = "none";
        options = [ "bind" ];
      };
    })
  ];
}
