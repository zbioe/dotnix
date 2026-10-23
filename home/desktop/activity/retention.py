"""aw-retention: keeps ActivityWatch's database from growing for good.

Machine samples (metrics every minute, health every 15) older than KEEP_DAYS
are thinned to one per hour; everything else (windows, tabs, Emacs, commands)
stays whole. Then the file is compacted. Runs with aw-server stopped.
"""

import os
import sqlite3
import time

DB = os.environ["AW_DB"]
KEEP_DAYS = int(os.environ.get("AW_KEEP_DAYS", "90"))
THINNED = ("aw-watcher-system-metrics_%", "aw-watcher-health_%")
HOUR = 3600 * 10**9


def main():
    cutoff = int((time.time() - KEEP_DAYS * 86400) * 1e9)
    db = sqlite3.connect(DB)
    before = os.path.getsize(DB)
    removed = 0
    for pattern in THINNED:
        rows = db.execute(
            "SELECT id FROM buckets WHERE name LIKE ?", (pattern,)
        ).fetchall()
        for (bucket,) in rows:
            cur = db.execute(
                """
                DELETE FROM events
                WHERE bucketrow = :b AND starttime < :cutoff AND id NOT IN (
                  SELECT min(id) FROM events
                  WHERE bucketrow = :b AND starttime < :cutoff
                  GROUP BY starttime / :hour
                )
                """,
                {"b": bucket, "cutoff": cutoff, "hour": HOUR},
            )
            removed += cur.rowcount
    db.commit()
    db.execute("VACUUM")
    db.close()
    print(
        f"removed {removed} samples, {before >> 20} MiB -> {os.path.getsize(DB) >> 20} MiB"
    )


if __name__ == "__main__":
    main()
