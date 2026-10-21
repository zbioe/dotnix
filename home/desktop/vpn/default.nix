# `vpn`: the VPN connections NetworkManager knows (the Proton VPN app's, while
# connected, and WireGuard .conf files imported with `vpn add`): status, up,
# down, toggle. The bar's VPN widget and panel ./plugin run it.
{
  lib,
  config,
  pkgs,
  ...
}:
let
  vpn = pkgs.writeShellApplication {
    name = "vpn";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      jq
      networkmanager
      util-linux
    ];
    text = ''
      state=''${XDG_STATE_HOME:-$HOME/.local/state}/vpn

      usage() {
        echo "usage: vpn [status [--json] | up [NAME] | down | toggle | list | add FILE.conf | remove NAME | app]"
      }

      # VPN connections as UUID<TAB>TYPE<TAB>ACTIVE(yes/no)<TAB>NAME
      connections() {
        nmcli -t -f UUID,TYPE,ACTIVE connection show | while IFS=: read -r uuid type active; do
          case "$type" in vpn | wireguard) ;; *) continue ;; esac
          printf '%s\t%s\t%s\t%s\n' "$uuid" "$type" "$active" "$(nmcli -g connection.id connection show "$uuid")"
        done
      }

      json() {
        connections | jq -R -s --argjson app "$(command -v protonvpn-app >/dev/null && echo true || echo false)" \
          --arg last "$(cat "$state/last" 2>/dev/null || true)" '
          [split("\n")[] | select(. != "") | split("\t") | {uuid: .[0], type: .[1], active: (.[2] == "yes"), name: .[3]}]
          | {active: map(select(.active)), saved: ., last: $last, app: $app}'
      }

      up() {
        local id=''${1:-$(cat "$state/last" 2>/dev/null || true)}
        if [ -z "$id" ]; then
          app
          return
        fi
        nmcli connection up "$id" >/dev/null
        mkdir -p "$state"
        nmcli -g connection.uuid connection show "$id" >"$state/last"
      }

      down() {
        connections | awk -F'\t' '$3 == "yes" { print $1 }' | while read -r uuid; do
          nmcli connection down "$uuid" >/dev/null
        done
      }

      # the app is a single instance: running it again shows its window
      app() {
        command -v protonvpn-app >/dev/null || { echo "vpn: the Proton VPN app isn't installed (modules.protonvpn)" >&2; exit 1; }
        setsid -f protonvpn-app >/dev/null 2>&1
      }

      case "''${1:-status}" in
        status)
          if [ "''${2:-}" = --json ]; then
            json
          else
            connections | awk -F'\t' '$3 == "yes" { print "up\t" $4; f = 1 } END { if (!f) print "down" }'
          fi
          ;;
        up) up "''${2:-}" ;;
        down) down ;;
        toggle)
          if connections | awk -F'\t' '$3 == "yes" { f = 1 } END { exit !f }'; then down; else up; fi
          ;;
        list) connections | awk -F'\t' '{ printf "%s %s\t%s\n", ($3 == "yes" ? "*" : " "), $4, $2 }' ;;
        add)
          [ -f "''${2:-}" ] || { usage >&2; exit 1; }
          uuid=$(nmcli connection import type wireguard file "$2" | grep -oE '[0-9a-f-]{36}')
          nmcli connection modify "$uuid" connection.autoconnect no
          echo "vpn: added $(nmcli -g connection.id connection show "$uuid")"
          ;;
        remove)
          [ -n "''${2:-}" ] || { usage >&2; exit 1; }
          nmcli connection delete "$2" >/dev/null
          ;;
        app) app ;;
        *)
          usage >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  options.dotnix.desktop.vpn.enable = lib.mkEnableOption "`vpn` and the bar's VPN widget";

  config = lib.mkIf config.dotnix.desktop.vpn.enable {
    home.packages = [ vpn ];

    dotnix.desktop.noctalia.plugins.vpn = {
      src = ./plugin;
      manifest = {
        name = "VPN";
        icon = "shield";
        description = "VPN state and connections of the dotnix `vpn` command.";
        widget = [
          {
            id = "vpn";
            entry = "widget.luau";
            actions.left = "panel-toggle dotnix/vpn:panel";
          }
        ];
        panel = [
          {
            id = "panel";
            entry = "panel.luau";
            width = 420;
            height = 520;
            placement = "attached";
            position = "auto";
          }
        ];
      };
      files."vpn.json" = (pkgs.formats.json { }).generate "vpn.json" {
        command = "${config.home.profileDirectory}/bin/vpn";
      };
    };
  };
}
