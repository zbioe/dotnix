# Noctalia: bar, launcher, notifications and lock screen of the mango session.
# Its colors follow `theme`, and its dark/light toggle drives `theme` back.
{
  config,
  osConfig,
  lib,
  pkgs,
  ...
}:
let
  laptop = osConfig.dotnix.hardware.laptop.enable;
  # where am I (GeoClue, Wi-Fi based) -> ~/.config/noctalia/location.toml;
  # noctalia merges every *.toml in its config dir
  locate = pkgs.writeShellApplication {
    name = "noctalia-locate";
    runtimeInputs = [ pkgs.gawk ];
    text = ''
      out=${config.xdg.configHome}/noctalia/location.toml
      fix=$(LC_ALL=C ${pkgs.geoclue2}/libexec/geoclue-2.0/demos/where-am-i -t 20 -a 8 2>/dev/null |
        awk -F: '/Latitude/ { gsub(/[ °]/, "", $2); sub(/,/, ".", $2); lat = $2 }
                 /Longitude/ { gsub(/[ °]/, "", $2); sub(/,/, ".", $2); lon = $2 }
                 END { if (lat != "" && lon != "") print lat, lon }' || true)
      if [ -z "$fix" ]; then
        echo "noctalia-locate: no fix, keeping $out"
        exit 0
      fi
      read -r lat lon <<< "$fix"
      cat > "$out.tmp" <<EOF
      [location]
      auto_locate = false
      latitude = $lat
      longitude = $lon
      EOF
      mv "$out.tmp" "$out"
      # the same position for `theme auto` (sunrise/sunset)
      echo "$lat $lon" > ${config.xdg.stateHome}/theme/location
      ${lib.getExe config.dotnix.theme.package} auto-tick
      echo "noctalia-locate: $lat $lon"
    '';
  };

  plugins = config.dotnix.desktop.noctalia.plugins;
  # local plugins, registered by the modules that own them
  dotnixPlugins = pkgs.runCommandLocal "noctalia-plugins" { } (
    lib.concatStrings (
      lib.mapAttrsToList (name: plugin: ''
        mkdir -p $out/${name}
        cp ${plugin.src}/*.luau $out/${name}/
        cp ${
          (pkgs.formats.toml { }).generate "plugin.toml" (
            {
              id = "dotnix/${name}";
              version = "1.0.0";
              plugin_api = 26;
              author = "dotnix";
              license = "MIT";
            }
            // plugin.manifest
          )
        } $out/${name}/plugin.toml
        ${lib.concatStrings (
          lib.mapAttrsToList (file: path: "cp ${path} $out/${name}/${file}\n") plugin.files
        )}
      '') plugins
    )
  );
in
{
  options.dotnix.desktop.noctalia.enable =
    lib.mkEnableOption "noctalia: bar, launcher, notifications and lock screen";
  options.dotnix.desktop.noctalia.plugins = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          src = lib.mkOption {
            type = lib.types.path;
            description = "Folder with the plugin's .luau files.";
          };
          manifest = lib.mkOption {
            type = lib.types.attrs;
            description = "plugin.toml, without id, version, plugin_api, author and license.";
          };
          files = lib.mkOption {
            type = lib.types.attrsOf lib.types.path;
            default = { };
            description = "More files of the plugin (data its scripts read).";
          };
        };
      }
    );
    default = { };
  };

  config = lib.mkIf config.dotnix.desktop.noctalia.enable {
    systemd.user.services.noctalia-locate = {
      Unit.Description = "Locate this machine for noctalia (GeoClue)";
      Service = {
        Type = "oneshot";
        ExecStart = lib.getExe locate;
      };
    };
    systemd.user.timers.noctalia-locate = {
      Unit.Description = "Locate this machine for noctalia (GeoClue)";
      Timer = {
        OnStartupSec = "30s";
        OnUnitActiveSec = "6h";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    # right click on a calendar day opens the text/calendar default: Google
    # Calendar on the web (mimeapps.list stays user-managed, only this entry)
    xdg.desktopEntries.google-calendar = {
      name = "Google Calendar";
      exec = "librewolf https://calendar.google.com/calendar/r";
      icon = "office-calendar";
      categories = [
        "Office"
        "Calendar"
      ];
      mimeType = [ "text/calendar" ];
    };
    home.activation.calendarDefault = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      run ${pkgs.xdg-utils}/bin/xdg-mime default google-calendar.desktop text/calendar
    '';

    programs.noctalia = {
      enable = true;
      # patched: overlays/default.nix
      package = pkgs.noctalia-shell;
      customPalettes = config.dotnix.theme.noctaliaPalettes;
      settings = {
        theme = {
          source = "custom";
          custom_palette = "nix-${config.dotnix.theme.default.name}";
          inherit (config.dotnix.theme.default) mode;
        };

        # the app icons' tint (each colorize_icons) comes from `theme icons tint`
        # (home/theme/icons)

        # everything here is declared: no first-run wizard (it shows on every
        # fresh home: the live ISO, a new install)
        shell.setup_wizard_enabled = false;

        # Activate emacs shortcuts
        shell.readline_shortcuts = true;
        # its own polkit agent: with none in the session, what asks for your
        # password (fprintd-enroll, disks, network settings) was refused unasked
        shell.polkit_agent = true;

        # Emacs keys too (C-n C-p C-f C-b), like GTK here: lists, the launcher,
        # tabs and menus of every noctalia surface
        keybinds = {
          up = [
            "up"
            "ctrl+p"
          ];
          down = [
            "down"
            "ctrl+n"
          ];
          left = [
            "left"
            "ctrl+b"
          ];
          right = [
            "right"
            "ctrl+f"
          ];
          validate = [
            "return"
            "enter"
            "kp_enter"
            "ctrl+m"
          ];
        };

        # its systemctl calls would broadcast over the shutdown splash
        shell.session.power = {
          reboot = "systemctl reboot --no-wall";
          shutdown = "systemctl poweroff --no-wall";
        };

        # session menu (the power button of the control center): the defaults,
        # plus the system + home switch in a floating terminal (home/desktop/rebuild.nix)
        shell.session.actions = [
          {
            action = "lock";
            shortcut = "1";
          }
          {
            action = "logout";
            shortcut = "2";
          }
          {
            action = "lock_and_suspend";
            shortcut = "3";
          }
          {
            action = "reboot";
            shortcut = "4";
          }
          {
            action = "shutdown";
            variant = "destructive";
            shortcut = "5";
          }
          {
            action = "command";
            command = "rebuild";
            label = "System Update";
            glyph = "package";
            shortcut = "6";
          }
          # flake updates: state, settings, apply (home/desktop/updates)
          {
            action = "command";
            command = "noctalia msg panel-open dotnix/updates:panel";
            label = "Updates";
            glyph = "refresh";
            shortcut = "7";
          }
        ];

        # generated per theme (home/theme); `theme` switches it live
        wallpaper.default.path = "${config.xdg.stateHome}/theme/current/wallpaper.png";

        bar.main = {
          position = "top";
          thickness = 36;
          reserve_space = true;
          background_opacity = 1.0;
          shadow = false;
          border_width = 0.0;
          radius = 0;
          radius_top_left = 0;
          radius_top_right = 0;
          radius_bottom_left = 0;
          radius_bottom_right = 0;
          concave_edge_corners = false;
          margin_ends = 0;
          margin_edge = 0;
          padding = 8;
          widget_spacing = 10;
          capsule = false;

          start = [
            "launcher"
            "workspaces"
          ];
          center = [ "active_window" ];
          end = [
            "caffeine"
            "bluetooth"
            "ram"
            "cpu"
            "disk"
            "volume"
            "vpn"
            "network"
            "themes"
            "keys" # shortcuts list (also Super+/)
            "clipboard" # history (also Super+V)
            "notifications" # bell; crossed out while do not disturb is on
            "tray"
          ]
          # (hidden by itself where there's no battery)
          ++ lib.optional laptop "brightness"
          ++ [
            "battery"
            # the clock at the far right, only the control center past it
            "clock"
            "control-center"
          ];

          # the AOC turned sideways (1080 wide): the full bar doesn't fit
          monitor.aoc = {
            match = "24G4";
            start = [
              "launcher"
              "workspaces"
            ];
            center = [ "active_window" ];
            end = [
              "brightness"
              "battery"
              "clock"
            ];
          };
        };

        # toasts on the laptop's screen only, not on the AOC
        notification.monitors = [ "eDP-1" ];

        widget = {
          launcher = {
            custom_image = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake-white.svg";
            custom_image_colorize = true;
          };
          workspaces = {
            style = "minimal";
            # label_map (an icon per tag), font_family and font_weight come from
            # `theme icons` (home/theme/icons), in ~/.config/noctalia/icons.toml
            hide_when_empty = true;
            focused_color = "primary";
            occupied_color = "on_surface";
            urgent_color = "error";
          };
          ram = {
            type = "sysmon";
            stat = "ram_pct";
            visualization = "none";
          };
          cpu = {
            type = "sysmon";
            stat = "cpu_usage";
            visualization = "none";
          };
          disk = {
            type = "sysmon";
            stat = "disk_used_pct";
            visualization = "none";
          };
          # icons only (details on hover / in the panels)
          network = {
            show_label = false;
            # the vpn widget shows it
            vpn_status = "hidden";
            # nm-applet's menu (VPN, ethernet, ...), hidden from the tray below
            actions.right = "tray-menu nm-applet";
            # order of the saved Wi-Fi networks (home/desktop/wifi)
            actions.middle = "panel-toggle dotnix/wifi:priority";
          };
          volume.show_label = false;
          # a glyph, so it follows the icon pack; the percentage on a laptop
          battery = {
            show_label = laptop;
            display_mode = "glyph";
          };
          brightness.show_label = false;

          # fcitx's "us" says nothing (fixed layout); network and bluetooth
          # already have their own widgets
          tray.hidden = [
            "fcitx"
            "nm-applet"
            "blueman"
          ];

          # shield lit while a VPN is up: the dotnix/vpn panel, right click toggles
          vpn.type = "dotnix/vpn:vpn";

          # shortcuts list: the dotnix/keys panel
          keys = {
            type = "custom_button";
            glyph = "keyboard";
            tooltip = "Shortcuts";
            actions.left = "panel-toggle dotnix/keys:list";
          };

          # theme picker: the dotnix/theme panel
          themes = {
            type = "custom_button";
            glyph = "palette";
            tooltip = "Themes (right click: fonts)";
            actions.left = "panel-toggle dotnix/theme:picker";
            actions.right = "panel-toggle dotnix/theme:fonts";
          };
        };

        # follows [location] (GeoClue, see noctalia-locate above)
        weather.enabled = true;
        # off: its tint makes the desktop disagree with the boot splash and
        # every themed app; on from the Monitor tab (brightness widget)
        nightlight.enabled = false;

        # lock after 10 min, screen off a minute later (caffeine pauses both)
        idle.behavior = {
          lock = {
            enabled = true;
            timeout = 600;
            action = "lock";
          };
          screen-off = {
            enabled = true;
            timeout = 660;
            action = "screen_off";
          };
        };

        # events from the accounts added in Settings -> Calendar (Google, ICS
        # links such as Proton's); credentials stay in the keyring, not here
        calendar.enabled = true;

        # the lock screen over the wallpaper exactly as it is (its colors never
        # leave the palette: no blur, no tint) and one quick fade in and out
        lockscreen = {
          blur_intensity = 0.0;
          tint_intensity = 0.0;
          transition = [ "fade" ];
          transition_duration = 400;
        };

        # The lock screen, per output (the laptop's, the AOC turned sideways):
        # a large thin clock with the date under it up top, a slim pill to
        # type in with a hint that the finger works too, what's playing at
        # the bottom left (only while something plays) and suspend, restart
        # and power off as plain icons at the bottom right
        lockscreen_widgets =
          let
            pill = {
              background_color = "surface_container";
              background_opacity = 0.9;
              background_radius = 32.0;
            };
            at = output: cx: cy: w: h: type: settings: {
              inherit
                output
                cx
                cy
                type
                settings
                ;
              box_width = w;
              box_height = h;
              rotation = 0.0;
            };
            clock = format: font: color: {
              inherit format color;
              font_family = font;
              center_text = true;
              background = false;
              shadow = false;
            };
            icon = glyph: command: {
              inherit glyph command;
              variant = "ghost";
              background = false;
              color = "on_surface";
            };
            # one centered column: the time, the date, the field to type in
            # (just the pill, no bar around it) and how to unlock under it;
            # what's playing floats at the bottom while something plays
            # placed for this output's size: without it noctalia rescales them
            # and saves its own copy, which then wins over this config
            screen =
              name: w: h:
              lib.mapAttrs
                (
                  _: v:
                  v
                  // {
                    placement_width = w;
                    placement_height = h;
                  }
                )
                {
                  "lockscreen-login-box@${name}" = {
                    type = "login_box";
                    output = name;
                    cx = w / 2.0;
                    cy = h / 2.0 + 120.0;
                    settings = {
                      layout = "compact";
                      background_opacity = 0.0;
                      input_opacity = 0.92;
                      input_radius = 32.0;
                      center_password_text = true;
                      show_password_reveal = false;
                      show_login_button = false;
                      # no hints nor layout chip: errors and Caps Lock still show
                      show_unlock_hint = false;
                      show_keyboard_layout = false;
                    };
                  };
                  # the time large and light in the accent, nothing around it
                  "lockscreen-clock@${name}" = at name (w / 2.0) (h / 2.0 - 150.0) 560.0 180.0 "clock" (
                    clock "{:%H:%M}" "Geist Light" "primary"
                  );
                  "lockscreen-date@${name}" = at name (w / 2.0) (h / 2.0 + 10.0) 560.0 40.0 "clock" (
                    clock "{:%A, %d de %B}" "Geist" "on_surface"
                  );
                  "lockscreen-media@${name}" = at name (w / 2.0) (h - 110.0) 460.0 96.0 "media_player" (
                    pill // { hide_when_no_media = true; }
                  );
                  "lockscreen-suspend@${name}" = at name (w - 168.0) (h - 56.0) 48.0 48.0 "button" (
                    icon "moon" "systemctl suspend"
                  );
                  "lockscreen-reboot@${name}" = at name (w - 112.0) (h - 56.0) 48.0 48.0 "button" (
                    icon "refresh" "systemctl reboot"
                  );
                  "lockscreen-poweroff@${name}" = at name (w - 56.0) (h - 56.0) 48.0 48.0 "button" (
                    icon "power" "systemctl poweroff"
                  );
                };
            widget = screen "eDP-1" 1920.0 1200.0 // screen "HDMI-A-1" 1080.0 1920.0;
          in
          {
            enabled = true;
            inherit widget;
            widget_order = lib.attrNames widget;
          };

        # the desktop monitor has no kernel backlight: DDC/CI (system/desktop)
        brightness.enable_ddcutil = true;

        # a notification at 20% and lower (critical): UPower's low level
        # (system/hardware); at 3% it shuts down
        battery.warning_threshold = 20;

        # local Nix-built plugins only; no git sources or background updates
        plugins = {
          enabled = map (name: "dotnix/${name}") (lib.attrNames plugins);
          auto_update = "none";
          source = [
            {
              name = "official";
              kind = "git";
              location = "https://github.com/noctalia-dev/official-plugins";
              enabled = false;
            }
            {
              name = "dotnix";
              kind = "path";
              location = "${dotnixPlugins}";
              enabled = true;
            }
          ];
        };

        # the theme tile, and on a laptop its power profiles (performance,
        # balanced, power saver: tlp-pd) in place of the night light
        control_center.shortcuts = map (type: { inherit type; }) [
          "wifi"
          "bluetooth"
          "caffeine"
          (if laptop then "power_profile" else "nightlight")
          "notification"
          "dotnix/theme:theme" # the home grid shows at most 6
        ];

        # the bar/settings toggle switches the whole system theme
        hooks.theme_mode_changed = "${lib.getExe config.dotnix.theme.package} noctalia-mode $NOCTALIA_THEME_MODE";
      };
    };
  };
}
