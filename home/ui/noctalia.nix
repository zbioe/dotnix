# Noctalia: shell for the mango session (started from home/ui/mango.nix).
# The bar keeps the shape of the Hyprland waybar (home/ui/waybar.nix): a thin
# strip on top, no shadow or rounding, tags in use only with the same icons,
# the NixOS logo as the launcher. Colors come from `theme` (home/theme): one
# palette per theme, switched by `theme apply`; noctalia's own dark/light
# toggle drives `theme` back.
{
  config,
  lib,
  pkgs,
  noctalia,
  ...
}:
let
  # same icons as the waybar workspaces (home/ui/waybar.nix)
  icons = config.programs.waybar.settings.mainBar."hyprland/workspaces".format-icons;
  workspaceIcons = lib.concatMapStringsSep "," (n: "${toString n}=${icons.${toString n}}") (
    lib.range 1 10
  );

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
      ${lib.getExe config.theme.package} auto-tick
      echo "noctalia-locate: $lat $lon"
    '';
  };

  # local plugins (noctalia-plugins/): "dotnix/theme", the theme panel and
  # control center tile; "dotnix/wifi", the Wi-Fi priority panel
  dotnixPlugins =
    let
      swatchesOf =
        scheme:
        let
          c = (config.stylix.base16.mkSchemeAttrs scheme).withHashtag;
        in
        [
          c.base00
          c.base05
          c.base08
          c.base0A
          c.base0B
          c.base0D
          c.base0E
        ];
      themesJson = (pkgs.formats.json { }).generate "themes.json" {
        theme = lib.getExe config.theme.package;
        state = "${config.xdg.stateHome}/theme";
        themes = lib.mapAttrsToList (
          name: theme: { inherit name; } // lib.mapAttrs (_: swatchesOf) theme.schemes
        ) config.theme.themes;
      };
      wifiJson = (pkgs.formats.json { }).generate "wifi.json" {
        command = "${config.home.profileDirectory}/bin/wifi-prefer";
      };
      wifiManifest = (pkgs.formats.toml { }).generate "plugin.toml" {
        id = "dotnix/wifi";
        name = "Wi-Fi Priority";
        version = "1.0.0";
        plugin_api = 26;
        author = "dotnix";
        license = "MIT";
        icon = "wifi";
        description = "Order of the saved Wi-Fi networks for the dotnix `wifi-prefer` command.";
        panel = [
          {
            id = "priority";
            entry = "priority.luau";
            width = 380;
            height = 460;
            placement = "attached";
            position = "auto";
          }
        ];
      };
      keysManifest = (pkgs.formats.toml { }).generate "plugin.toml" {
        id = "dotnix/keys";
        name = "Shortcuts";
        version = "1.0.0";
        plugin_api = 26;
        author = "dotnix";
        license = "MIT";
        icon = "keyboard";
        description = "Every mango bind with what it does (home/ui/mango.nix).";
        panel = [
          {
            id = "list";
            entry = "list.luau";
            width = 560;
            height = 720;
            placement = "attached";
            position = "auto";
          }
        ];
      };
      manifest = (pkgs.formats.toml { }).generate "plugin.toml" {
        id = "dotnix/theme";
        name = "Themes";
        version = "1.0.0";
        plugin_api = 26;
        author = "dotnix";
        license = "MIT";
        icon = "palette";
        description = "Theme picker for the dotnix `theme` command.";
        panel = [
          {
            id = "picker";
            entry = "picker.luau";
            width = 420;
            height = 640;
            placement = "attached";
            position = "auto";
          }
        ];
        shortcut = [
          {
            id = "theme";
            entry = "shortcut.luau";
          }
        ];
      };
    in
    pkgs.runCommandLocal "noctalia-plugins" { } ''
      mkdir -p $out/theme $out/wifi $out/keys
      cp ${./noctalia-plugins/theme}/*.luau $out/theme/
      cp ${manifest} $out/theme/plugin.toml
      cp ${themesJson} $out/theme/themes.json
      cp ${./noctalia-plugins/wifi}/*.luau $out/wifi/
      cp ${wifiManifest} $out/wifi/plugin.toml
      cp ${wifiJson} $out/wifi/wifi.json
      cp ${./noctalia-plugins/keys}/*.luau $out/keys/
      cp ${keysManifest} $out/keys/plugin.toml
      cp ${config.xdg.configFile."mango/keys.json".source} $out/keys/keys.json
    '';
in
{
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
    # label_map: per-workspace labels (icons); tray-menu: a tray item's menu
    # from any widget (see the patches)
    package = noctalia.overrideAttrs (old: {
      patches = (old.patches or [ ]) ++ [
        ../../patches/noctalia-workspace-label-map.patch
        ../../patches/noctalia-tray-menu.patch
      ];
    });
    customPalettes = config.theme.noctaliaPalettes;
    settings = {
      theme = {
        source = "custom";
        custom_palette = "nix-${config.theme.default.name}";
        inherit (config.theme.default) mode;
      };

      # tray and window icons drawn in the theme's colors (Discord's white
      # tray icon included); the launcher keeps the full-color Papirus set
      shell.app_icon_colorize = true;

      # session menu (the power button of the control center): the defaults,
      # plus the system + home switch in a floating terminal (home/ui/rebuild.nix)
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
          label_map = workspaceIcons;
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
        # icons only, like the waybar (details on hover / in the panels)
        network = {
          show_label = false;
          # nm-applet's menu (VPN, ethernet, ...), hidden from the tray below
          actions.right = "tray-menu nm-applet";
          # order of the saved Wi-Fi networks (home/ui/wifi-prefer.nix)
          actions.middle = "panel-toggle dotnix/wifi:priority";
        };
        volume.show_label = false;
        battery.show_label = false;

        # fcitx's "us" says nothing (fixed layout); network and bluetooth
        # already have their own widgets
        tray.hidden = [
          "fcitx"
          "nm-applet"
          "blueman"
        ];

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
          tooltip = "Themes";
          actions.left = "panel-toggle dotnix/theme:picker";
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

      # the desktop monitor has no kernel backlight: DDC/CI (default/ui.nix)
      brightness.enable_ddcutil = true;

      # local Nix-built plugins only; no git sources or background updates
      plugins = {
        enabled = [
          "dotnix/theme"
          "dotnix/wifi"
          "dotnix/keys"
        ];
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
      hooks.theme_mode_changed = "${lib.getExe config.theme.package} mode $NOCTALIA_THEME_MODE";
    };
  };
}
