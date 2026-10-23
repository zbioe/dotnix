# The Activity dashboard, through frser-sqlite-datasource (the SQL: sql.nix)
{ lib }:
let
  ds = {
    type = "frser-sqlite-datasource";
    uid = "activitywatch";
  };

  q = import ./sql.nix {
    inherit lib;
    # the dashboard's time range, in the events' nanoseconds
    from = "\${__from}000000";
    to = "\${__to}000000";
  };
  # FMT (strftime) of a nanosecond column in local time, as UTC ISO: a
  # day's or an hour's bar where it belongs
  local =
    fmt: col:
    "strftime('%Y-%m-%dT%H:%M:%SZ', strftime('${fmt}', ${col} / 1e9, 'unixepoch', 'localtime'), 'utc')";

  # one column per category (a long table the plugin can't turn into series)
  perCategory =
    lib.concatMapStringsSep ",\n  "
      (c: "sum(CASE WHEN category = '${c}' THEN e - s END) / 1e9 AS \"${c}\"")
      (
        (map (r: r.name) (import ./categories.nix).rules)
        ++ [
          "Browsing"
          "Other"
        ]
      );

  inherit (q)
    from
    to
    bucket
    inRange
    active
    activeBy
    domain
    iso
    categorized
    byCategory
    ;

  target = kind: sql: {
    refId = "A";
    datasource = ds;
    queryText = sql;
    rawQueryText = sql;
    queryType = kind;
    timeColumns = [ "time" ];
  };

  panel =
    {
      title,
      type,
      sql,
      x,
      y,
      w,
      h,
      kind ? "table",
      unit ? null,
      options ? { },
      custom ? { },
      description ? null,
    }:
    {
      inherit title type;
      datasource = ds;
      gridPos = {
        inherit
          x
          y
          w
          h
          ;
      };
      targets = [ (target kind sql) ];
      fieldConfig = {
        defaults = lib.optionalAttrs (unit != null) { inherit unit; } // {
          inherit custom;
        };
        overrides = [ ];
      };
      inherit options;
    }
    // lib.optionalAttrs (description != null) { inherit description; };

  # one value per row (name, seconds) as bars
  rows = {
    reduceOptions = {
      values = true;
      calcs = [ ];
      fields = "";
    };
    orientation = "horizontal";
    displayMode = "gradient";
    showUnfilled = true;
    valueMode = "color";
    namePlacement = "left";
    sizing = "auto";
  };

  donut = {
    inherit (rows) reduceOptions;
    pieType = "donut";
    legend = {
      displayMode = "table";
      placement = "right";
      values = [ "percent" ];
    };
  };

  stat = {
    reduceOptions = {
      values = false;
      calcs = [ "lastNotNull" ];
      fields = "";
    };
    colorMode = "value";
    graphMode = "none";
    textMode = "value";
  };

  bars = {
    drawStyle = "bars";
    fillOpacity = 70;
    lineWidth = 0;
  };

  lines = {
    drawStyle = "line";
    fillOpacity = 15;
    lineWidth = 1;
    spanNulls = true;
    showPoints = "never";
  };

  tooltip = {
    tooltip.mode = "multi";
    legend = {
      displayMode = "list";
      placement = "bottom";
    };
  };

  metric = path: "json_extract(data, '$.${path}')";

  # the metrics bucket's samples in range, with a time column
  samples = cols: ''
    SELECT ${iso "starttime"} AS time, ${cols}
    FROM events
    WHERE bucketrow = ${bucket "aw-watcher-system-metrics_"} AND endtime > ${from} AND starttime < ${to}
    ORDER BY starttime
  '';

  # the newest health sample, and a value of it (EXPR over its data)
  latestRow = "SELECT data FROM events WHERE bucketrow = ${bucket "aw-watcher-health_"} ORDER BY starttime DESC LIMIT 1";
  latest =
    expr:
    if lib.hasInfix "(" expr then
      "SELECT ${expr} AS value FROM (${latestRow})"
    else
      "SELECT json_extract(data, '$.${expr}') AS value FROM (${latestRow})";

  # the health samples in range, with a time column
  health = cols: ''
    SELECT ${iso "starttime"} AS time, ${cols}
    FROM events
    WHERE bucketrow = ${bucket "aw-watcher-health_"} AND endtime > ${from} AND starttime < ${to}
    ORDER BY starttime
  '';

  # a process list of the metrics samples (apps_cpu, apps_mem...), averaged
  processes = list: field: ''
    SELECT json_extract(p.value, '$.name') AS name,
      avg(json_extract(p.value, '$.${field}')) AS value,
      max(json_extract(p.value, '$.${field}')) AS peak
    FROM events, json_each(events.data, '$.procs.${list}') AS p
    WHERE bucketrow = ${bucket "aw-watcher-system-metrics_"} AND endtime > ${from} AND starttime < ${to}
    GROUP BY name ORDER BY value DESC LIMIT 15
  '';

  panels = [
    # the period at a glance
    (panel {
      title = "At the keyboard";
      type = "stat";
      unit = "s";
      options = stat;
      x = 0;
      y = 0;
      w = 5;
      h = 4;
      sql = "WITH ${active} SELECT coalesce(sum(e - s), 0) / 1e9 AS seconds FROM active";
    })
    (panel {
      title = "Away";
      type = "stat";
      unit = "s";
      options = stat;
      x = 5;
      y = 0;
      w = 5;
      h = 4;
      sql = ''
        SELECT coalesce(sum(e - s), 0) / 1e9 AS seconds FROM (${inRange "aw-watcher-afk_"})
        WHERE json_extract(data, '$.status') = 'afk'
      '';
    })
    (panel {
      title = "App switches";
      type = "stat";
      options = stat;
      x = 10;
      y = 0;
      w = 4;
      h = 4;
      sql = "SELECT count(*) AS switches FROM (${inRange "aw-watcher-window_"})";
    })
    (panel {
      title = "Commands run";
      type = "stat";
      options = stat;
      x = 14;
      y = 0;
      w = 5;
      h = 4;
      sql = "SELECT count(*) AS commands FROM (${inRange "aw-watcher-terminal_"})";
    })
    (panel {
      title = "Playing";
      type = "stat";
      unit = "s";
      options = stat;
      x = 19;
      y = 0;
      w = 5;
      h = 4;
      sql = "SELECT coalesce(sum(e - s), 0) / 1e9 AS seconds FROM (${inRange "aw-watcher-media_"})";
    })

    # what the time went to (categories.nix)
    (panel {
      title = "Categories";
      type = "bargauge";
      unit = "s";
      options = rows;
      x = 0;
      y = 4;
      w = 8;
      h = 9;
      sql = byCategory;
    })
    (panel {
      title = "Categories, day by day";
      type = "timeseries";
      kind = "time series";
      unit = "s";
      custom = bars // {
        stacking.mode = "normal";
      };
      options = tooltip;
      x = 8;
      y = 4;
      w = 16;
      h = 9;
      sql = ''
        WITH ${categorized}
        SELECT ${local "%Y-%m-%d 12:00:00" "s"} AS time,
          ${perCategory}
        FROM categorized GROUP BY 1 ORDER BY 1
      '';
    })
    (panel {
      title = "Category timeline";
      type = "state-timeline";
      options = {
        showValue = "never";
        mergeValues = true;
        rowHeight = 0.9;
        legend.showLegend = true;
      };
      x = 0;
      y = 13;
      w = 24;
      h = 5;
      sql = ''
        WITH ${categorized}
        SELECT time, category FROM (
          SELECT ${iso "s"} AS time, s, category FROM categorized
          UNION ALL
          SELECT ${iso "s"} AS time, s, 'away' FROM (${inRange "aw-watcher-afk_"})
          WHERE json_extract(data, '$.status') = 'afk'
        ) ORDER BY s
      '';
    })

    # where the time goes
    (panel {
      title = "Apps";
      type = "bargauge";
      unit = "s";
      options = rows;
      x = 0;
      y = 22;
      w = 12;
      h = 10;
      sql = activeBy "aw-watcher-window_" (metric "app") 15;
    })
    (panel {
      title = "Sites";
      type = "bargauge";
      unit = "s";
      options = rows;
      x = 12;
      y = 22;
      w = 12;
      h = 10;
      description = "Active tab of every browser, counting only the time at the keyboard";
      sql = activeBy "aw-watcher-web-" (domain (metric "url")) 15;
    })
    (panel {
      title = "Hour of the day";
      type = "barchart";
      unit = "s";
      options = {
        xField = "hour";
        showValue = "never";
        barWidth = 0.8;
      };
      x = 0;
      y = 32;
      w = 12;
      h = 8;
      sql = ''
        WITH ${active}
        SELECT strftime('%H', s / 1e9, 'unixepoch', 'localtime') AS hour, sum(e - s) / 1e9 AS seconds
        FROM active GROUP BY hour ORDER BY hour
      '';
    })
    (panel {
      title = "Every day";
      type = "timeseries";
      kind = "time series";
      unit = "s";
      custom = bars;
      options = tooltip;
      x = 12;
      y = 32;
      w = 12;
      h = 8;
      sql = ''
        WITH ${active}
        SELECT ${local "%Y-%m-%d 12:00:00" "s"} AS time, sum(e - s) / 1e9 AS active
        FROM active GROUP BY time ORDER BY time
      '';
    })

    # Emacs, the terminal and the projects across both
    (panel {
      title = "Emacs: projects";
      type = "bargauge";
      unit = "s";
      options = rows;
      x = 0;
      y = 40;
      w = 8;
      h = 9;
      sql = activeBy "aw-watcher-emacs_" (metric "project") 12;
    })
    (panel {
      title = "Emacs: languages and modes";
      type = "piechart";
      unit = "s";
      options = donut;
      x = 8;
      y = 40;
      w = 8;
      h = 9;
      sql = activeBy "aw-watcher-emacs_" (metric "language") 10;
    })
    (panel {
      title = "Emacs: files and functions";
      type = "table";
      unit = "s";
      x = 16;
      y = 40;
      w = 8;
      h = 9;
      sql =
        activeBy "aw-watcher-emacs_"
          "coalesce(${metric "file"}, ${metric "buffer"}) || coalesce(' › ' || ${metric "function"}, ' › ' || ${metric "heading"}, '')"
          50;
    })
    (panel {
      title = "Projects (Emacs + terminal)";
      type = "bargauge";
      unit = "s";
      options = rows;
      x = 0;
      y = 49;
      w = 12;
      h = 9;
      description = "Emacs time at the keyboard plus the time commands ran inside each git project";
      sql = ''
        SELECT name, sum(seconds) AS seconds FROM (
          SELECT * FROM (${activeBy "aw-watcher-emacs_" (metric "project") 1000})
          UNION ALL
          SELECT ${metric "project"} AS name, sum(e - s) / 1e9 AS seconds
          FROM (${inRange "aw-watcher-terminal_"}) GROUP BY name
        ) WHERE name IS NOT NULL GROUP BY name ORDER BY seconds DESC LIMIT 15
      '';
    })
    (panel {
      title = "Terminal: commands";
      type = "table";
      x = 12;
      y = 49;
      w = 12;
      h = 9;
      sql = ''
        SELECT ${metric "bin"} AS command, count(*) AS runs,
          sum(${metric "status"} != 0) AS failed,
          sum(e - s) / 1e9 AS seconds, max(e - s) / 1e9 AS longest
        FROM (${inRange "aw-watcher-terminal_"})
        GROUP BY command ORDER BY runs DESC LIMIT 50
      '';
    })

    # windows, pages and media in detail
    (panel {
      title = "Window titles";
      type = "table";
      unit = "s";
      x = 0;
      y = 58;
      w = 12;
      h = 10;
      sql = activeBy "aw-watcher-window_" "${metric "app"} || ' › ' || ${metric "title"}" 100;
    })
    (panel {
      title = "Pages";
      type = "table";
      unit = "s";
      x = 12;
      y = 58;
      w = 12;
      h = 10;
      sql = activeBy "aw-watcher-web-" "coalesce(${metric "title"}, '') || ' › ' || ${metric "url"}" 100;
    })
    (panel {
      title = "Played";
      type = "table";
      unit = "s";
      x = 0;
      y = 68;
      w = 12;
      h = 9;
      sql = ''
        SELECT ${metric "player"} AS player, ${metric "artist"} AS artist, ${metric "title"} AS title,
          sum(e - s) / 1e9 AS seconds
        FROM (${inRange "aw-watcher-media_"})
        GROUP BY player, artist, title ORDER BY seconds DESC LIMIT 100
      '';
    })
    (panel {
      title = "Players";
      type = "bargauge";
      unit = "s";
      options = rows;
      x = 12;
      y = 68;
      w = 12;
      h = 9;
      sql = ''
        SELECT ${metric "player"} AS name, sum(e - s) / 1e9 AS seconds
        FROM (${inRange "aw-watcher-media_"}) GROUP BY name ORDER BY seconds DESC
      '';
    })

    # the machine
    (panel {
      title = "CPU and GPU";
      type = "timeseries";
      kind = "time series";
      unit = "percent";
      custom = lines;
      options = tooltip;
      x = 0;
      y = 77;
      w = 12;
      h = 8;
      sql = samples ''
        ${metric "cpu"} AS cpu, ${metric "cpu_max_core"} AS "busiest core",
        ${metric "gpu.busy"} AS gpu, ${metric "gpu.vram_percent"} AS vram
      '';
    })
    (panel {
      title = "Memory";
      type = "timeseries";
      kind = "time series";
      unit = "bytes";
      custom = lines;
      options = tooltip;
      x = 12;
      y = 77;
      w = 12;
      h = 8;
      sql = samples ''
        ${metric "mem_used"} AS used, ${metric "swap_used"} AS swap, ${metric "gpu.vram_used"} AS vram
      '';
    })
    (panel {
      title = "Temperatures";
      type = "timeseries";
      kind = "time series";
      unit = "celsius";
      custom = lines;
      options = tooltip;
      x = 0;
      y = 85;
      w = 12;
      h = 8;
      sql = samples ''
        json_extract(data, '$.temps."k10temp.Tctl"') AS cpu,
        json_extract(data, '$.temps."amdgpu.edge"') AS gpu,
        json_extract(data, '$.temps."nvme.Composite"') AS nvme,
        json_extract(data, '$.temps."mt7921_phy0.temp"') AS "wifi/bt"
      '';
    })
    (panel {
      title = "Disk and network";
      type = "timeseries";
      kind = "time series";
      unit = "Bps";
      custom = lines;
      options = tooltip;
      x = 12;
      y = 85;
      w = 12;
      h = 8;
      sql = samples ''
        ${metric "disk_read"} AS "disk read", ${metric "disk_write"} AS "disk write",
        ${metric "net_rx"} AS download, ${metric "net_tx"} AS upload
      '';
    })
    (panel {
      title = "Load and processes";
      type = "timeseries";
      kind = "time series";
      custom = lines;
      options = tooltip;
      x = 0;
      y = 93;
      w = 12;
      h = 8;
      sql = samples ''
        ${metric "load1"} AS load, ${metric "procs.count"} AS processes
      '';
    })
    (panel {
      title = "Battery";
      type = "timeseries";
      kind = "time series";
      unit = "percent";
      custom = lines;
      options = tooltip;
      x = 12;
      y = 93;
      w = 12;
      h = 8;
      sql = samples "${metric "battery"} AS battery";
    })
    (panel {
      title = "Programs by CPU (average of a core)";
      type = "table";
      unit = "percent";
      x = 0;
      y = 101;
      w = 12;
      h = 10;
      description = "Every process with the same name summed, foreground or background";
      sql = processes "apps_cpu" "cpu";
    })
    (panel {
      title = "Programs by memory";
      type = "table";
      unit = "bytes";
      x = 12;
      y = 101;
      w = 12;
      h = 10;
      sql = processes "apps_mem" "rss";
    })
    (panel {
      title = "System state";
      type = "state-timeline";
      options = {
        showValue = "auto";
        mergeValues = true;
        rowHeight = 0.8;
        legend.showLegend = false;
      };
      x = 0;
      y = 111;
      w = 24;
      h = 9;
      sql = ''
        SELECT ${iso "starttime"} AS time, ${metric "vpn"} AS vpn, ${metric "wifi"} AS wifi,
          ${metric "bluetooth"} AS bluetooth, ${metric "audio_out"} AS "audio out",
          ${metric "theme"} AS theme, ${metric "generation"} AS generation, ${metric "power"} AS power
        FROM events
        WHERE bucketrow = ${bucket "aw-watcher-system-state_"} AND endtime > ${from} AND starttime < ${to}
        ORDER BY starttime
      '';
    })

    # how the time went, in order
    (panel {
      title = "App timeline";
      type = "state-timeline";
      options = {
        showValue = "never";
        mergeValues = true;
        rowHeight = 0.9;
        legend.showLegend = false;
      };
      x = 0;
      y = 120;
      w = 24;
      h = 5;
      sql = ''
        SELECT ${iso "s"} AS time, ${metric "app"} AS app FROM (${inRange "aw-watcher-window_"})
        UNION ALL
        SELECT ${iso "s"} AS time, 'away' AS app FROM (${inRange "aw-watcher-afk_"})
        WHERE json_extract(data, '$.status') = 'afk'
        ORDER BY time
      '';
    })
    (panel {
      title = "Focus sessions";
      type = "table";
      unit = "s";
      x = 0;
      y = 125;
      w = 8;
      h = 10;
      description = "Stretches at the keyboard without going away, longest first, with what filled them";
      sql = ''
        WITH ${active},
        sessions AS (SELECT row_number() OVER (ORDER BY s) AS id, s, e FROM active),
        win AS (SELECT s, e, ${metric "app"} AS app FROM (${inRange "aw-watcher-window_"})),
        overlap AS (
          SELECT sessions.id, win.app, count(*) AS n,
            sum(min(win.e, sessions.e) - max(win.s, sessions.s)) AS t
          FROM sessions JOIN win ON win.s < sessions.e AND sessions.s < win.e
          GROUP BY sessions.id, win.app
        ),
        best AS (SELECT id, app, row_number() OVER (PARTITION BY id ORDER BY t DESC) AS r FROM overlap)
        SELECT strftime('%d/%m %H:%M', sessions.s / 1e9, 'unixepoch', 'localtime') AS started,
          (sessions.e - sessions.s) / 1e9 AS seconds, best.app AS mostly,
          (SELECT sum(n) FROM overlap WHERE overlap.id = sessions.id) AS windows
        FROM sessions LEFT JOIN best ON best.id = sessions.id AND best.r = 1
        ORDER BY seconds DESC LIMIT 30
      '';
    })
    (panel {
      title = "Switches per hour";
      type = "timeseries";
      kind = "time series";
      custom = bars;
      options = tooltip;
      x = 8;
      y = 125;
      w = 16;
      h = 10;
      description = "Window changes per hour: the higher, the more scattered";
      sql = ''
        SELECT ${local "%Y-%m-%d %H:30:00" "s"} AS time, count(*) AS switches
        FROM (${inRange "aw-watcher-window_"}) GROUP BY time ORDER BY time
      '';
    })

    # Emacs in depth
    (panel {
      title = "Emacs: typing and commands";
      type = "timeseries";
      kind = "time series";
      custom = bars;
      options = tooltip;
      x = 0;
      y = 135;
      w = 12;
      h = 8;
      sql = ''
        SELECT ${iso "starttime"} AS time, ${metric "chars"} AS typed, ${metric "commands"} AS commands
        FROM events
        WHERE bucketrow = ${bucket "aw-watcher-emacs-input_"} AND endtime > ${from} AND starttime < ${to}
        ORDER BY starttime
      '';
    })
    (panel {
      title = "Emacs: most used commands";
      type = "bargauge";
      options = rows;
      x = 12;
      y = 135;
      w = 12;
      h = 8;
      sql = ''
        SELECT json_extract(c.value, '$.command') AS name, sum(json_extract(c.value, '$.count')) AS runs
        FROM events, json_each(events.data, '$.top') AS c
        WHERE bucketrow = ${bucket "aw-watcher-emacs-input_"} AND endtime > ${from} AND starttime < ${to}
        GROUP BY name ORDER BY runs DESC LIMIT 20
      '';
    })
    (panel {
      title = "Emacs: modes";
      type = "bargauge";
      unit = "s";
      options = rows;
      x = 0;
      y = 143;
      w = 8;
      h = 9;
      description = "Major modes: code, magit, org, mail, vterm, dired...";
      sql = activeBy "aw-watcher-emacs_" (metric "mode") 15;
    })
    (panel {
      title = "Emacs: evil states";
      type = "piechart";
      unit = "s";
      options = donut;
      x = 8;
      y = 143;
      w = 8;
      h = 9;
      sql = activeBy "aw-watcher-emacs_" (metric "evil") 10;
    })
    (panel {
      title = "Emacs: branches and org";
      type = "table";
      unit = "s";
      x = 16;
      y = 143;
      w = 8;
      h = 9;
      sql = ''
        SELECT * FROM (${
          activeBy "aw-watcher-emacs_" "coalesce(${metric "project"}, '-') || ' @ ' || ${metric "branch"}" 15
        })
        UNION ALL
        SELECT * FROM (${
          activeBy "aw-watcher-emacs_" "'org › ' || coalesce(${metric "clock"}, ${metric "heading"})" 15
        })
        ORDER BY seconds DESC
      '';
    })

    # the terminal and the browser in depth
    (panel {
      title = "Terminal: failures";
      type = "table";
      x = 0;
      y = 152;
      w = 12;
      h = 9;
      sql = ''
        SELECT strftime('%d/%m %H:%M', s / 1e9, 'unixepoch', 'localtime') AS at,
          ${metric "status"} AS status, ${metric "cmd"} AS command, ${metric "dir"} AS dir
        FROM (${inRange "aw-watcher-terminal_"})
        WHERE ${metric "status"} != 0 ORDER BY s DESC LIMIT 100
      '';
    })
    (panel {
      title = "Terminal: slowest commands";
      type = "table";
      unit = "s";
      x = 12;
      y = 152;
      w = 12;
      h = 9;
      sql = ''
        SELECT strftime('%d/%m %H:%M', s / 1e9, 'unixepoch', 'localtime') AS at,
          (e - s) / 1e9 AS seconds, ${metric "cmd"} AS command, ${metric "project"} AS project
        FROM (${inRange "aw-watcher-terminal_"})
        ORDER BY seconds DESC LIMIT 50
      '';
    })
    (panel {
      title = "Browsers";
      type = "piechart";
      unit = "s";
      options = donut;
      x = 0;
      y = 161;
      w = 8;
      h = 8;
      sql = ''
        WITH ${active},
        ev AS (
          SELECT max(starttime, ${from}) AS s, min(endtime, ${to}) AS e,
            substr(b.name, 16, instr(b.name, '_') - 16) AS k
          FROM events JOIN buckets b ON b.id = events.bucketrow
          WHERE b.name LIKE 'aw-watcher-web-%' AND endtime > ${from} AND starttime < ${to}
        )
        SELECT ev.k AS name, sum(min(ev.e, active.e) - max(ev.s, active.s)) / 1e9 AS seconds
        FROM ev JOIN active ON ev.s < active.e AND active.s < ev.e
        GROUP BY name ORDER BY seconds DESC
      '';
    })
    (panel {
      title = "Tabs with sound";
      type = "bargauge";
      unit = "s";
      options = rows;
      x = 8;
      y = 161;
      w = 8;
      h = 8;
      sql = ''
        SELECT ${domain (metric "url")} AS name, sum(e - s) / 1e9 AS seconds
        FROM (${inRange "aw-watcher-web-"})
        WHERE ${metric "audible"} = 1 GROUP BY name ORDER BY seconds DESC LIMIT 15
      '';
    })
    (panel {
      title = "Open tabs";
      type = "timeseries";
      kind = "time series";
      custom = lines;
      options = tooltip;
      x = 16;
      y = 161;
      w = 8;
      h = 8;
      sql = ''
        SELECT ${iso "s"} AS time, max(${metric "tabCount"}) AS tabs
        FROM (${inRange "aw-watcher-web-"}) GROUP BY time ORDER BY time
      '';
    })

    # the setup itself (aw-watcher-system's health, every 15 minutes)
    (panel {
      title = "Last backup";
      type = "stat";
      unit = "s";
      description = "Time since the last successful backup";
      options = stat;
      x = 0;
      y = 169;
      w = 4;
      h = 4;
      sql = latest "json_extract(data, '$.backup_age_h') * 3600";
    })
    (panel {
      title = "Backup verified";
      type = "stat";
      unit = "s";
      description = "Time since the last restore test (backup verify)";
      options = stat;
      x = 4;
      y = 169;
      w = 4;
      h = 4;
      sql = latest "json_extract(data, '$.verify_age_h') * 3600";
    })
    (panel {
      title = "Verify result";
      type = "stat";
      options = stat;
      x = 8;
      y = 169;
      w = 3;
      h = 4;
      sql = latest "verify";
    })
    (panel {
      title = "Failed units";
      type = "stat";
      options = stat;
      x = 11;
      y = 169;
      w = 3;
      h = 4;
      sql = latest "json_array_length(data, '$.failed_system') + json_array_length(data, '$.failed_user')";
    })
    (panel {
      title = "Updates";
      type = "stat";
      options = stat;
      x = 14;
      y = 169;
      w = 3;
      h = 4;
      sql = latest "updates";
    })
    (panel {
      title = "Firmware updates";
      type = "stat";
      options = stat;
      x = 17;
      y = 169;
      w = 3;
      h = 4;
      sql = latest "firmware_updates";
    })
    (panel {
      title = "Errors in the journal";
      type = "stat";
      description = "Since this boot";
      options = stat;
      x = 20;
      y = 169;
      w = 4;
      h = 4;
      sql = latest "journal_errors_boot";
    })
    (panel {
      title = "Store, generations and snapshots";
      type = "timeseries";
      kind = "time series";
      custom = lines;
      options = tooltip;
      x = 0;
      y = 173;
      w = 12;
      h = 8;
      sql = health ''
        ${metric "store_paths"} AS "store paths", ${metric "system_generations"} AS "system generations",
        ${metric "home_generations"} AS "home generations", ${metric "snapshots_home"} AS snapshots
      '';
    })
    (panel {
      title = "Nix disk and journal errors";
      type = "timeseries";
      kind = "time series";
      custom = lines;
      options = tooltip;
      x = 12;
      y = 173;
      w = 12;
      h = 8;
      sql = health ''
        ${metric "nix_disk_percent"} AS "nix disk %", ${metric "journal_errors_boot"} AS "journal errors"
      '';
    })
    (panel {
      title = "Rebuilds";
      type = "table";
      unit = "s";
      x = 0;
      y = 181;
      w = 12;
      h = 8;
      sql = ''
        SELECT strftime('%d/%m %H:%M', starttime / 1e9, 'unixepoch', 'localtime') AS at,
          CASE ${metric "ok"} WHEN 1 THEN 'ok' ELSE 'failed' END AS result,
          (endtime - starttime) / 1e9 AS seconds
        FROM events WHERE bucketrow = ${bucket "aw-watcher-events_"} AND ${metric "kind"} = 'rebuild'
          AND endtime > ${from} AND starttime < ${to}
        ORDER BY starttime DESC LIMIT 50
      '';
    })
    (panel {
      title = "Failed units now";
      type = "table";
      x = 12;
      y = 181;
      w = 12;
      h = 8;
      sql = ''
        SELECT 'system' AS scope, u.value AS unit FROM (${latestRow}), json_each(data, '$.failed_system') AS u
        UNION ALL
        SELECT 'user', u.value FROM (${latestRow}), json_each(data, '$.failed_user') AS u
      '';
    })
  ];
in
{
  uid = "activity";
  title = "Activity";
  tags = [ "activitywatch" ];
  timezone = "browser";
  editable = true;
  refresh = "1m";
  time = {
    from = "now/d";
    to = "now";
  };
  schemaVersion = 39;
  panels = lib.imap1 (id: p: p // { inherit id; }) panels;
}
