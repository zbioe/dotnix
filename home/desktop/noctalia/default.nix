# Noctalia: bar, launcher, notifications and lock screen of the mango session.
# Its colors follow `theme`, and its dark/light toggle drives `theme` back.
{
  config,
  lib,
  pkgs,
  ...
}:
let
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

        # app_icon_colorize comes from `theme icons tint` (home/theme/icons)

        # everything here is declared: no first-run wizard (it shows on every
        # fresh home: the live ISO, a new install)
        shell.setup_wizard_enabled = false;

        # Activate emacs shortcuts
        shell.readline_shortcuts = true;

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
            "clock"
            "battery"
            "control-center"
          ];
        };

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
          # a glyph, so it follows the icon pack
          battery = {
            show_label = false;
            display_mode = "glyph";
          };

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

        # both follow [location] (GeoClue, see noctalia-locate above)
        weather.enabled = true;
        nightlight.enabled = true;

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

        # the desktop monitor has no kernel backlight: DDC/CI (system/desktop)
        brightness.enable_ddcutil = true;

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

        # defaults with the theme tile in place of power profiles (desktop)
        control_center.shortcuts = map (type: { inherit type; }) [
          "wifi"
          "bluetooth"
          "caffeine"
          "nightlight"
          "notification"
          "dotnix/theme:theme" # the home grid shows at most 6
        ];

        # the bar/settings toggle switches the whole system theme
        hooks.theme_mode_changed = "${lib.getExe config.dotnix.theme.package} noctalia-mode $NOCTALIA_THEME_MODE";
      };
    };
  };
}
