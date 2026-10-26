# zbioe.cachix.org (system/nix/substituters.nix): each new system and home of
# this host is pushed there, only what cache.nixos.org doesn't have
{
  config,
  lib,
  pkgs,
  homes,
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
  # copies and parts go too. The system's and this host's home's.
  hostHome = homes.${config.networking.hostName} or null;
  unfree = lib.filter (p: !lib.all (l: l.free or true) (lib.toList (p.meta.license or [ ]))) (
    config.environment.systemPackages ++ lib.optionals (hostHome != null) hostHome.config.home.packages
  );
  unfreeRe = "^/nix/store/[a-z0-9]{32}-(${
    lib.concatMapStringsSep "|" lib.escapeRegex (lib.unique (map lib.getName unfree))
  })([-.]|$)";
in
{
  options.dotnix.services.cache = {
    push.enable = lib.mkEnableOption "pushing this host's builds to zbioe.cachix.org";
    warnAt = lib.mkOption {
      type = lib.types.ints.positive;
      default = 4000;
      description = "MB this host's system and home take on the cache (compressed) above which the user is told; the free plan has 5 GB.";
    };
  };

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
        pkgs.gnused
        pkgs.gawk
        pkgs.curl
        pkgs.util-linux
        pkgs.libnotify
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
        comm -23 closure skip > push
        ${lib.getExe pkgs.cachix} push zbioe < push

        # what they take there (compressed, as the narinfos say): past the
        # free plan, the least used go, older generations first, then these
        sed -E 's|^/nix/store/([a-z0-9]{32})-.*|url = "https://zbioe.cachix.org/\1.narinfo"|' push > urls
        mb=$(curl -s --parallel --parallel-max 32 -K urls | awk '/^FileSize:/ { s += $2 } END { printf "%d", s / 1e6 }')
        echo "zbioe.cachix.org: this system and home take $mb MB"
        uid=$(id -u ${user})
        if [ "$mb" -gt ${toString cfg.warnAt} ] && [ -S /run/user/$uid/bus ]; then
          runuser -u ${user} -- env DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$uid/bus \
            notify-send -a cachix -i dialog-warning "Binary cache almost full" \
            "This system and home take $mb MB of zbioe.cachix.org's 5 GB" || true
        fi
      '';
    };

    # a switch, a boot entry or a home generation: their folders (a watch on
    # the profile links follows them into the store, where nothing changes)
    systemd.paths.cachix-push = {
      wantedBy = [ "multi-user.target" ];
      pathConfig = {
        PathChanged = map dirOf profiles;
        TriggerLimitIntervalSec = "1min";
      };
    };
  };
}
