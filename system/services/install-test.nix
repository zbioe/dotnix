# install-test (checks/vm/install.nix) doesn't fit CI: this host runs it each
# night it is on, on the flake's last commit, a quick no-op unless something changed,
# and tells the user when it fails. It boots an 8 GB VM: skipped when the
# memory isn't there.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.services.installTest;
  user = config.dotnix.core.user.name;
  home = config.users.users.${user}.home;
  flake = "${home}/dotnix";
in
{
  options.dotnix.services.installTest.enable =
    lib.mkEnableOption "a daily run of install-test on the flake's last commit";

  config = lib.mkIf cfg.enable {
    systemd.services.install-test = {
      description = "dotnix-install on a VM (install-test)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      onFailure = [ "install-test-failed.service" ];
      environment.HOME = home;
      path = [
        config.nix.package
        pkgs.git
        pkgs.gawk
      ];
      serviceConfig = {
        Type = "oneshot";
        User = user;
        Nice = 19;
        IOSchedulingClass = "idle";
      };
      script = ''
        free=$(awk '/MemAvailable/ { printf "%d", $2 / 1048576 }' /proc/meminfo)
        if [ "$free" -lt 16 ]; then
          echo "$free GB free, 16 needed: tomorrow"
          exit 0
        fi
        rev=$(git -C ${flake} rev-parse HEAD)
        echo "install-test on $rev"
        # (the log stays out of the journal: `nix log` has it)
        nix build --no-link "git+file://${flake}?rev=$rev#install-test" || {
          echo "failed: nix log git+file://${flake}?rev=$rev#install-test"
          exit 1
        }
      '';
    };

    systemd.services.install-test-failed = {
      description = "Tell the user install-test failed";
      serviceConfig.Type = "oneshot";
      script = ''
        uid=$(${pkgs.coreutils}/bin/id -u ${user})
        [ -S /run/user/$uid/bus ] || exit 0
        ${pkgs.util-linux}/bin/runuser -u ${user} -- ${pkgs.coreutils}/bin/env \
          DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus \
          ${pkgs.libnotify}/bin/notify-send -a dotnix -u critical -i dialog-error \
          "install-test failed" "dotnix-install broke: journalctl -u install-test" || true
      '';
    };

    # only at night, when the machine is on: its builds run in nix-daemon, at
    # full priority whatever this service's (not right after a boot, then)
    systemd.timers.install-test = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*-*-* 03:30";
        RandomizedDelaySec = "15min";
      };
    };
  };
}
