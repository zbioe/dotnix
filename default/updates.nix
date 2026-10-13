# The system side of `flake-updates` (home/ui/flake-updates.nix) in "auto"
# mode: the system it built, as the default of the next boot (like
# `nixos-rebuild boot`), never switched under the running session. It takes
# the path from the user's state and only a NixOS system of this host
# (validated); the user starts it without a password.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  user = config.modules.user.name;
  home = config.users.users.${user}.home;
  host = config.networking.hostName;
in
{
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
}
