# ActivityWatch, everything on this machine only: aw-server-rust on
# 127.0.0.1:5600 with watchers for windows and AFK (awatcher, Wayland), the
# system (load, processes, state, the setup's health), media (MPRIS) and the
# shell; the browsers' extension (system/desktop/activity.nix), zmacs and
# `rebuild` send their own. Grafana draws it all at 127.0.0.1:5610, started on
# the first visit and stopped when left alone; `activity report` sums up a day
# or a week (a notification every evening, and on Sundays for the week).
{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.desktop.activity;
  host = osConfig.networking.hostName;
  api = "http://127.0.0.1:5600/api/0";
  data = "${config.xdg.dataHome}/activitywatch";
  db = "${data}/aw-server-rust/sqlite.db";
  grafanaPort = 5610;

  python = pkgs.python3.withPackages (p: [ p.psutil ]);

  watcher =
    name: script: inputs:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = inputs;
      text = ''exec ${python}/bin/python3 -u ${script} "$@"'';
    };

  systemWatcher = watcher "aw-watcher-system" ./system.py (
    with pkgs;
    [
      wireplumber # wpctl: audio output
      networkmanager # nmcli: Wi-Fi
      bluez # bluetoothctl: connected devices
      systemd # systemctl, journalctl: failed units, errors
      snapper # snapshot count
      fwupd # fwupdmgr: firmware updates
    ]
  );
  mediaWatcher = watcher "aw-watcher-media" ./media.py [ pkgs.playerctl ];

  term = pkgs.writeShellApplication {
    name = "aw-term";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      git
      jq
      curl
      tmux
    ];
    text = ''
      AW_API=${api}
      HOSTNAME=${host}
      ${builtins.readFile ./term.sh}
    '';
  };

  # buckets written to with plain events: the shell's and the setup's own
  # (rebuilds); the server answers once it says it's ready (Type=notify)
  buckets = pkgs.writeShellScript "aw-buckets" ''
    bucket() {
      ${lib.getExe pkgs.curl} -sf -X POST -H 'Content-Type: application/json' \
        -d "{\"client\":\"$2\",\"type\":\"$3\",\"hostname\":\"${host}\"}" \
        "${api}/buckets/$1_${host}" >/dev/null || true
    }
    bucket aw-watcher-terminal aw-term app.terminal.command
    bucket aw-watcher-events dotnix os.events
  '';

  # `activity report`: the dashboard's own queries, with :from and :to
  queries =
    let
      q = import ./sql.nix {
        inherit lib;
        from = ":from";
        to = ":to";
      };
      field = f: "json_extract(data, '$.${f}')";
    in
    pkgs.writeText "activity-queries.json" (
      builtins.toJSON {
        active = "WITH ${q.active} SELECT coalesce(sum(e - s), 0) / 1e9 FROM active";
        focus = "WITH ${q.active} SELECT coalesce(max(e - s), 0) / 1e9 FROM active";
        categories = q.byCategory;
        apps = q.activeBy "aw-watcher-window_" (field "app") 5;
        sites = q.activeBy "aw-watcher-web-" (q.domain (field "url")) 5;
        projects = ''
          SELECT name, sum(seconds) FROM (
            SELECT * FROM (${q.activeBy "aw-watcher-emacs_" (field "project") 1000})
            UNION ALL
            SELECT ${field "project"} AS name, sum(e - s) / 1e9 AS seconds
            FROM (${q.inRange "aw-watcher-terminal_"}) GROUP BY name
          ) WHERE name IS NOT NULL GROUP BY name ORDER BY 2 DESC LIMIT 5
        '';
        switches = "SELECT count(*) FROM (${q.inRange "aw-watcher-window_"})";
        commands = "SELECT count(*), coalesce(sum(${field "status"} != 0), 0) FROM (${q.inRange "aw-watcher-terminal_"})";
        typed = "SELECT coalesce(sum(${field "chars"}), 0) FROM (${q.inRange "aw-watcher-emacs-input_"})";
        media = ''
          SELECT coalesce(${field "artist"} || ' - ', ''') || ${field "title"}, sum(e - s) / 1e9
          FROM (${q.inRange "aw-watcher-media_"}) GROUP BY 1 ORDER BY 2 DESC LIMIT 5
        '';
      }
    );

  # the database's own: machine samples thinned after 90 days, then compacted
  retention = pkgs.writeShellScript "aw-retention" ''
    systemctl --user stop aw-server.service
    AW_DB=${db} ${python}/bin/python3 ${./retention.py}
    status=$?
    systemctl --user start aw-server.service
    exit $status
  '';

  grafanaIni = pkgs.writeText "grafana.ini" (
    lib.generators.toINI { } {
      # a unix socket, the proxy's backend: there once Grafana listens
      server = {
        protocol = "socket";
        socket = "$__env{RUNTIME_DIRECTORY}/grafana.sock";
        root_url = "http://127.0.0.1:${toString grafanaPort}/";
      };
      paths = {
        data = "${config.xdg.dataHome}/grafana";
        logs = "${config.xdg.stateHome}/grafana";
        plugins = pkgs.linkFarm "grafana-plugins" [
          {
            name = "frser-sqlite-datasource";
            path = pkgs.grafanaPlugins.frser-sqlite-datasource;
          }
        ];
        inherit provisioning;
      };
      # nothing leaves the machine
      analytics = {
        reporting_enabled = false;
        check_for_updates = false;
        check_for_plugin_updates = false;
        feedback_links_enabled = false;
      };
      news.news_feed_enabled = false;
      snapshots.external_enabled = false;
      public_dashboards.enabled = false;
      security.disable_gravatar = true;
      plugins = {
        plugin_admin_enabled = false;
        # (the plugins it would download at every start)
        preinstall_disabled = true;
      };
      unified_alerting.enabled = false;
      # one user, on localhost
      auth.disable_login_form = true;
      "auth.anonymous".enabled = true;
      users.default_theme = "system";
      dashboards.default_home_dashboard_path = "${dashboards}/activity.json";
      log.mode = "console";
    }
  );

  dashboards = pkgs.writeTextDir "activity.json" (
    builtins.toJSON (import ./dashboard.nix { inherit lib; })
  );

  provisioning = pkgs.linkFarm "grafana-provisioning" [
    {
      name = "datasources/activitywatch.yaml";
      path = pkgs.writeText "datasource.yaml" (
        builtins.toJSON {
          apiVersion = 1;
          datasources = [
            {
              name = "ActivityWatch";
              uid = "activitywatch";
              type = "frser-sqlite-datasource";
              isDefault = true;
              jsonData = {
                path = db;
                pathPrefix = "file:";
                pathOptions = "?mode=ro";
              };
            }
          ];
        }
      );
    }
    {
      name = "dashboards/activity.yaml";
      path = pkgs.writeText "dashboards.yaml" (
        builtins.toJSON {
          apiVersion = 1;
          providers = [
            {
              name = "dotnix";
              type = "file";
              disableDeletion = true;
              allowUiUpdates = false;
              options.path = dashboards;
            }
          ];
        }
      );
    }
  ];

  # `activity`: the dashboard (the socket starts Grafana on the first
  # request); `activity report [today|yesterday|week] [--notify] [--save]`
  activity = pkgs.writeShellApplication {
    name = "activity";
    runtimeInputs = [
      pkgs.xdg-utils
      pkgs.libnotify
    ];
    text = ''
      if [ "''${1:-}" = report ]; then
        shift
        AW_DB=${db} AW_REPORT_QUERIES=${queries} exec ${python}/bin/python3 ${./report.py} "$@"
      fi
      exec xdg-open http://127.0.0.1:${toString grafanaPort}/d/activity
    '';
  };

  timer = calendar: {
    Timer = {
      OnCalendar = calendar;
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };

  service = description: exec: extra: {
    Unit = {
      Description = description;
      After = [ "aw-server.service" ];
      Wants = [ "aw-server.service" ];
    }
    // extra.Unit or { };
    Service = {
      ExecStart = exec;
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = extra.wantedBy or [ "graphical-session.target" ];
  };
in
{
  options.dotnix.desktop.activity.enable =
    lib.mkEnableOption "ActivityWatch with every watcher, and Grafana over it"
    // {
      default = osConfig.dotnix.desktop.activity.enable or false;
    };

  config = lib.mkIf cfg.enable {
    home.packages = [
      activity
      term
    ];

    xdg.desktopEntries.activity = {
      name = "Activity";
      genericName = "Where the time goes";
      exec = lib.getExe activity;
      icon = "utilities-system-monitor";
      categories = [ "Utility" ];
    };

    # every finished command, in the background so the prompt never waits
    programs.fish.functions.__aw_postexec = {
      onEvent = "fish_postexec";
      body = ''
        set -l st $status
        ${lib.getExe term} "$argv[1]" $st $CMD_DURATION "$PWD" &>/dev/null &
        disown 2>/dev/null
      '';
    };

    systemd.user.services = {
      aw-server = {
        Unit.Description = "ActivityWatch server (127.0.0.1:5600)";
        Service = {
          Type = "notify";
          ExecStart = "${pkgs.aw-server-rust}/bin/aw-server --host 127.0.0.1 --port 5600 --dbpath ${db}";
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${data}/aw-server-rust";
          ExecStartPost = buckets;
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "default.target" ];
      };

      aw-awatcher =
        service "ActivityWatch: windows and AFK (Wayland)"
          "${pkgs.awatcher}/bin/awatcher --idle-timeout 120"
          {
            Unit = {
              PartOf = [ "graphical-session.target" ];
              After = [
                "aw-server.service"
                "graphical-session.target"
              ];
            };
          };
      aw-watcher-system =
        lib.recursiveUpdate
          (service "ActivityWatch: load, processes, state and health" (lib.getExe systemWatcher) {
            wantedBy = [ "default.target" ];
          })
          {
            Service.Environment = [
              "AW_BACKUP_DIR=${osConfig.dotnix.storage.backup.cacheDir or "/var/cache/backup"}"
            ];
          };
      aw-watcher-media = service "ActivityWatch: what plays (MPRIS)" (lib.getExe mediaWatcher) {
        Unit.PartOf = [ "graphical-session.target" ];
      };

      grafana = {
        Unit = {
          Description = "Grafana over ActivityWatch (on demand)";
          StopWhenUnneeded = true;
        };
        Service = {
          ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${config.xdg.dataHome}/grafana ${config.xdg.stateHome}/grafana";
          RuntimeDirectory = "grafana";
          ExecStart = "${pkgs.grafana}/bin/grafana server --homepath ${pkgs.grafana}/share/grafana --config ${grafanaIni}";
          # ready once its socket is there (its own READY comes before it
          # listens), so the first request waits for it
          ExecStartPost = pkgs.writeShellScript "grafana-ready" ''
            exec {events}< <(exec ${pkgs.inotify-tools}/bin/inotifywait -m -e create --format %f "$RUNTIME_DIRECTORY" 2>&1)
            name=""
            until [ "$name" = "Watches established." ]; do read -r name <&"$events"; done
            until [ -S "$RUNTIME_DIRECTORY/grafana.sock" ]; do read -r name <&"$events"; done
          '';
          TimeoutStartSec = 90;
        };
      };
      activity-report = {
        Unit.Description = "Today's activity, as a notification and in ~/org/activity";
        Service = {
          Type = "oneshot";
          ExecStart = "${lib.getExe activity} report today --notify --save";
        };
      };
      activity-report-week = {
        Unit.Description = "The week's activity, as a notification and in ~/org/activity";
        Service = {
          Type = "oneshot";
          ExecStart = "${lib.getExe activity} report week --notify --save";
        };
      };
      aw-retention = {
        Unit.Description = "ActivityWatch: thin old machine samples, compact the database";
        Service = {
          Type = "oneshot";
          ExecStart = retention;
        };
      };

      # the socket's side: forwards to Grafana and lets it go after 30 idle minutes
      grafana-proxy = {
        Unit = {
          Description = "Grafana on demand";
          Requires = [ "grafana.service" ];
          After = [ "grafana.service" ];
        };
        Service.ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=30min %t/grafana/grafana.sock";
      };
    };

    systemd.user.timers = {
      activity-report = timer "*-*-* 21:30";
      activity-report-week = timer "Sun *-*-* 21:35";
      aw-retention = timer "monthly";
    };

    systemd.user.sockets.grafana-proxy = {
      Unit.Description = "Grafana on demand (127.0.0.1:${toString grafanaPort})";
      Socket.ListenStream = "127.0.0.1:${toString grafanaPort}";
      Install.WantedBy = [ "sockets.target" ];
    };
  };
}
