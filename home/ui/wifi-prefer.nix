# `wifi-prefer`: moves to the saved Wi-Fi network of highest priority in
# range. NetworkManager only honours connection.autoconnect-priority when it
# connects, never while a lower one still works; a user timer checks every
# 2 minutes and switches when a higher network has a good signal (>= 60%).
# On/off and the order of the networks: the "Wi-Fi Priority" panel
# (noctalia-plugins/wifi; middle click on the network icon, or the launcher)
# or this command.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  wifiPrefer = pkgs.writeShellApplication {
    name = "wifi-prefer";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      networkmanager
    ];
    text = ''
      state=${config.xdg.stateHome}/wifi-prefer
      min_signal=60

      usage() {
        echo "usage: wifi-prefer [status | on | off | toggle | list | order UUID... | tick]"
      }

      enabled() { [ "$(cat "$state/enabled" 2>/dev/null || echo on)" = on ]; }

      set_enabled() {
        mkdir -p "$state"
        echo "$1" > "$state/enabled"
      }

      # saved Wi-Fi connections, highest priority first:
      # PRIORITY<TAB>UUID<TAB>NAME<TAB>SSID<TAB>ACTIVE(yes/no)<TAB>SIGNAL (0 = out of range)
      list() {
        local signals
        signals=$(nmcli -t -f SSID,SIGNAL device wifi list --rescan no 2>/dev/null || true)
        nmcli -t -f UUID,TYPE,ACTIVE connection show | while IFS=: read -r uuid type active; do
          [ "$type" = 802-11-wireless ] || continue
          IFS=$'\n' read -r -d "" name ssid prio < <(
            nmcli -g connection.id,802-11-wireless.ssid,connection.autoconnect-priority connection show "$uuid"
            printf '\0'
          ) || true
          signal=$(printf '%s\n' "$signals" | awk -F: -v s="$ssid" '$1 == s && $2 > m { m = $2 } END { print m + 0 }')
          printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$prio" "$uuid" "$name" "$ssid" "$active" "$signal"
        done | sort -t$'\t' -k1,1nr -k3,3
      }

      # priorities from an order (first = highest): 10 * (count - index)
      order() {
        local n=$#
        for uuid in "$@"; do
          nmcli connection modify "$uuid" connection.autoconnect-priority $((n * 10))
          n=$((n - 1))
        done
      }

      tick() {
        enabled || return 0
        local current best
        current=$(list | awk -F'\t' '$5 == "yes" { print $1; exit }')
        # not on Wi-Fi: NetworkManager's own autoconnect picks by priority
        [ -n "$current" ] || return 0
        best=$(list | awk -F'\t' -v cur="$current" -v min="$min_signal" \
          '$5 == "no" && $1 > cur && $6 >= min { print $2; exit }')
        [ -n "$best" ] || return 0
        echo "wifi-prefer: switching to $best"
        nmcli connection up "$best" >/dev/null
      }

      case "''${1:-status}" in
        status) if enabled; then echo on; else echo off; fi ;;
        on | off) set_enabled "$1" ;;
        toggle) if enabled; then set_enabled off; else set_enabled on; fi ;;
        list) list ;;
        order)
          shift
          order "$@"
          ;;
        tick) tick ;;
        *)
          usage
          exit 1
          ;;
      esac
    '';
  };
in
{
  home.packages = [ wifiPrefer ];

  systemd.user.services.wifi-prefer = {
    Unit.Description = "Move to the preferred Wi-Fi network in range";
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe wifiPrefer} tick";
    };
  };
  systemd.user.timers.wifi-prefer = {
    Unit.Description = "Move to the preferred Wi-Fi network in range";
    Timer = {
      OnStartupSec = "1min";
      OnUnitActiveSec = "2min";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  xdg.desktopEntries.wifi-priority = {
    name = "Wi-Fi Priority";
    comment = "Order of the saved Wi-Fi networks, and switching to the preferred one";
    exec = "noctalia msg panel-toggle dotnix/wifi:priority";
    icon = "network-wireless";
    terminal = false;
    categories = [ "Settings" ];
  };
}
