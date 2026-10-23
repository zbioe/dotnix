# ActivityWatch's side in the system: the browsers' watcher extension and the
# data kept off the backup (it never leaves the machine). The server, the other
# watchers and Grafana are the user's (home/desktop/activity).
{
  config,
  lib,
  ...
}:
let
  cfg = config.dotnix.desktop.activity;
in
{
  options.dotnix.desktop.activity.enable =
    lib.mkEnableOption "ActivityWatch (local only) and Grafana over it";

  config = lib.mkIf cfg.enable {
    # the watcher extension in Chromium and Brave (LibreWolf: its own policies)
    dotnix.desktop.browsers.chromiumExtensions = [ "nglaklhklhcoonedhgnpgddginnjdadi" ];

    dotnix.storage.backup.exclude = [
      ".local/share/activitywatch"
      ".local/share/grafana"
    ];
  };
}
