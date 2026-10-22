# LibreWolf's private settings, from secrets/librewolf.yaml: uBlock Origin's
# rules (its managed storage, applied at every start) and the sites that stay
# logged in. Change them in the browser, then `librewolf-save` writes them to
# the flake; at the next start the flake's copy wins.
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.desktop.librewolf;
  secrets = ../../../secrets/librewolf.yaml;
  flake = "${config.home.homeDirectory}/dotnix";

  python = pkgs.python3.withPackages (p: [ p.python-snappy ]);

  # the default profile: what profiles.ini says to start
  profileOf = ''
    profile() {
      local dir=$HOME/.librewolf rel
      rel=$(awk -F= '/^\[Install/ { i = 1 } i && $1 == "Default" { print $2; exit }' "$dir/profiles.ini")
      [ -n "$rel" ] || rel=$(awk -F= '$1 == "Path" { p = $2 } $1 == "Default" && $2 == 1 { print p; exit }' "$dir/profiles.ini")
      echo "$dir/$rel"
    }
  '';

  save = pkgs.writeShellApplication {
    name = "librewolf-save";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      gnugrep
      jq
      python
      sops
      sqlite
    ];
    text = ''
      ${profileOf}
      p=$(profile)
      uuid=$(grep -oE '\\"uBlock0@raymondhill.net\\":\\"[0-9a-f-]+' "$p/prefs.js" | grep -oE '[0-9a-f-]{36}')
      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT
      # copies: the browser may hold them open
      cp "$p"/storage/default/moz-extension+++"$uuid"^userContextId=4294967295/idb/3647222921wleabcEoxlt-eengsairo.sqlite* "$tmp/"
      cp "$p"/permissions.sqlite* "$tmp/"
      python3 ${./ublock-read.py} "$tmp/3647222921wleabcEoxlt-eengsairo.sqlite" > "$tmp/ublock.json"
      sqlite3 "$tmp/permissions.sqlite" \
        "select origin from moz_perms where type = 'cookie' and permission = 1 order by origin" > "$tmp/cookies"
      jq -n --rawfile ublock "$tmp/ublock.json" --rawfile cookies "$tmp/cookies" \
        '{ublock: $ublock, "cookie-exceptions": $cookies}' > "$tmp/plain.json"
      sops encrypt --filename-override ${flake}/secrets/librewolf.yaml --input-type json --output-type yaml \
        "$tmp/plain.json" > "$tmp/librewolf.yaml"
      mv "$tmp/librewolf.yaml" ${flake}/secrets/librewolf.yaml
      echo "saved: $(jq '.data.adminSettings | fromjson | .dynamicFilteringString | split("\n") | length' "$tmp/ublock.json") uBlock rules, $(wc -l < "$tmp/cookies") cookie exceptions -> secrets/librewolf.yaml"
    '';
  };

  # the flake's exceptions, exactly: the profile's own are replaced
  cookies = pkgs.writeShellApplication {
    name = "librewolf-cookie-exceptions";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      procps
      sqlite
    ];
    text = ''
      ${profileOf}
      if pgrep -f 'bin/\.?librewolf' >/dev/null; then
        echo "LibreWolf is running: its exceptions stay until the next login"
        exit 0
      fi
      db=$(profile)/permissions.sqlite
      [ -e "$db" ] || exit 0
      now=$(($(date +%s) * 1000))
      {
        echo "begin;"
        echo "delete from moz_perms where type = 'cookie';"
        while read -r origin; do
          [ -n "$origin" ] || continue
          o=''${origin//\'/}
          echo "insert into moz_perms (origin, type, permission, expireType, expireTime, modificationTime) values ('$o', 'cookie', 1, 0, 0, $now);"
        done < ${config.sops.secrets.cookie-exceptions.path}
        echo "commit;"
      } | sqlite3 "$db" || echo "permissions.sqlite is busy: the exceptions stay until the next login"
    '';
  };
in
{
  options.dotnix.desktop.librewolf.enable = lib.mkEnableOption "LibreWolf's private settings" // {
    default = osConfig.dotnix.desktop.browsers.librewolf.enable;
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      { home.packages = [ save ]; }
      # until the first `librewolf-save`
      (lib.mkIf (builtins.pathExists secrets) {
        sops.secrets = {
          ublock = {
            sopsFile = secrets;
            # LibreWolf reads managed storage from ~/.librewolf, not ~/.mozilla
            path = "${config.home.homeDirectory}/.librewolf/managed-storage/uBlock0@raymondhill.net.json";
          };
          cookie-exceptions.sopsFile = secrets;
        };

        systemd.user.services.librewolf-cookie-exceptions = {
          Unit = {
            Description = "LibreWolf's cookie exceptions from the flake";
            After = [ "sops-nix.service" ];
            Requires = [ "sops-nix.service" ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = lib.getExe cookies;
          };
          Install.WantedBy = [ "default.target" ];
        };
      })
    ]
  );
}
