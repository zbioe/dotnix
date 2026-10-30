# type-clipboard: types the clipboard at your own rhythm, with a Cancel button.
#   type-clipboard            type it (Super+M V)
#   type-clipboard cancel     stop it (Super+Esc)
#   type-clipboard calibrate  learn your rhythm: type a few lines in a terminal
# Intervals are drawn from the kernel's random source (getrandom, the same pool
# as /dev/random, fed by input events among others) around your measured
# rhythm: cadenced, never the same twice.
import json
import math
import os
import random
import signal
import subprocess
import sys
import termios
import time
import tty

STATE = os.path.join(os.environ["XDG_RUNTIME_DIR"], "type-clipboard.pid")
RHYTHM = os.path.join(
    os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
    "type-clipboard",
    "rhythm.json",
)
# until calibrated: a steady typist, ~85 words a minute
DEFAULT = {"median": 0.120, "sigma": 0.35, "word": 1.6, "sentence": 3.0, "pause": 0.02}
rng = random.SystemRandom()
KEYS = {"\n": "Return", "\t": "Tab", "-": "minus"}


def rhythm():
    try:
        with open(RHYTHM) as f:
            return {**DEFAULT, **json.load(f)}
    except FileNotFoundError:
        return DEFAULT


def interval(r, prev):
    # log-normal around the median: most keys close to it, a few slower
    d = r["median"] * math.exp(rng.gauss(0, r["sigma"]))
    if prev == " ":
        d *= r["word"]
    elif prev in ".!?\n":
        d *= r["sentence"]
    if rng.random() < r["pause"]:
        d += rng.uniform(0.4, 1.2)
    return d


def wtype_args(text, r):
    args, prev = [], ""
    for c in text:
        if prev:
            args += ["-s", str(round(interval(r, prev) * 1000))]
        args += ["-k", KEYS[c]] if c in KEYS else [c]
        prev = c
    return args


def notify(*args):
    return subprocess.run(["notify-send", "-a", "Type clipboard", *args], capture_output=True, text=True)


def type_clipboard():
    text = subprocess.run(["wl-paste", "--no-newline"], capture_output=True, text=True).stdout
    if not text:
        notify("-t", "1500", "The clipboard is empty")
        return
    typer = subprocess.Popen(["wtype", *wtype_args(text, rhythm())])
    with open(STATE, "w") as f:
        f.write(str(typer.pid))
    # the button: notify-send prints the id, then the action once clicked
    ask = subprocess.Popen(
        ["notify-send", "-a", "Type clipboard", "-p", "-A", "cancel=Cancel", "Typing the clipboard", f"{len(text)} characters"],
        stdout=subprocess.PIPE,
        text=True,
    )
    note = ask.stdout.readline().strip()
    os.set_blocking(ask.stdout.fileno(), False)
    while typer.poll() is None:
        try:
            typer.wait(0.2)
        except subprocess.TimeoutExpired:
            if (ask.stdout.readline() or "").strip() == "cancel":
                typer.terminate()
    ask.terminate()
    os.unlink(STATE)
    notify("-r", note, "-t", "1500", "Typed" if typer.returncode == 0 else "Cancelled")


def cancel():
    try:
        with open(STATE) as f:
            os.kill(int(f.read()), signal.SIGTERM)
    except (FileNotFoundError, ProcessLookupError, ValueError):
        pass


def calibrate():
    print("Type normally, as many lines as you like; an empty line ends.\n")
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    gaps, words, sentences, line, last, prev = [], [], [], "", None, ""
    try:
        tty.setcbreak(fd)
        while True:
            c = sys.stdin.read(1)
            now = time.monotonic()
            if c == "\x7f":  # a fix: its timing isn't typing
                line, last = line[:-1], None
                sys.stdout.write("\b \b")
                sys.stdout.flush()
                continue
            if c == "\n" and not line:
                break
            sys.stdout.write(c)
            sys.stdout.flush()
            if last is not None:
                gap = now - last
                if gap < 2:  # longer: you stopped, not typed
                    (words if prev == " " else sentences if prev in ".!?\n" else gaps).append(gap)
            line = "" if c == "\n" else line + c
            last, prev = now, c
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)
    if len(gaps) < 40:
        sys.exit(f"only {len(gaps)} keys: type more (two or three lines)")
    logs = sorted(math.log(g) for g in gaps)
    mid = logs[len(logs) // 2]
    sigma = (sum((x - mid) ** 2 for x in logs) / len(logs)) ** 0.5
    median = math.exp(mid)

    def factor(xs, default):
        return sorted(xs)[len(xs) // 2] / median if len(xs) >= 3 else default

    r = {
        "median": round(median, 4),
        "sigma": round(sigma, 3),
        "word": round(factor(words, DEFAULT["word"]), 2),
        "sentence": round(factor(sentences, DEFAULT["sentence"]), 2),
        "pause": DEFAULT["pause"],
    }
    os.makedirs(os.path.dirname(RHYTHM), exist_ok=True)
    with open(RHYTHM, "w") as f:
        json.dump(r, f, indent=2)
    print(f"\n{60 / (median * 5):.0f} words a minute; saved to {RHYTHM}:\n{json.dumps(r)}")


{"cancel": cancel, "calibrate": calibrate}.get(sys.argv[1] if len(sys.argv) > 1 else "", type_clipboard)()
