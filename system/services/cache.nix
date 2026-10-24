# zbioe.cachix.org (system/nix/substituters.nix): each new system and home of
# this host is pushed there, only what cache.nixos.org doesn't have
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.services.cache;
  user = config.dotnix.core.user.name;
  home = config.users.users.${user}.home;
  profiles = [
    "/nix/var/nix/profiles/system"
    "${home}/.local/state/nix/profiles/home-manager"
  ];
  # unfree packages stay out (licenses, and the 5 GB of the free plan), with
  # what refers to them (cachix pushes closures); by name, so their GTK4-swapped
  # copies and parts go too. The home has none of its own.
  unfree = lib.filter (
    p: !lib.all (l: l.free or true) (lib.toList (p.meta.license or [ ]))
  ) config.environment.systemPackages;
  unfreeRe = "^/nix/store/[a-z0-9]{32}-(${
    lib.concatMapStringsSep "|" lib.escapeRegex (lib.unique (map lib.getName unfree))
  })([-.]|$)";
in
{
  options.dotnix.services.cache.push.enable =
    lib.mkEnableOption "pushing this host's builds to zbioe.cachix.org";

  config = lib.mkIf cfg.push.enable {
    assertions = [
      {
        assertion = config.dotnix.core.secrets.enable;
        message = "dotnix.services.cache.push: its token is in secrets/ (core.secrets)";
      }
    ];

    # CACHIX_AUTH_TOKEN=...
    sops.secrets.cachix-env = { };

    systemd.services.cachix-push = {
      description = "Push the current system and home to zbioe.cachix.org";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.sops.secrets.cachix-env.path;
        RuntimeDirectory = "cachix-push";
        WorkingDirectory = "/run/cachix-push";
        Nice = 19;
        IOSchedulingClass = "idle";
      };
      path = [
        config.nix.package
        pkgs.coreutils
        pkgs.gnugrep
      ];
      script = ''
        paths=()
        for p in ${lib.escapeShellArgs profiles}; do
          [ -e "$p" ] && paths+=("$(readlink -f "$p")")
        done
        nix path-info -r "''${paths[@]}" | sort -u > closure
        grep -E ${lib.escapeShellArg unfreeRe} closure > unfree || true
        if [ -s unfree ]; then
          xargs nix-store -q --referrers-closure < unfree | sort -u > skip
        else
          : > skip
        fi
        # (already there or on cache.nixos.org: skipped by cachix)
        comm -23 closure skip | ${lib.getExe pkgs.cachix} push zbioe
      '';
    };

    # a switch, a boot entry or a home generation
    systemd.paths.cachix-push = {
      wantedBy = [ "multi-user.target" ];
      pathConfig = {
        PathChanged = profiles;
        TriggerLimitIntervalSec = "1min";
      };
    };
  };
}
