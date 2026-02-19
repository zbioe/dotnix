{
  pkgs,
  config,
  lib,
  ...
}:

let
  colors = config.lib.stylix.colors;

  network-script = pkgs.writeShellScript "yambar-network" ''
    # Tenta achar interface wireless
    WLAN=$(ls /sys/class/net/ | grep ^w | head -n 1)
    # Tenta achar interface ethernet (caso use cabo)
    ETH=$(ls /sys/class/net/ | grep ^e | head -n 1)

    if [ -n "$WLAN" ] && [ "$(cat /sys/class/net/$WLAN/operstate 2>/dev/null)" = "up" ]; then
      SSID=$(${pkgs.wirelesstools}/bin/iwgetid -r || echo "Wi-Fi")
      echo "type|string|wifi"
      echo "state|string|up"
      echo "name|string|$SSID"
    elif [ -n "$ETH" ] && [ "$(cat /sys/class/net/$ETH/operstate 2>/dev/null)" = "up" ]; then
      echo "type|string|eth"
      echo "state|string|up"
      echo "name|string|Ethernet"
    else
      echo "state|string|down"
      echo "name|string|Disc."
    fi
    echo ""
  '';

  bluetooth-script = pkgs.writeShellScript "yambar-bluetooth" ''
    if ! command -v bluetoothctl &> /dev/null; then
      echo "status|string|off"
      exit 0
    fi

    # Verifica se está ligado (Powered: yes)
    POWER=$(bluetoothctl show | grep "Powered: yes")

    if [ -z "$POWER" ]; then
      echo "status|string|off"
    else
      CONNECTED=$(bluetoothctl devices Connected | head -n 1)
      if [ -n "$CONNECTED" ]; then
        echo "status|string|connected"
      else
        echo "status|string|on"
      fi
    fi
    echo ""
  '';

  disk-script = pkgs.writeShellScript "yambar-disk" ''
    # Pega a porcentagem de uso do /
    USE=$(df -h / --output=pcent | sed 1d | tr -d ' %')
    echo "used|int|$USE"
    echo ""
  '';

in
{
  programs.yambar = {
    enable = true;
    settings = {
      bar = {
        layer = "top";
        location = "top";
        height = 28;
        background = "${colors.base00}ff";
        font = "${config.stylix.fonts.monospace.name}:pixelsize=12";

        left = [
          {
            river = {
              anchors = {
                base = {
                  left-margin = 8;
                  right-margin = 8;
                  default = {
                    string = {
                      text = "{id}";
                    };
                  };
                };
              };
              content = {
                map = {
                  conditions = {
                    "focused" = {
                      string = {
                        text = "[{id}]";
                        foreground = "${colors.base0B}ff";
                        font = "bold";
                      };
                    };
                    "occupied" = {
                      string = {
                        text = "{id}";
                        foreground = "${colors.base05}ff";
                      };
                    };
                    "visible" = {
                      string = {
                        text = "{id}";
                        foreground = "${colors.base0E}ff";
                      };
                    };
                    "urgent" = {
                      string = {
                        text = "{id}!";
                        foreground = "${colors.base08}ff";
                      };
                    };
                  };
                };
              };
            };
          }
        ];

        # --- CENTRO: TÍTULO DA JANELA ---
        center = [
          {
            foreign-toplevel = {
              content = {
                map = {
                  conditions = {
                    "activated" = {
                      string = {
                        text = "{app-id}: {title}";
                        foreground = "${colors.base05}ff";
                      };
                    };
                    "~activated" = {
                      empty = { };
                    };
                  };
                };
              };
            };
          }
        ];

        right = [
          # Bluetooth
          {
            script = {
              path = "${bluetooth-script}";
              poll-interval = 5000;
              content = {
                map = {
                  conditions = {
                    "status == connected" = {
                      string = {
                        text = "󰂱 | ";
                        foreground = "${colors.base0D}ff";
                        on-click = "notify-send 'Bluetooth' 'Conectado: {devices}'";
                      };
                    };
                    "status == on" = {
                      string = {
                        text = "󰂯 | ";
                        foreground = "${colors.base05}ff";
                        on-click = "notify-send 'Bluetooth' 'Ligado (Sem dispositivos)'";
                      };
                    };
                    "status == off" = {
                      string = {
                        text = "󰂲 | ";
                        foreground = "${colors.base03}ff";
                        on-click = "notify-send 'Bluetooth' 'Desligado'";
                      };
                    };
                  };
                };
              };
            };
          }
          # Disk
          {
            script = {
              path = "${disk-script}";
              poll-interval = 60000; # Verifica a cada 1 min
              content = {
                string = {
                  text = " {used}% | ";
                  foreground = "${colors.base0E}ff";
                  on-click = "notify-send 'Disco (/)' 'Livre: {free}\nTotal: {total}'";
                };
              };
            };
          }
          # CPU
          {
            cpu = {
              poll-interval = 2500;
              content = {
                map = {
                  conditions = {
                    "id < 0" = {
                      string = {
                        text = " {cpu}% | ";
                        foreground = "${colors.base09}ff";
                        on-click = ''notify-send 'Top CPU' "$(ps -eo pcpu,comm --sort=-pcpu | head -n 6)"'';
                      };
                    };
                  };
                };
              };
            };
          }
          {
            mem = {
              poll-interval = 2500;
              content = {
                string = {
                  text = " {percent_used}% | ";
                  foreground = "${colors.base0C}ff";
                };
              };
            };
          }
          {
            script = {
              path = "${network-script}";
              poll-interval = 5000;
              content = {
                map = {
                  conditions = {
                    "state == up" = {
                      string = {
                        text = "󰖩 {name} | ";
                        foreground = "${colors.base0B}ff";
                      };
                    };
                    "state == down" = {
                      string = {
                        text = "󰤭 Disc. | ";
                        foreground = "${colors.base08}ff";
                      };
                    };
                  };
                };
              };
            };
          }
          {
            battery = {
              name = "BAT0";
              poll-interval = 30000;
              content = {
                map = {
                  conditions = {
                    "state == charging" = {
                      string = {
                        text = "󰚥 {capacity}% | ";
                        foreground = "${colors.base0B}ff";
                        on-click = "notify-send 'Battery' 'Charging...\n{capacity}%'";
                      };
                    };
                    "state == discharging" = {
                      string = {
                        text = " {capacity}% | ";
                        foreground = "${colors.base0A}ff";
                        on-click = "notify-send 'Battery' 'Discharging...\n{capacity}%'";
                      };
                    };
                    "state == full" = {
                      string = {
                        text = " {capacity}% | ";
                        foreground = "${colors.base0B}ff";

                      };
                    };
                    "capacity < 80" = {
                      string = {
                        text = " {capacity}% | ";
                        foreground = "${colors.base08}ff";
                        on-click = "notify-send 'Battery' 'Discharging...\n{capacity}%'";
                      };
                    };
                    "capacity < 60" = {
                      string = {
                        text = " {capacity}% | ";
                        foreground = "${colors.base08}ff";
                        on-click = "notify-send 'Battery' 'Discharging...\n{capacity}%'";
                      };
                    };
                    "capacity < 40" = {
                      string = {
                        text = " {capacity}% | ";
                        foreground = "${colors.base08}ff";
                        on-click = "notify-send 'Battery' 'Discharging...\n{capacity}%'";
                      };
                    };
                    "capacity < 20" = {
                      string = {
                        text = " {capacity}% | ";
                        foreground = "${colors.base08}ff";
                        on-click = "notify-send -u critical 'Low Battery' '{capacity}%!'";
                      };
                    };
                  };
                };
              };
            };
          }
          {
            clock = {
              time-format = "%H:%M";
              date-format = "%Y-%m-%d";
              content = {
                string = {
                  text = "{time} ";
                  foreground = "${colors.base05}ff";
                  on-click = "notify-send 'Calendar' \"$(cal)\"";
                };
              };
            };
          }
        ];
      };
    };
  };
}
