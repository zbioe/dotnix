"""aw-watcher-media: what every MPRIS player is playing, into ActivityWatch.

A heartbeat per playing player every POLL seconds in aw-watcher-media_HOST;
paused or stopped players send nothing, so a gap means nothing played.
"""

import json
import os
import socket
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timezone

API = os.environ.get("AW_API", "http://127.0.0.1:5600/api/0")
HOST = socket.gethostname()
BUCKET = f"aw-watcher-media_{HOST}"
POLL = 5
FIELDS = ["player", "status", "artist", "title", "album", "url", "length"]
FORMAT = "\x1f".join(
    [
        "{{playerName}}",
        "{{status}}",
        "{{artist}}",
        "{{title}}",
        "{{album}}",
        "{{xesam:url}}",
        "{{mpris:length}}",
    ]
)


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


def playing():
    try:
        out = subprocess.run(
            ["playerctl", "-a", "metadata", "--format", FORMAT],
            capture_output=True,
            text=True,
            timeout=5,
        ).stdout
    except Exception:
        return []
    players = []
    for line in out.splitlines():
        p = dict(zip(FIELDS, line.split("\x1f")))
        if p.get("status") != "Playing":
            continue
        length = p.pop("length", "")
        p["length"] = round(int(length) / 1e6) if length.isdigit() else None
        players.append(p)
    return players


def main():
    post(
        f"/buckets/{BUCKET}",
        {"client": "aw-watcher-media", "type": "media.playing", "hostname": HOST},
    )
    while True:
        stamp = datetime.now(timezone.utc).isoformat()
        for p in playing():
            post(
                f"/buckets/{BUCKET}/heartbeat?pulsetime={POLL * 3}",
                {"timestamp": stamp, "duration": 0, "data": p},
            )
        time.sleep(POLL)


if __name__ == "__main__":
    main()
