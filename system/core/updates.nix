# flake-updates' "auto" mode: the system it built becomes the next boot's
# default, never switched under the running session
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.core.updates;
  user = config.dotnix.core.user.name;
  home = config.users.users.${user}.home;
  host = config.networking.hostName;
in
{
  options.dotnix.core.updates.enable = lib.mkEnableOption "flake-updates' boot side";

  config = lib.mkIf cfg.enable {
    systemd.services.dotnix-update-boot = {
      description = "Make the system built by flake-updates the next boot's default";
      serviceConfig.Type = "oneshot";
      path = [ pkgs.coreutils ];
      script = ''
        system=$(head -c 300 ${home}/.local/state/flake-updates/pending-system)
        [[ $system =~ ^/nix/store/[a-z0-9]{32}-nixos-system-${host}-[^/]+$ ]] || {
          echo "not a ${host} system: $system"
          exit 1
        }
        [ -x "$system/bin/switch-to-configuration" ] || exit 1
        ${config.nix.package}/bin/nix-env -p /nix/var/nix/profiles/system --set "$system"
        "$system/bin/switch-to-configuration" boot
      '';
    };

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            action.lookup("unit") == "dotnix-update-boot.service" &&
            action.lookup("verb") == "start" && subject.user == "${user}") {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
