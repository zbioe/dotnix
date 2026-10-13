{
  config,
  lib,
  pkgs,
  waybar,
  ...
}:
let
  # quick pickers on fuzzel (themed by stylix); right click keeps the full GUI
  wifiMenu = "${pkgs.networkmanager_dmenu}/bin/networkmanager_dmenu";
  bluetoothMenu = "${pkgs.bzmenu}/bin/bzmenu --launcher fuzzel --interactive";
  audioMenu = "${pkgs.pwmenu}/bin/pwmenu --launcher fuzzel --interactive";
  theme = lib.getExe config.theme.package;
in
{
  xdg.configFile."networkmanager-dmenu/config.ini".text = lib.generators.toINI { } {
    dmenu = {
      dmenu_command = "fuzzel --dmenu";
      compact = true;
      wifi_chars = "▂▄▆█";
    };
  };

  programs.waybar = {
    enable = true;
    package = waybar;
    systemd.enable = true;
    style = lib.mkMerge [
      (lib.mkBefore ''
        @import url("file://${config.xdg.stateHome}/theme/current/waybar.css");

        * {
            font-family: "${config.stylix.fonts.monospace.name}";
            font-size: ${toString config.stylix.fonts.sizes.desktop}pt;
        }
      '')
      (builtins.readFile ./waybar.css)
      (lib.mkAfter ''
        .modules-left #workspaces button.active {
          background: @base01;
          border-bottom: 0px solid @base05;
        }
      '')
    ];
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
          "custom/theme"
          "tray"
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
            "10" = "";
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
          on-click = audioMenu;
          on-click-right = "pavucontrol";
          on-click-middle = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        };
        "custom/theme" = {
          exec = "${theme} icon";
          interval = "once";
          tooltip = false;
          on-click = "${theme} toggle";
          on-click-right = "${theme} menu";
        };
        "custom/separator" = {
          format = " | ";
          interval = "once";
          tooltip = false;
        };
        battery = {
          format = "{icon} ";
          format-charging = "{icon} 󰚥 ";
          format-icons = [
            ""
            ""
            ""
            ""
            ""
          ];
          interval = 60;
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
          on-click = bluetoothMenu;
          on-click-right = "blueman-manager";
        };

        network = {
          interval = 5;
          format-disconnected = "󰤭 ";
          format-wifi = "󰖩 ";
          format-ethernet = "󰈀 ";
          tooltip-format = "{essid}  {signalStrength} | {ipaddr}/{cidr}  {bandwidthUpBytes} 󰁅 {bandwidthDownBytes}";
          on-click = wifiMenu;
          on-click-right = "nm-connection-editor";
        };

        memory = {
          interval = 10;
          format = " {percentage}%";
          tooltip-format = "{used} / {total} G";
        };
        cpu = {
          interval = 5;
          format = " {usage}%";
        };
        disk = {
          interval = 60;
          format = " {percentage_used}%";
          tooltip-format = "{used} used out of {total} on {path} ";
        };

        clock = {
          format = "{:%H:%M}";
          format-alt = "{:%d.%m.%Y}";
          tooltip-format = "<tt>{calendar}</tt>";
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
