# Native messaging host for the nix-theme extension: sends
# ~/.local/state/theme/current/browser.json and font.json now and whenever
# `theme` swaps the `current` link or rewrites font.json.
import json
import os
import struct
import subprocess
import sys
import threading

STATE = os.path.join(
    os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
    "theme",
)


def send(path):
    try:
        with open(os.path.join(STATE, path), "rb") as f:
            data = json.dumps(json.load(f)).encode()
    except (OSError, ValueError):
        return
    sys.stdout.buffer.write(struct.pack("@I", len(data)) + data)
    sys.stdout.buffer.flush()


def exit_with_browser():
    # stdin closes when the extension disconnects
    while sys.stdin.buffer.read(4096):
        pass
    os._exit(0)


threading.Thread(target=exit_with_browser, daemon=True).start()
os.makedirs(STATE, exist_ok=True)
send("current/browser.json")
send("font.json")

watch = subprocess.Popen(
    ["@inotifywait@", "-m", "-q", "-e", "moved_to,create",
     "--format", "%f", STATE],
    stdout=subprocess.PIPE,
    text=True,
)
for name in watch.stdout:
    if name.strip() == "current":
        send("current/browser.json")
    elif name.strip() == "font.json":
        send("font.json")
