# The monitors' arrangement, set by hand in a window and kept: "Monitors"
# opens wdisplays (drag, rotate, pick the refresh rate, Apply); closing it
# saves what's applied as a shikane profile for that set of monitors, which
# shikane applies again whenever they're plugged in. The profiles stay in
# ~/.config/shikane/config.toml, editable by hand (not managed here).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.desktop.displays;
  configFile = "${config.xdg.configHome}/shikane/config.toml";
  python = pkgs.python3.withPackages (p: [ p.tomli-w ]);

  # the arrangement now, as the profile of this set of monitors (replacing
  # the one it had)
  save = pkgs.writeScriptBin "displays-save" ''
    #!${python}/bin/python3
    import subprocess, sys, tomllib, tomli_w
    from pathlib import Path

    path = Path("${configFile}")
    out = subprocess.run(
        ["${pkgs.shikane}/bin/shikanectl", "export", "--vendor", "--model", "--serial", "current"],
        capture_output=True, text=True, check=True,
    ).stdout
    profile = tomllib.loads(out)["profile"][0]

    def label(output):
        fields = dict(s.split("=", 1) for s in output["search"])
        return f"{fields.get('v', ''')} {fields.get('m', ''')}".strip()

    profile["name"] = " + ".join(sorted(label(o) for o in profile["output"]))
    text = path.read_text() if path.exists() else ""
    profiles = [p for p in tomllib.loads(text).get("profile", []) if p.get("name") != profile["name"]]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(tomli_w.dumps({"profile": profiles + [profile]}))
    subprocess.run(["${pkgs.shikane}/bin/shikanectl", "reload"], check=False)
    print(f"saved: {profile['name']}")
  '';

  monitors = pkgs.writeShellApplication {
    name = "monitors";
    runtimeInputs = [
      pkgs.wdisplays
      pkgs.libnotify
      save
    ];
    text = ''
      wdisplays
      if name=$(displays-save); then
        notify-send -a monitors -i video-display "Monitors" "''${name#saved: }"
      else
        notify-send -a monitors -u critical -i dialog-error "Monitors" "Could not save the arrangement"
      fi
    '';
  };
in
{
  options.dotnix.desktop.displays.enable =
    lib.mkEnableOption "monitor arrangement set in a window and kept (wdisplays, shikane)"
    // {
      default = config.dotnix.desktop.enable;
    };

  config = lib.mkIf cfg.enable {
    home.packages = [
      monitors
      save
      pkgs.shikane # shikanectl: switch or reload profiles by hand
    ];

    xdg.desktopEntries.monitors = {
      name = "Monitors";
      comment = "Arrange, rotate and set the refresh rate of the monitors; kept for next time";
      exec = "monitors";
      icon = "video-display";
      categories = [
        "Settings"
        "HardwareSettings"
      ];
    };

    systemd.user.services.shikane = {
      Unit = {
        Description = "Apply the saved monitor arrangement (shikane)";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        # the first time there's nothing saved yet
        ExecStartPre = "${pkgs.writeShellScript "shikane-config" ''
          ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname ${configFile})"
          ${pkgs.coreutils}/bin/touch ${configFile}
        ''}";
        ExecStart = "${pkgs.shikane}/bin/shikane -c ${configFile}";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
