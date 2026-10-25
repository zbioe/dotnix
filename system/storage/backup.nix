# Daily restic backup of /home and /persist (from read-only snapshots) through
# rclone; the secrets live in the user's keyring. Start with `backup setup`.
# Once a month a restore test: restic reads 1% of the data back and restores a
# sample of files from the last snapshot, checking their content.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) types mkOption mkIf;
  cfg = config.dotnix.storage.backup;
  user = config.dotnix.core.user.name;
  home = config.users.users.${user}.home;
  host = config.networking.hostName;
  repo = "rclone:${cfg.remote}:${cfg.path}/${host}";

  # keyring entries (secret-tool attributes)
  secret = key: "${pkgs.libsecret}/bin/secret-tool lookup service dotnix-backup key ${key}";

  # runs a command as the user, inside their session (keyring, notifications)
  asUser = pkgs.writeShellScript "backup-as-user" ''
    uid=$(${pkgs.coreutils}/bin/id -u ${user})
    bus=/run/user/$uid/bus
    if [ ! -S "$bus" ]; then
      echo "backup: ${user} is not logged in" >&2
      exit 1
    fi
    exec ${pkgs.util-linux}/bin/runuser -u ${user} -- ${pkgs.coreutils}/bin/env \
      HOME=${home} XDG_RUNTIME_DIR=/run/user/$uid DBUS_SESSION_BUS_ADDRESS=unix:path=$bus "$@"
  '';

  # rclone with the encrypted config unlocked from the keyring. Proton
  # sometimes rejects a block mid-upload and keeps the file as a draft, which
  # then blocks every retry of it ("a draft exist"): retries replace it.
  rclone = pkgs.writeShellScript "backup-rclone" ''
    export RCLONE_PASSWORD_COMMAND="${secret "rclone"}"
    exec ${pkgs.rclone}/bin/rclone --tpslimit 4 --protondrive-replace-existing-draft "$@"
  '';

  # restic environment, for root (the service) and for the user (`backup`)
  resticEnv = runAs: ''
    export RESTIC_REPOSITORY=${repo}
    export RESTIC_PASSWORD_COMMAND="${lib.optionalString (runAs != "") "${runAs} "}${secret "restic"}"
    # fewer, bigger files on the remote (Proton throttles many small uploads)
    export RESTIC_PACK_SIZE=64
  '';
  rcloneProgram =
    runAs:
    "-o rclone.program=${
      if runAs == "" then
        rclone
      else
        pkgs.writeShellScript "backup-rclone-as-user" ''exec ${asUser} ${rclone} "$@"''
    }";

  notify = urgency: title: body: ''
    ${asUser} ${pkgs.libnotify}/bin/notify-send -a backup -u ${urgency} -i drive-harddisk \
      ${lib.escapeShellArg title} ${body} || true
  '';

  stamp = "${cfg.cacheDir}/last-success";
  verified = "${cfg.cacheDir}/last-verify";
  verifyResult = "${cfg.cacheDir}/last-verify-result";
  # where the home directory is inside the snapshot being backed up
  backupHome = "/home/.backup/${lib.removePrefix "/home/" home}";
  # the Secure Boot keys (system/core/boot.nix): every restore test reads them
  # back, since a new machine takes them from here (dotnix-sbctl-keys)
  sbctlKeys =
    lib.optionals
      (
        config.dotnix.core.boot.secureBoot.enable
        && config.dotnix.storage.impermanence.enable
        && lib.elem "/persist" cfg.subvolumes
      )
      [
        "var/lib/sbctl/keys/PK/PK.key"
        "var/lib/sbctl/keys/KEK/KEK.key"
        "var/lib/sbctl/keys/db/db.key"
      ];

  # the backup itself (root); `auto` (timer) does nothing when the last one
  # is less than a day old, the user is away, the network is down or there
  # is no repository yet
  run = pkgs.writeShellScript "backup-run" ''
    set -euo pipefail
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.findutils
        pkgs.diffutils
        pkgs.jq
        pkgs.btrfs-progs
        pkgs.networkmanager
        pkgs.util-linux
      ]
    }:$PATH
    mode=$1
    # one at a time: runs share the snapshot path (a second one would
    # delete the snapshot the first is reading)
    exec 9>${cfg.cacheDir}/lock
    if ! flock -n 9; then
      echo "backup: another one is running"
      exit 0
    fi
    # the timers' runs: only when the last one is old enough
    case "$mode" in
      auto) last=${stamp} every=72000 ;;
      verify) last=${verified} every=2592000 ;;
      *) last="" ;;
    esac
    if [ -n "$last" ]; then
      if [ -e "$last" ] && [ $(( $(date +%s) - $(stat -c %Y "$last") )) -lt $every ]; then exit 0; fi
      [ -S "/run/user/$(id -u ${user})/bus" ] || exit 0
      nm-online -q -t 30 || exit 0
      # not set up yet (`backup setup`)
      ${asUser} ${secret "restic"} >/dev/null 2>&1 || exit 0
    fi

    ${resticEnv asUser}
    restic() {
      ${pkgs.restic}/bin/restic ${rcloneProgram asUser} --cache-dir ${cfg.cacheDir}/restic "$@"
    }

    if [ "$mode" = verify ] || [ "$mode" = verify-now ]; then
      tmp=$(mktemp -d /var/tmp/backup-verify.XXXXXX)
      trap 'rm -rf "$tmp"' EXIT
      fail() { echo "failed $1 $(date +%F)" > ${verifyResult}; exit 1; }
      echo "running $(date +%F)" > ${verifyResult}
      restic check --retry-lock 10m --read-data-subset 1% || fail check
      # up to 200 files under 20 MB, without glob characters (--include-file
      # reads patterns)
      restic ls --json --host ${host} latest \
        | jq -r 'select(.type == "file" and .size < 20000000) | .path | select(test("[][*?\\\\]") | not)' \
        | shuf -n 200 > "$tmp/files" || fail list
      ${lib.optionalString (sbctlKeys != [ ]) ''
        printf '/persist/.backup/%s\n' ${lib.escapeShellArgs sbctlKeys} >> "$tmp/files"
        sort -u -o "$tmp/files" "$tmp/files"
      ''}
      expected=$(wc -l < "$tmp/files")
      restic restore --host ${host} --target "$tmp/out" --include-file "$tmp/files" --verify latest || fail restore
      restored=$(find "$tmp/out" -type f | wc -l)
      [ "$restored" -eq "$expected" ] || fail "missing:$((expected - restored))"
      for k in ${lib.escapeShellArgs sbctlKeys}; do
        cmp -s "$tmp/out/persist/.backup/$k" "/persist/$k" || fail sbctl
      done
      echo "ok $restored files, $(date +%F)" > ${verifyResult}
      touch ${verified}
      if [ "$mode" = verify-now ]; then
        ${notify "low" "Backup verified" "\"$restored files restored and checked\""}
      fi
      exit 0
    fi

    # read-only snapshots at a fixed path, so each backup compares with
    # the previous one instead of rereading everything
    sources=()
    cleanup() {
      for s in "''${sources[@]}"; do btrfs subvolume delete -c "$s" >/dev/null 2>&1 || true; done
    }
    trap cleanup EXIT
    for sub in ${lib.escapeShellArgs cfg.subvolumes}; do
      snap=$sub/.backup
      if [ -d "$snap" ]; then btrfs subvolume delete -c "$snap" >/dev/null; fi
      btrfs subvolume snapshot -r "$sub" "$snap" >/dev/null
      sources+=("$snap")
    done

    # locks left by a run that was killed (only dead ones go; a live run
    # would hold the flock above)
    restic unlock

    restic backup --host ${host} --tag ${host} --exclude-caches --skip-if-unchanged \
      ${
        lib.concatMapStringsSep " " (e: "--exclude ${lib.escapeShellArg "${backupHome}/${e}"}") cfg.exclude
      } \
      "''${sources[@]}"

    restic forget --retry-lock 10m --host ${host} --keep-daily 7 --keep-weekly 8 --keep-monthly 12
    # pruning rewrites data on the remote: once a week is plenty
    if [ ! -e ${cfg.cacheDir}/last-prune ] || [ $(( $(date +%s) - $(stat -c %Y ${cfg.cacheDir}/last-prune) )) -gt 604800 ]; then
      restic prune --retry-lock 10m --max-unused 10%
      touch ${cfg.cacheDir}/last-prune
    fi

    touch ${stamp}
    if [ "$mode" = now ]; then
      ${notify "low" "Backup done" "\"${host} is saved on ${cfg.remote}\""}
    fi
  '';

  # the user-facing command
  backupCmd = pkgs.writeShellApplication {
    name = "backup";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      libsecret
      restic
      systemd
    ];
    text = ''
      ${resticEnv ""}
      restic() { command restic ${rcloneProgram ""} "$@"; }
      store() { secret-tool store --label "$1" service dotnix-backup key "$2"; }

      case "''${1:-status}" in
        setup)
          export RCLONE_PASSWORD_COMMAND="${secret "rclone"}"
          if ! ${secret "rclone"} >/dev/null 2>&1; then
            head -c 32 /dev/urandom | base64 | tr -d '\n' | store "dotnix backup: rclone config key" rclone
          fi
          if ! ${rclone} listremotes | grep -qx '${cfg.remote}:'; then
            echo "Proton Drive login (stored encrypted in ~/.config/rclone; the key is in your keyring)"
            read -rp "Proton e-mail: " u
            read -rsp "Password: " p; echo
            read -rp "2FA code (empty if none): " code
            read -rsp "Mailbox password (empty unless two-password mode): " mp; echo
            args=(username "$u" password "$p")
            [ -n "$code" ] && args+=(2fa "$code")
            [ -n "$mp" ] && args+=(mailbox_password "$mp")
            ${rclone} config create ${cfg.remote} protondrive "''${args[@]}" >/dev/null
            unset p mp
          fi
          ${rclone} config encryption check 2>/dev/null || ${rclone} config encryption set
          if ! ${secret "restic"} >/dev/null 2>&1; then
            pw=$(head -c 32 /dev/urandom | base64 | tr -d '\n')
            printf '%s' "$pw" | store "dotnix backup: restic repository (${host})" restic
            restic init
            echo
            echo "Repository password (keep it outside this computer, e.g. in Proton Pass:"
            echo "without it the backup cannot be read if this disk dies):"
            echo "  $pw"
          fi
          echo "Ready. First backup: backup now"
          ;;
        now)
          systemctl start --no-block backup@now.service
          echo "backup running (backup status)"
          ;;
        verify)
          systemctl start --no-block backup@verify-now.service
          echo "restore test running (backup status)"
          ;;
        status)
          running=$(systemctl list-units --no-legend --plain --state=activating,active 'backup@*' 'backup-*' 2>/dev/null | awk '$1 ~ /service$/ { print $1 }')
          for unit in $running; do
            echo "running now: $unit, since $(systemctl show -p ActiveEnterTimestamp --value "$unit")"
          done
          [ -n "$running" ] || echo "not running"
          if [ -e ${stamp} ]; then echo "last backup: $(date -r ${stamp} '+%F %R')"; else echo "no backup yet"; fi
          if [ -e ${verifyResult} ]; then echo "last restore test: $(cat ${verifyResult})"; else echo "no restore test yet"; fi
          ;;
        log) journalctl -u 'backup@*' -n 100 --no-pager ;;
        snapshots) restic snapshots --host ${host} ;;
        # browse every backup as folders (Ctrl+C to unmount)
        mount)
          dir=''${2:-$HOME/backup}
          mkdir -p "$dir"
          echo "backups under $dir/snapshots (Ctrl+C to unmount)"
          restic mount "$dir"
          ;;
        # a new Proton session, when the old one expired (2FA asked again)
        login)
          read -rp "2FA code: " code
          RCLONE_PASSWORD_COMMAND="${secret "rclone"}" ${rclone} config update ${cfg.remote} 2fa "$code" >/dev/null
          ${rclone} about ${cfg.remote}: >/dev/null && echo "logged in"
          ;;
        password) ${secret "restic"}; echo ;;
        restic) shift; restic "$@" ;;
        *)
          echo "usage: backup [setup | login | now | verify | status | log | snapshots | mount [DIR] | password | restic ARGS...]"
          exit 1
          ;;
      esac
    '';
  };
in
{
  options.dotnix.storage.backup = with types; {
    enable = mkOption {
      type = bool;
      default = false;
      description = "Daily restic backup of /home and /persist to an rclone remote.";
    };
    remote = mkOption {
      type = str;
      default = "proton";
      description = "rclone remote name (created by `backup setup`).";
    };
    path = mkOption {
      type = str;
      default = "dotnix-backup";
      description = "Folder on the remote; each host gets a repository inside it.";
    };
    subvolumes = mkOption {
      type = listOf str;
      default = [
        "/home"
        "/persist"
      ];
      description = "btrfs subvolumes to back up (from a read-only snapshot).";
    };
    exclude = mkOption {
      type = listOf str;
      default = [ ];
      description = "Paths (restic patterns) relative to the user's home left out of the backup.";
    };
    cacheDir = mkOption {
      type = str;
      default = "/var/cache/backup";
      description = "restic cache and timestamps; must survive reboots and stay out of the snapshots.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      backupCmd
      pkgs.restic
      pkgs.rclone
    ];

    systemd.services."backup@" = {
      description = "Backup to ${cfg.remote} (%i)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      onFailure = [ "backup-failed.service" ];
      # a switch (`rebuild`) lets a running backup finish with the script
      # it started with; the next run takes the new one
      restartIfChanged = false;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${run} %i";
        Nice = 15;
        IOSchedulingClass = "idle";
      };
    };

    systemd.services.backup-failed = {
      description = "Tell the user a backup failed";
      serviceConfig.Type = "oneshot";
      script = notify "critical" "Backup failed" "\"see: backup log\"";
    };

    # hourly try; it runs once a day, as soon as the user is in and online
    systemd.timers.backup = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "15min";
        OnUnitActiveSec = "1h";
        Unit = "backup@auto.service";
      };
    };

    # the restore test: tried hourly, run once a month
    systemd.timers.backup-verify = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "45min";
        OnUnitActiveSec = "1h";
        Unit = "backup@verify.service";
      };
    };

    # readable: `backup status` (the user) reads the timestamps; the restic
    # cache inside stays root's
    systemd.tmpfiles.rules = [
      "d ${cfg.cacheDir} 0755 root root -"
      "d ${cfg.cacheDir}/restic 0700 root root -"
    ];

    # `backup now` without sudo
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            (action.lookup("unit") == "backup@now.service" ||
             action.lookup("unit") == "backup@verify-now.service") &&
            action.lookup("verb") == "start" && subject.user == "${user}") {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
