# The disks' own health (SMART) and a monthly btrfs scrub, which rereads
# everything and checks it against its checksums: what goes bad shows up
# before the backups carry it. disk-health writes both to a file the Activity
# dashboard reads (aw-watcher-system's health) and fails, so it shows among
# the failed units, when a disk reports trouble or the scrub found errors
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.storage.health;
  status = "/var/lib/disk-health/status.json";
  check = pkgs.writers.writePython3 "disk-health" { flakeIgnore = [ "E501" ]; } ''
    import json
    import os
    import re
    import subprocess
    import sys
    import time
    from pathlib import Path


    def sh(*cmd):
        return subprocess.run(cmd, capture_output=True, text=True).stdout


    def internal(dev):
        # the USB sticks (the key's) aren't watched: most don't speak SMART
        return "/usb" not in os.path.realpath(f"/sys/block/{dev}")


    disks = []
    for dev in sorted(os.listdir("/sys/block")):
        if not re.fullmatch(r"nvme\d+n\d+|sd[a-z]+", dev) or not internal(dev):
            continue
        out = json.loads(sh("${pkgs.smartmontools}/bin/smartctl", "-j", "-H", "-A", "-i", f"/dev/{dev}") or "{}")
        nvme = out.get("nvme_smart_health_information_log", {})
        disks.append({
            "name": dev,
            "model": out.get("model_name"),
            "passed": out.get("smart_status", {}).get("passed"),
            "temperature_c": out.get("temperature", {}).get("current"),
            "used_percent": nvme.get("percentage_used"),
            "media_errors": nvme.get("media_errors"),
            "power_on_hours": out.get("power_on_time", {}).get("hours"),
        })

    scrubs = []
    for fs in ${builtins.toJSON cfg.scrub}:
        out = sh("${pkgs.btrfs-progs}/bin/btrfs", "scrub", "status", "-R", fs)
        fields = dict(re.findall(r"^\s*(\w[\w ]*?):\s*(\S.*?)\s*$", out, re.M))
        started = fields.get("Scrub started")
        scrubs.append({
            "path": fs,
            "started": time.mktime(time.strptime(started, "%a %b %d %H:%M:%S %Y")) if started else None,
            "status": fields.get("Status"),
            "errors": sum(int(fields.get(k, "0")) for k in
                          ("read_errors", "csum_errors", "verify_errors", "super_errors", "uncorrectable_errors")),
        })

    Path("${status}").write_text(json.dumps({"time": time.time(), "disks": disks, "scrubs": scrubs}))
    bad = [d["name"] for d in disks if d["passed"] is False or d["media_errors"]] + \
          [s["path"] for s in scrubs if s["errors"]]
    if bad:
        print("trouble on: " + ", ".join(bad), file=sys.stderr)
        sys.exit(1)
  '';
in
{
  options.dotnix.storage.health = {
    enable = lib.mkEnableOption "disk health (SMART) and btrfs scrub, on the Activity dashboard";
    scrub = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "/" ];
      description = "btrfs filesystems (any path on each) scrubbed monthly; a scrub covers all its subvolumes.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.smartmontools ];

    services.btrfs.autoScrub = {
      enable = true;
      interval = "monthly";
      fileSystems = cfg.scrub;
    };
    # where btrfs keeps the last scrub's result
    environment.persistence = lib.mkIf config.dotnix.storage.impermanence.enable {
      "/persist".directories = [ "/var/lib/btrfs" ];
    };

    systemd.services.disk-health = {
      description = "Check the disks' SMART health and the last btrfs scrub";
      serviceConfig = {
        Type = "oneshot";
        StateDirectory = "disk-health";
        StateDirectoryMode = "0755";
        ExecStart = check;
      };
    };
    systemd.timers.disk-health = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "1h";
      };
    };
  };
}
