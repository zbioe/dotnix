# SQL over aw-server-rust's SQLite (events.data is the event's JSON, start and
# end in nanoseconds), shared by the dashboard and `activity report`. FROM and
# TO are SQL expressions for the range, in nanoseconds.
{
  lib,
  from,
  to,
}:
let
  categories = import ./categories.nix;

  quote = s: "'${lib.replaceStrings [ "'" ] [ "''" ] s}'";
  globs = col: ps: lib.concatMapStringsSep " OR " (p: "${col} GLOB ${quote p}") ps;
  # CASE over the rules' apps or domains: the category, or NULL
  classify =
    field: col:
    let
      rules = lib.filter (r: r.${field} != [ ]) categories.rules;
    in
    "(CASE ${
      lib.concatMapStringsSep " " (
        r: "WHEN ${globs "lower(${col})" r.${field}} THEN ${quote r.name}"
      ) rules
    } END)";
  isBrowser = col: "lower(${col}) IN (${lib.concatMapStringsSep ", " quote categories.browsers})";
in
rec {
  inherit from to;

  bucket = prefix: "(SELECT id FROM buckets WHERE name LIKE '${prefix}%')";

  # events of a bucket inside the range, cut at its edges: s, e and data
  inRange = prefix: ''
    SELECT max(starttime, ${from}) AS s, min(endtime, ${to}) AS e, data
    FROM events
    WHERE bucketrow = ${bucket prefix} AND endtime > ${from} AND starttime < ${to}
  '';

  # the stretches at the keyboard (awatcher's afk bucket says not-afk)
  active = ''
    active AS (
      SELECT s, e FROM (${inRange "aw-watcher-afk_"})
      WHERE json_extract(data, '$.status') = 'not-afk'
    )
  '';

  # seconds of KEY (an SQL expression over data) from a bucket, counting only
  # the time at the keyboard
  activeBy = prefix: key: limit: ''
    WITH ${active},
    ev AS (SELECT s, e, ${key} AS k FROM (${inRange prefix}))
    SELECT ev.k AS name, sum(min(ev.e, active.e) - max(ev.s, active.s)) / 1e9 AS seconds
    FROM ev JOIN active ON ev.s < active.e AND active.s < ev.e
    WHERE ev.k IS NOT NULL AND ev.k != '''
    GROUP BY ev.k ORDER BY seconds DESC LIMIT ${toString limit}
  '';

  # the host part of a URL
  domain = col: ''
    substr(substr(${col}, instr(${col}, '://') + 3), 1,
      instr(substr(${col}, instr(${col}, '://') + 3) || '/', '/') - 1)
  '';

  iso = col: "strftime('%Y-%m-%dT%H:%M:%SZ', ${col} / 1e9, 'unixepoch')";

  # every stretch at the keyboard with its category (s, e, app, category): the
  # focused window's app, or for a browser the domain of its tab
  categorized = ''
    ${active},
    win AS (SELECT s, e, json_extract(data, '$.app') AS app FROM (${inRange "aw-watcher-window_"})),
    seg AS (
      SELECT max(win.s, active.s) AS s, min(win.e, active.e) AS e, win.app
      FROM win JOIN active ON win.s < active.e AND active.s < win.e
    ),
    web AS (SELECT s, e, ${domain "json_extract(data, '$.url')"} AS dom FROM (${inRange "aw-watcher-web-"})),
    categorized AS (
      SELECT max(seg.s, web.s) AS s, min(seg.e, web.e) AS e, seg.app,
        coalesce(${classify "domains" "web.dom"}, 'Browsing') AS category
      FROM seg JOIN web ON seg.s < web.e AND web.s < seg.e
      WHERE ${isBrowser "seg.app"}
      UNION ALL
      SELECT s, e, app, 'Browsing' AS category FROM seg
      WHERE ${isBrowser "seg.app"}
        AND NOT EXISTS (SELECT 1 FROM web WHERE seg.s < web.e AND web.s < seg.e)
      UNION ALL
      SELECT s, e, app, coalesce(${classify "apps" "app"}, 'Other') AS category FROM seg
      WHERE NOT ${isBrowser "seg.app"}
    )
  '';

  # seconds per category
  byCategory = ''
    WITH ${categorized}
    SELECT category AS name, sum(e - s) / 1e9 AS seconds
    FROM categorized GROUP BY category ORDER BY seconds DESC
  '';
}
