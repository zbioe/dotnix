# btrfs snapshots (snapper) of the subvolumes that outlive a boot: / is
# rolled back to root-blank at every boot and the system itself rolls back
# through NixOS generations, so only /home and /persist hold state to save.
# Hourly/daily/weekly timeline, plus one before every `rebuild`
# (home/ui/rebuild.nix). Directories that change a lot and need no history
# (caches, downloads) are subvolumes of their own, which snapshots skip.
# Browse them in <subvolume>/.snapshots/N/snapshot, or `snapper -c home list` / `snapper -c home undochange N..0 FILE`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) types mkOption mkIf;
  cfg = config.modules.snapshots;

  home = config.users.users.${config.modules.user.name}.home;

  # each directory turned into a subvolume (once, at boot, before anyone
  # logs in): `keep` copies its contents over (reflinks, no extra space),
  # otherwise it starts empty
  excludeScript = ''
    exclude() {
      local dir=$1 keep=$2 new="$1.subvol-new" old="$1.subvol-old"
      # an earlier run stopped between its two renames
      if [ ! -e "$dir" ] && [ -d "$old" ]; then mv -T "$old" "$dir"; fi
      # already a subvolume (its root inode is always 256)
      if [ -d "$dir" ] && [ "$(stat -c %i "$dir")" = 256 ]; then return 0; fi
      rm -rf "$new"
      btrfs subvolume create "$new"
      if [ -d "$dir" ]; then
        chown --reference="$dir" "$new"
        chmod --reference="$dir" "$new"
        if [ "$keep" = 1 ]; then cp -a --reflink=always "$dir/." "$new/"; fi
        mv -T "$dir" "$old"
      else
        chown "${config.modules.user.name}:users" "$new"
        chmod 700 "$new"
      fi
      mv -T "$new" "$dir"
      rm -rf "$old"
      echo "snapshot-exclude: $dir is a subvolume now"
    }
  ''
  + lib.concatMapStrings (d: ''
    exclude ${lib.escapeShellArg "${home}/${d.path}"} ${if d.keep then "1" else "0"}
  '') cfg.exclude;

  # the timeline kept per subvolume (older ones are removed hourly)
  timeline = {
    TIMELINE_CREATE = true;
    TIMELINE_CLEANUP = true;
    TIMELINE_LIMIT_HOURLY = "12";
    TIMELINE_LIMIT_DAILY = "7";
    TIMELINE_LIMIT_WEEKLY = "4";
    # none older than a month: a deleted big file frees its space by then
    TIMELINE_LIMIT_MONTHLY = "0";
    TIMELINE_LIMIT_YEARLY = "0";
    # `rebuild` snapshots (cleanup algorithm "number")
    NUMBER_CLEANUP = true;
    NUMBER_LIMIT = "10";
  };
in
{
  options.modules.snapshots = with types; {
    enable = mkOption {
      type = bool;
      default = false;
      description = "Timeline snapshots of /home and /persist with snapper.";
    };
    exclude = mkOption {
      type = listOf (submodule {
        options = {
          path = mkOption {
            type = str;
            description = "Directory relative to the user's home.";
          };
          keep = mkOption {
            type = bool;
            default = true;
            description = "Keep its contents when it becomes a subvolume.";
          };
        };
      });
      default = [ ];
      description = "Home directories left out of the snapshots (made subvolumes of their own).";
    };
  };

  config = mkIf cfg.enable {
    services.snapper = {
      persistentTimer = true; # catch up on a snapshot missed while off
      configs = {
        # the user creates and reads these without sudo (`rebuild`, file
        # browser)
        home = timeline // {
          SUBVOLUME = "/home";
          ALLOW_USERS = [ config.modules.user.name ];
          SYNC_ACL = true;
        };
        # system state (logs, ssh host keys, Wi-Fi passwords): root only
        persist = timeline // {
          SUBVOLUME = "/persist";
        };
      };
    };

    systemd.services.snapshot-exclude = mkIf (cfg.exclude != [ ]) {
      description = "Leave busy home directories out of the snapshots";
      wantedBy = [ "multi-user.target" ];
      before = [ "systemd-user-sessions.service" ];
      unitConfig.RequiresMountsFor = [ home ];
      path = [
        pkgs.btrfs-progs
        pkgs.coreutils
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = excludeScript;
    };

    # snapper keeps each config's snapshots in a .snapshots subvolume of its own
    systemd.tmpfiles.rules = [
      "v /home/.snapshots 0750 root root -"
      "v /persist/.snapshots 0750 root root -"
    ];
  };
}
