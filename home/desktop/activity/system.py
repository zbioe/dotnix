"""aw-watcher-system: the machine's load and state into ActivityWatch.

Every INTERVAL seconds one event in aw-watcher-system-metrics_HOST (CPU, memory,
GPU, temperatures, disks, network and the processes eating them), a heartbeat
in aw-watcher-system-state_HOST that merges while nothing changes (generation,
VPN, Wi-Fi, Bluetooth, audio output, theme, power), and every HEALTH_INTERVAL
one event in aw-watcher-health_HOST: how the setup itself is doing (failed
units, backup and its verification, updates, firmware, generations, store,
snapshots, journal errors).
"""

import json
import os
import socket
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import psutil

API = os.environ.get("AW_API", "http://127.0.0.1:5600/api/0")
HOST = socket.gethostname()
INTERVAL = int(os.environ.get("AW_SYSTEM_INTERVAL", "60"))
STATE_INTERVAL = 30
HEALTH_INTERVAL = 15 * 60
BACKUP_DIR = Path(os.environ.get("AW_BACKUP_DIR", "/var/cache/backup"))
UPDATES_DIR = Path.home() / ".local/state/flake-updates"
METRICS = f"aw-watcher-system-metrics_{HOST}"
STATE = f"aw-watcher-system-state_{HOST}"
HEALTH = f"aw-watcher-health_{HOST}"
TOP = 10


def post(path, body):
    req = urllib.request.Request(
        API + path,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        urllib.request.urlopen(req, timeout=5).read()
    except Exception as e:
        print(f"post {path}: {e}", file=sys.stderr)


def bucket(name, kind):
    post(
        f"/buckets/{name}",
        {"client": "aw-watcher-system", "type": kind, "hostname": HOST},
    )


def now():
    return datetime.now(timezone.utc).isoformat()


def run(*cmd):
    try:
        return subprocess.run(
            cmd, capture_output=True, text=True, timeout=5
        ).stdout.strip()
    except Exception:
        return ""


def read(path):
    try:
        return Path(path).read_text().strip()
    except Exception:
        return None


def gpu():
    out = {}
    for card in sorted(Path("/sys/class/drm").glob("card[0-9]")):
        dev = card / "device"
        busy = read(dev / "gpu_busy_percent")
        if busy is None:
            continue
        out = {"busy": float(busy)}
        used, total = (
            read(dev / "mem_info_vram_used"),
            read(dev / "mem_info_vram_total"),
        )
        if used and total:
            out["vram_used"] = int(used)
            out["vram_percent"] = round(100 * int(used) / int(total), 1)
        break
    return out


def temps():
    out = {}
    for chip, entries in (psutil.sensors_temperatures() or {}).items():
        for e in entries:
            key = f"{chip}.{e.label or 'temp'}".replace(" ", "_")
            out[key] = round(e.current, 1)
    return out


def processes(cpus):
    procs, groups = [], {}
    states = {}
    threads = 0
    for p in psutil.process_iter(
        ["pid", "name", "username", "memory_info", "status", "num_threads", "cmdline"]
    ):
        try:
            cpu = p.cpu_percent(None) / cpus
        except psutil.Error:
            continue
        info = p.info
        rss = info["memory_info"].rss if info["memory_info"] else 0
        states[info["status"]] = states.get(info["status"], 0) + 1
        threads += info["num_threads"] or 0
        name = info["name"] or "?"
        cmd = " ".join(info["cmdline"] or [])[:160]
        procs.append(
            {
                "pid": info["pid"],
                "name": name,
                "user": info["username"],
                "cpu": round(cpu, 2),
                "rss": rss,
                "cmd": cmd,
            }
        )
        g = groups.setdefault(name, {"name": name, "cpu": 0.0, "rss": 0, "count": 0})
        g["cpu"] += cpu
        g["rss"] += rss
        g["count"] += 1
    for g in groups.values():
        g["cpu"] = round(g["cpu"], 2)

    def by(xs, k):
        return sorted(xs, key=lambda x: x[k], reverse=True)[:TOP]

    return {
        "count": len(procs),
        "threads": threads,
        "states": states,
        "top_cpu": by(procs, "cpu"),
        "top_mem": by(procs, "rss"),
        "apps_cpu": by(list(groups.values()), "cpu"),
        "apps_mem": by(list(groups.values()), "rss"),
    }


class Rates:
    def __init__(self):
        self.t = time.monotonic()
        self.disk = psutil.disk_io_counters()
        self.net = self._net()

    @staticmethod
    def _net():
        c = psutil.net_io_counters(pernic=True)
        return {k: v for k, v in c.items() if k != "lo"}

    def sample(self):
        t, disk, net = time.monotonic(), psutil.disk_io_counters(), self._net()
        dt = max(t - self.t, 1e-3)
        out = {}
        if disk and self.disk:
            out["disk_read"] = round((disk.read_bytes - self.disk.read_bytes) / dt)
            out["disk_write"] = round((disk.write_bytes - self.disk.write_bytes) / dt)
        rx = sum(
            v.bytes_recv - self.net[k].bytes_recv
            for k, v in net.items()
            if k in self.net
        )
        tx = sum(
            v.bytes_sent - self.net[k].bytes_sent
            for k, v in net.items()
            if k in self.net
        )
        out["net_rx"], out["net_tx"] = round(rx / dt), round(tx / dt)
        self.t, self.disk, self.net = t, disk, net
        return out


def metrics(rates, cpus):
    vm, sw = psutil.virtual_memory(), psutil.swap_memory()
    freq = psutil.cpu_freq()
    data = {
        "cpu": psutil.cpu_percent(None),
        "cpu_max_core": max(psutil.cpu_percent(None, percpu=True) or [0]),
        "cpu_freq": round(freq.current) if freq else None,
        "load1": os.getloadavg()[0],
        "mem_percent": vm.percent,
        "mem_used": vm.total - vm.available,
        "mem_total": vm.total,
        "swap_used": sw.used,
        "disk_root": psutil.disk_usage("/").percent,
        "disk_home": psutil.disk_usage(str(Path.home())).percent,
        "gpu": gpu(),
        "temps": temps(),
        "procs": processes(cpus),
    }
    data.update(rates.sample())
    bat = psutil.sensors_battery()
    if bat:
        data["battery"] = round(bat.percent, 1)
    return data


def state():
    sink = run("wpctl", "inspect", "@DEFAULT_AUDIO_SINK@")
    sink = next(
        (
            x.split("=", 1)[1].strip().strip('"')
            for x in sink.splitlines()
            if "node.description" in x
        ),
        None,
    )
    ssid = next(
        (
            x.split(":", 1)[1]
            for x in run("nmcli", "-t", "-f", "active,ssid", "dev", "wifi").splitlines()
            if x.startswith("yes:")
        ),
        None,
    )
    bt = []
    for line in run("bluetoothctl", "devices", "Connected").splitlines():
        parts = line.split(" ", 2)
        if len(parts) == 3:
            bt.append(parts[2])
    vpn = sorted(
        i
        for i in psutil.net_if_stats()
        if i.startswith(("wg", "tun", "proton", "CloudflareWARP"))
        and psutil.net_if_stats()[i].isup
    )
    theme = Path.home() / ".local/state/theme"
    bat = psutil.sensors_battery()
    return {
        "generation": os.path.basename(os.readlink("/nix/var/nix/profiles/system"))
        if os.path.islink("/nix/var/nix/profiles/system")
        else None,
        "kernel": os.uname().release,
        "boot_id": read("/proc/sys/kernel/random/boot_id"),
        "vpn": ",".join(vpn) or "off",
        "wifi": ssid or "off",
        "bluetooth": ",".join(sorted(bt)) or "none",
        "audio_out": sink,
        "theme": f"{read(theme / 'name')} {read(theme / 'mode')}",
        "power": ("ac" if bat.power_plugged else "battery") if bat else "ac",
    }


def age_hours(path):
    try:
        return round((time.time() - path.stat().st_mtime) / 3600, 1)
    except OSError:
        return None


def lines(*cmd):
    return [x for x in run(*cmd).splitlines() if x.strip()]


def health():
    profiles = os.listdir("/nix/var/nix/profiles")
    homes = Path.home() / ".local/state/nix/profiles"
    verify = read(BACKUP_DIR / "last-verify-result")
    fw = run("fwupdmgr", "get-updates", "--json", "--no-unreported-check")
    try:
        firmware = len(json.loads(fw).get("Devices", [])) if fw else None
    except ValueError:
        firmware = None
    nix = psutil.disk_usage("/nix")
    return {
        "failed_system": [
            x.split()[0]
            for x in lines("systemctl", "--failed", "--no-legend", "--plain")
        ],
        "failed_user": [
            x.split()[0]
            for x in lines("systemctl", "--user", "--failed", "--no-legend", "--plain")
        ],
        "backup_age_h": age_hours(BACKUP_DIR / "last-success"),
        "prune_age_h": age_hours(BACKUP_DIR / "last-prune"),
        "verify": verify.split()[0] if verify else None,
        "verify_age_h": age_hours(BACKUP_DIR / "last-verify"),
        "updates": read(UPDATES_DIR / "result"),
        "updates_check_age_h": age_hours(UPDATES_DIR / "last-check"),
        "firmware_updates": firmware,
        "system_generations": sum(
            1 for p in profiles if p.startswith("system-") and p.endswith("-link")
        ),
        "home_generations": sum(1 for p in os.listdir(homes) if p.endswith("-link"))
        if homes.is_dir()
        else None,
        "store_paths": len(os.listdir("/nix/store")),
        "nix_disk_percent": nix.percent,
        "nix_disk_free": nix.free,
        "snapshots_home": max(
            len(lines("snapper", "-c", "home", "list", "--columns", "number")) - 2, 0
        ),
        "journal_errors_boot": len(
            lines("journalctl", "-b", "-p", "err", "-q", "-o", "cat", "--no-pager")
        ),
        "uptime_h": round((time.time() - psutil.boot_time()) / 3600, 1),
    }


def main():
    bucket(METRICS, "os.metrics")
    bucket(STATE, "os.state")
    bucket(HEALTH, "os.health")
    cpus = psutil.cpu_count() or 1
    rates = Rates()
    psutil.cpu_percent(None)
    processes(cpus)  # primes the per-process CPU counters
    start, t0 = now(), time.time()
    next_health = 0.0
    while True:
        if time.time() >= next_health:
            post(
                f"/buckets/{HEALTH}/events",
                [{"timestamp": now(), "duration": HEALTH_INTERVAL, "data": health()}],
            )
            next_health = time.time() + HEALTH_INTERVAL
        post(
            f"/buckets/{STATE}/heartbeat?pulsetime={STATE_INTERVAL * 3}",
            {"timestamp": now(), "duration": 0, "data": state()},
        )
        if time.time() - t0 >= INTERVAL:
            data = metrics(rates, cpus)
            post(
                f"/buckets/{METRICS}/events",
                [{"timestamp": start, "duration": time.time() - t0, "data": data}],
            )
            start, t0 = now(), time.time()
        time.sleep(STATE_INTERVAL)


if __name__ == "__main__":
    main()
