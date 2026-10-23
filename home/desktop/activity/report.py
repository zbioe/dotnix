"""activity report: a day or a week of ActivityWatch in a few lines.

    activity report [today|yesterday|week] [--notify] [--save]

The queries come from sql.nix (the dashboard's, with :from and :to); the
database is opened read-only. --notify sends the summary as a notification,
--save writes it to ~/org/activity/.
"""

import json
import os
import sqlite3
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path

DB = os.environ["AW_DB"]
QUERIES = json.loads(Path(os.environ["AW_REPORT_QUERIES"]).read_text())
SAVE_DIR = Path.home() / "org" / "activity"


def span(period):
    today = datetime.now().replace(hour=0, minute=0, second=0, microsecond=0)
    if period == "yesterday":
        return today - timedelta(days=1), today, "yesterday"
    if period == "week":
        start = today - timedelta(days=today.weekday())
        return start, datetime.now(), f"week of {start:%d/%m}"
    return today, datetime.now(), "today"


def ns(t):
    return int(t.timestamp() * 1e9)


def query(db, name, start, end):
    return db.execute(QUERIES[name], {"from": ns(start), "to": ns(end)}).fetchall()


def scalar(db, name, start, end):
    rows = query(db, name, start, end)
    return (rows[0][0] if rows else None) or 0


def hm(seconds):
    m = int(seconds // 60)
    return f"{m // 60}h{m % 60:02d}" if m >= 60 else f"{m}min"


def top(rows, n=3):
    return ", ".join(f"{name} {hm(sec)}" for name, sec in rows[:n] if name) or "-"


def report(period):
    start, end, label = span(period)
    db = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    days = max((end - start).days, 1) if period == "week" else 1

    active = scalar(db, "active", start, end)
    # the same span on the 7 days (or 4 weeks) before, for comparison
    step, n = (timedelta(days=7), 4) if period == "week" else (timedelta(days=1), 7)
    back = [
        scalar(db, "active", start - step * i, end - step * i) for i in range(1, n + 1)
    ]
    usual = sum(back) / len(back) if back else 0
    cats = query(db, "categories", start, end)
    total = sum(sec for _, sec in cats) or 1
    commands, failed = query(db, "commands", start, end)[0]
    switches = scalar(db, "switches", start, end)

    lines = [
        f"At the keyboard: {hm(active)}"
        + (f" ({(active - usual) / usual:+.0%} vs usual)" if usual else ""),
        "Categories: "
        + ", ".join(f"{name} {sec / total:.0%}" for name, sec in cats[:5]),
        f"Apps: {top(query(db, 'apps', start, end))}",
        f"Sites: {top(query(db, 'sites', start, end))}",
        f"Projects: {top(query(db, 'projects', start, end))}",
        f"Longest focus: {hm(scalar(db, 'focus', start, end))}",
        f"Window switches: {switches} ({switches / max(active / 3600, 1e-9):.0f}/h)"
        if active
        else f"Window switches: {switches}",
        f"Commands: {commands or 0} ({failed or 0} failed)",
        f"Typed in Emacs: {scalar(db, 'typed', start, end)} characters",
        f"Played: {top(query(db, 'media', start, end), 2)}",
    ]
    if days > 1:
        lines.insert(1, f"Per day: {hm(active / days)}")
    return label, start, lines


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    period = args[0] if args else "today"
    label, start, lines = report(period)
    text = "\n".join(lines)
    print(f"Activity, {label}\n{text}")
    if "--notify" in sys.argv:
        subprocess.run(
            [
                "notify-send",
                "-a",
                "activity",
                "-i",
                "utilities-system-monitor",
                f"Activity, {label}",
                text,
            ]
        )
    if "--save" in sys.argv:
        SAVE_DIR.mkdir(parents=True, exist_ok=True)
        name = f"{start:%Y}-W{start:%V}" if period == "week" else f"{start:%Y-%m-%d}"
        body = "\n".join(f"- {line}" for line in lines)
        (SAVE_DIR / f"{name}.org").write_text(
            f"#+title: Activity, {label}\n#+date: [{start:%Y-%m-%d}]\n\n{body}\n"
        )


if __name__ == "__main__":
    main()
