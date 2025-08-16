{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        margin-top = 0;
        margin-bottom = 0;
        modules-left = [
          "custom/logo"
          "hyprland/workspaces"
        ];
        modules-right = [
          "idle_inhibitor"
          "pulseaudio"
          "tray"
          "clock"
        ];

        "custom/logo" = {
          format = "  ";
          tooltip = false;
        };

        "hyprland/workspaces" = {
          disable-scroll = true;
          persistent_workspaces = {
            "I" = [ ];
            "II" = [ ];
            "III" = [ ];
            "IV" = [ ];
            "V" = [ ];
            "VI" = [ ];
            "VII" = [ ];
            "VIII" = [ ];
            "IX" = [ ];
            "X" = [ ];
          };
          disable-click = false;
        };

        pulseaudio = {
          format = " {icon} ";
          format-muted = "";
          format-icons = [
            ""
            "󰖀"
            "󰕾"
          ];
          tooltip = true;
          tooltip-format = "{volume}%";
        };

        clock = {
          format = ''{:%H:%M}'';
          format-alt = ''{:%d.%m.%Y}'';
          tooltip-format = ''<tt>{calendar}</tt>'';
          calendar = {
            mode = "month";
            mode-mon-col = 3;
            weeks-pos = "right";
            on-scroll = 1;
            format = {
              months = "<span color='#bac2de'><b>{}</b></span>";
              days = "<span color='#cdd6f4'><b>{}</b></span>";
              weeks = "<span color='#f9e2af'><b>W{}</b></span>";
              weekdays = "<span color='#a6adc8'><b>{}</b></span>";
              today = "<span color='#f38ba8'><b><u>{}</u></b></span>";
            };
          };
        };

        idle_inhibitor = {
          format = "{icon}";
          format-icons = {
            activated = "";
            deactivated = "";
          };
          tooltip = true;
          tooltip-format-activated = "Idle inhibitor active";
          tooltip-format-deactivated = "Idle inhibitor inactive";
        };

        tray = {
          icon-size = 21;
          spacing = 10;
        };
      };
    };
  };
}
