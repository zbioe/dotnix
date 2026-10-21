# The Wi-Fi networks of secrets/ (ssid, password, priority: names stay
# private too), added to NetworkManager when missing, so a new install connects
# by itself and changes made later (wifi-prefer's order) are kept
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.network.wifi;
in
{
  options.dotnix.network.wifi.enable = lib.mkEnableOption "the Wi-Fi networks of secrets/";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.dotnix.core.secrets.enable;
        message = "dotnix.network.wifi needs dotnix.core.secrets";
      }
    ];

    sops.secrets.wifi = { };

    systemd.services.wifi-seed = {
      description = "Add the missing Wi-Fi networks of secrets/";
      wantedBy = [ "NetworkManager.service" ];
      before = [ "NetworkManager.service" ];
      serviceConfig.Type = "oneshot";
      path = with pkgs; [
        coreutils
        gnugrep
        jq
        util-linux
      ];
      script = ''
        dir=/etc/NetworkManager/system-connections
        install -d -m 700 "$dir"
        umask 077
        jq -c '.[]' ${config.sops.secrets.wifi.path} | while read -r net; do
          ssid=$(jq -r .ssid <<<"$net")
          if grep -qxF "ssid=$ssid" "$dir"/*.nmconnection 2>/dev/null; then continue; fi
          cat >"$dir/''${ssid//\//_}.nmconnection" <<EOF
        [connection]
        id=$ssid
        uuid=$(uuidgen)
        type=wifi
        autoconnect-priority=$(jq -r '.priority // 0' <<<"$net")

        [wifi]
        mode=infrastructure
        ssid=$ssid

        [wifi-security]
        key-mgmt=wpa-psk
        psk=$(jq -r .psk <<<"$net")

        [ipv4]
        method=auto

        [ipv6]
        method=auto
        EOF
          echo "wifi-seed: added $ssid"
        done
      '';
    };
  };
}
