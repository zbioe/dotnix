# Proton VPN (app and CLI) through NetworkManager, so `vpn` and the bar's
# widget (home) see and stop it too
{
  config,
  lib,
  pkgs,
  unstable,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.network.vpn;

  # privsec.dev: Proton's own kill switch lets programs bound to the physical
  # interface out (`curl --interface wlp3s0`). While a WireGuard tunnel is up,
  # the physical interfaces only carry the tunnel, the LAN and DHCP; this goes
  # with the tunnel.
  killswitch = pkgs.writeShellScript "vpn-killswitch" ''
    export PATH=${
      lib.makeBinPath (
        with pkgs;
        [
          coreutils
          gawk
          networkmanager
          nftables
          wireguard-tools
        ]
      )
    }
    iface=$1
    action=$2
    state=/run/dotnix-killswitch
    case "$action" in
      up)
        [ "$(nmcli -g GENERAL.TYPE device show "$iface" 2>/dev/null)" = wireguard ] || exit 0
        physical=$(nmcli -t -f DEVICE,TYPE device | awk -F: '$2 == "wifi" || $2 == "ethernet" { printf "%s\"%s\"", (n++ ? ", " : ""), $1 }')
        [ -n "$physical" ] || exit 0
        endpoints=""
        while read -r _ endpoint; do
          host=''${endpoint%:*}
          port=''${endpoint##*:}
          case "$host" in
            \[*) endpoints+="ip6 daddr ''${host:1:-1} udp dport $port accept;" ;;
            *) endpoints+="ip daddr $host udp dport $port accept;" ;;
          esac
        done < <(wg show "$iface" endpoints)
        lan="ip daddr { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 169.254.0.0/16 } accept; ip6 daddr { fe80::/10, fc00::/7 } accept;"
        nft delete table inet dotnix_killswitch 2>/dev/null || true
        nft -f - <<EOF
    table inet dotnix_killswitch {
      chain output {
        type filter hook output priority 0; policy accept;
        oifname != { $physical } accept
        $lan
        udp dport { 67, 68, 546, 547 } accept
        $endpoints
        counter drop
      }
      chain forward {
        type filter hook forward priority 0; policy accept;
        oifname != { $physical } accept
        $lan
        counter drop
      }
    }
    EOF
        echo "$iface" >"$state"
        ;;
      # the tunnel may be gone already: the name it was put up for decides
      down | pre-down)
        [ "$(cat "$state" 2>/dev/null)" = "$iface" ] || exit 0
        nft delete table inet dotnix_killswitch 2>/dev/null || true
        rm -f "$state"
        ;;
    esac
  '';
in
{
  options.dotnix.network.vpn = {
    enable = lib.mkEnableOption "VPNs";
    proton.enable = dotlib.mkItem cfg "Proton VPN";
    warp.enable = dotlib.mkItem cfg "Cloudflare WARP";
    killswitch.enable = lib.mkEnableOption "nothing but the tunnel (and the LAN) on the physical interfaces while a WireGuard VPN is up";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.killswitch.enable {
      networking.networkmanager.dispatcherScripts = [
        {
          source = killswitch;
          type = "basic";
        }
      ];
    })
    (lib.mkIf cfg.proton.enable {
      environment.systemPackages = [
        unstable.proton-vpn # the app: every server, by country, settings
        unstable.proton-vpn-cli # `protonvpn connect`, used by `vpn`
      ];
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
