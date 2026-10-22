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
  browsers = config.dotnix.desktop.browsers;
  policy = builtins.toJSON {
    ExtensionInstallForcelist = [
      "nglaklhklhcoonedhgnpgddginnjdadi;https://clients2.google.com/service/update2/crx"
    ];
  };
in
{
  options.dotnix.desktop.activity.enable =
    lib.mkEnableOption "ActivityWatch (local only) and Grafana over it";

  config = lib.mkIf cfg.enable {
    environment.etc = {
      "chromium/policies/managed/activitywatch.json" = lib.mkIf browsers.chromium.enable {
        text = policy;
      };
      "brave/policies/managed/activitywatch.json" = lib.mkIf browsers.brave.enable { text = policy; };
    };

    dotnix.storage.backup.exclude = [
      ".local/share/activitywatch"
      ".local/share/grafana"
    ];
  };
}
