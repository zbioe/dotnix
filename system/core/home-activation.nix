# The home activated at boot, before the login screen: on the live ISO every
# time, on a new install only the first (then `nh home switch` owns it).
{
  config,
  lib,
  pkgs,
  homeActivation,
  ...
}:
let
  inherit (lib) types mkOption mkIf;
  cfg = config.dotnix.core.homeActivation;
  user = config.dotnix.core.user.name;
  home = config.users.users.${user}.home;

  # a new install, online once: the flake's history from upstream (with this
  # host in it after dotnix-adopt, else its files kept), then the first
  # rebuild (hosts/<host>/hardware.nix, and secrets/ once adopted)
  firstboot = pkgs.writeShellApplication {
    name = "dotnix-firstboot";
    runtimeInputs = with pkgs; [
      coreutils
      git
      nh
    ];
    text = ''
      flake=''${NH_FLAKE:-$HOME/dotnix}
      host=$(uname -n)
      cd "$flake"
      git fetch -q origin
      upstream=false
      if git cat-file -e "origin/main:hosts/$host/default.nix" 2>/dev/null; then
        git reset -q --hard origin/main
        upstream=true
      else
        git reset -q origin/main
        git add "hosts/$host"
        echo "hosts/$host isn't upstream yet: dotnix-adopt $host's address on a machine with your age key, then this again"
      fi
      nh os switch -H "$host" "$flake"
      nh home switch -c "$host" "$flake"
      # (without secrets/ yet: dotnix-firstboot.service still waits for upstream)
      [ "$upstream" = false ] || rm -f .git/dotnix-firstboot
      if command -v dotnix-tpm2-enroll >/dev/null; then dotnix-tpm2-enroll --offer; fi
    '';
  };

  # the same by itself (dotnix-install leaves the marker): tried every few
  # minutes until hosts/<host> is upstream (dotnix-adopt), then built, the
  # system for the next boot and the home now, and the user told to reboot
  flake = "${home}/dotnix";
  marker = "${flake}/.git/dotnix-firstboot";
  autoFirstboot = pkgs.writeShellScript "dotnix-firstboot-auto" ''
    set -euo pipefail
    host=${config.networking.hostName}
    uid=$(id -u ${user})
    as() { runuser -u ${user} -- env HOME=${home} XDG_RUNTIME_DIR=/run/user/$uid "$@"; }
    cd ${flake}
    if ! as git fetch -q origin; then
      echo "offline: next time"
      exit 0
    fi
    if ! as git cat-file -e "origin/main:hosts/$host/default.nix" 2>/dev/null; then
      echo "hosts/$host isn't upstream yet (dotnix-adopt)"
      exit 0
    fi
    as git reset -q --hard origin/main
    # both in one build: one evaluation, built side by side
    as nix build --no-link "${flake}#nixosConfigurations.$host.config.system.build.toplevel" \
      "${flake}#homeConfigurations.$host.activationPackage"
    system=$(as nix path-info "${flake}#nixosConfigurations.$host.config.system.build.toplevel")
    hm=$(as nix path-info "${flake}#homeConfigurations.$host.activationPackage")
    nix-env -p /nix/var/nix/profiles/system --set "$system"
    "$system/bin/switch-to-configuration" boot
    if [ -S /run/user/$uid/bus ]; then
      as env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus "$hm/activate"
    else
      as "$hm/activate"
    fi
    rm ${marker}
    body="Reboot to finish."
    [ ! -e "$system/sw/bin/dotnix-tpm2-enroll" ] || body="$body Then dotnix-tpm2-enroll: the disk opens with the TPM and a PIN."
    if [ -S /run/user/$uid/bus ]; then
      as env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus \
        notify-send -a dotnix -i system-reboot "$host is set up" "$body" || true
    fi
  '';
in
{
  options.dotnix.core.homeActivation = with types; {
    enable = mkOption {
      type = bool;
      default = false;
      description = "Activate the user's home-manager generation at boot.";
    };
    package = mkOption {
      type = package;
      default = homeActivation;
      defaultText = lib.literalExpression "homeConfigurations.bx.activationPackage";
      description = "The home-manager activation package (homeConfigurations.<host>.activationPackage).";
    };
    always = mkOption {
      type = bool;
      default = false;
      description = "Activate on every boot (live system), not only when the home has never been activated.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ firstboot ];
    systemd.services.dotnix-firstboot = mkIf (!cfg.always) {
      description = "First rebuild of a new install, from upstream";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      unitConfig.ConditionPathExists = marker;
      path = [
        config.nix.package
        pkgs.git
        pkgs.openssh
        pkgs.util-linux
        pkgs.libnotify
      ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = autoFirstboot;
      };
    };
    systemd.timers.dotnix-firstboot = mkIf (!cfg.always) {
      wantedBy = [ "timers.target" ];
      unitConfig.ConditionPathExists = marker;
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = "5min";
      };
    };
    systemd.services.home-activation = {
      description = "Activate ${user}'s home (home-manager)";
      wantedBy = [ "multi-user.target" ];
      before = [ "display-manager.service" ];
      after = [ "nix-daemon.socket" ];
      requires = [ "nix-daemon.socket" ];
      unitConfig.RequiresMountsFor = [ home ];
      path = [ pkgs.util-linux ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${lib.optionalString (!cfg.always) ''
          if [ -e ${home}/.local/state/nix/profiles/home-manager ]; then exit 0; fi
        ''}
        # no session yet: no systemd user instance to reload, D-Bus started
        # for dconf by home-manager itself; steps that download a lot can
        # skip themselves (DOTNIX_BOOT_ACTIVATION)
        exec runuser -l ${user} -c "DOTNIX_BOOT_ACTIVATION=1 ${cfg.package}/activate"
      '';
    };
  };
}
