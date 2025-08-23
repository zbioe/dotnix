{
  lib,
  ...
}:
{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = lib.mkAfter ''
      .modules-left #workspaces button.active {
        background: @base01;
        border-bottom: 0px solid @base05;
      }
    '';
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
          "bluetooth"
          "custom/separator"
          "memory"
          "cpu"
          "disk"
          "custom/separator"
          "pulseaudio"
          "network"
          "clock"
          "battery"
        ];

        modules-center = [
          "hyprland/window"
        ];

        "custom/logo" = {
          format = "   ";
          tooltip = false;
        };

        "hyprland/workspaces" = {
          disable-scroll = true;
          disable-click = false;
          format = "{icon}";
          format-icons = {
            "1" = "󱢢";
            "2" = "";
            "3" = "󱑴";
            "4" = "󱪿";
            "5" = "";
            "6" = "󰇏";
            "7" = "";
            "8" = "󱂏";
            "9" = "";
            "10" = "";
            "default" = "";
          };
        };

        "hyprland/window" = {
          seaparate-outputs = true;
          rewrite = {
            "(.*) — Doom Emacs" = " $1";
            "Tmux - (.*)" = "  $1";
          };
        };

        pulseaudio = {
          format = "{icon} ";
          format-muted = " ";
          format-icons = [
            ""
            ""
            ""
          ];
          tooltip = true;
          tooltip-format = "{volume}%";
          on-click = "pavucontrol";
          on-click-middle = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        };
        "custom/separator" = {
          format = " | ";
          interval = "once";
          tooltip = false;
        };
        battery = {
          format = "{icon} ";
          format-icons = [
            ""
            ""
            ""
            ""
            ""
          ];
          tooltip = true;
          tooltip-format = "{capacity}%";
        };

        bluetooth = {
          format = "󰂯";
          format-disabled = "󰂲";
          format-connected = "󰂱";
          format-no-controller = "";
          tooltip-format = "{device_alias}";
          format-connected-battery = "  {device_battery_percentage}% ";
          tooltip-format-enumerate-connected = "{device_alias}";
          on-click = "blueman-manager";
        };

        network = {
          interval = 1;
          format-disconnected = "󰤭 ";
          format-wifi = "󰖩 ";
          format-ethernet = "󰈀 ";
          tooltip-format = "{essid}  {signalStrength} | {ipaddr}/{cidr}  {bandwidthUpBytes} 󰁅 {bandwidthDownBytes}";
          on-click = "nm-connection-editor";
        };

        memory = {
          interval = 1;
          format = " {percentage}%";
          tooltip-format = "{used} / {total} G";
        };
        cpu = {
          interval = 1;
          format = " {usage}%";
        };
        disk = {
          interval = 60;
          format = " {percentage_used}%";
          tooltip-format = "{used} used out of {total} on {path} ";
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
          format = "{icon} ";
          format-icons = {
            activated = "";
            deactivated = "";
          };
          tooltip = true;
          tooltip-format-activated = "Idle inhibitor active";
          tooltip-format-deactivated = "Idle inhibitor inactive";
        };
      };
    };
  };
}
