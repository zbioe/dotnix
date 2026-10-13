# Installs the theme extension into a Brave profile as a persistent unpacked
# extension (what "Load unpacked" does), through the DevTools protocol over
# --remote-debugging-pipe, in a headless Brave that is closed right after.
# usage: install.py BRAVE USER_DATA_DIR PROFILE_DIRECTORY EXTENSION_DIR
import json
import os
import subprocess
import sys
import time

brave, root, profile, ext = sys.argv[1:5]
to_brave, from_us = os.pipe()  # browser reads fd 3
from_brave, to_us = os.pipe()  # browser writes fd 4


def fds():
    os.dup2(to_brave, 3)
    os.dup2(to_us, 4)


proc = subprocess.Popen(
    [
        brave,
        "--headless=new",
        f"--user-data-dir={root}",
        f"--profile-directory={profile}",
        "--no-first-run",
        "--remote-debugging-pipe",
        "--enable-unsafe-extension-debugging",
        "about:blank",
    ],
    preexec_fn=fds,
    pass_fds=(3, 4),
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)
os.close(to_brave)
os.close(to_us)
buf = b""


def call(n, method, params=None):
    global buf
    os.write(from_us, json.dumps({"id": n, "method": method, "params": params or {}}).encode() + b"\0")
    while True:
        while b"\0" not in buf:
            chunk = os.read(from_brave, 65536)
            if not chunk:
                sys.exit("brave-theme: Brave closed the debugging pipe")
            buf += chunk
        msg, buf = buf.split(b"\0", 1)
        reply = json.loads(msg)
        if reply.get("id") == n:
            return reply


try:
    reply = call(1, "Extensions.loadUnpacked", {"path": ext})
    if "error" in reply:
        sys.exit(f"brave-theme: {reply['error'].get('message')}")
    time.sleep(1)  # the theme pack is built and the prefs written
    call(2, "Browser.close")
    proc.wait(timeout=30)
finally:
    if proc.poll() is None:
        proc.kill()
