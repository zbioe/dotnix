# dotnix's themes for the GNOME session (dotnix.desktop.gnome.windowsLike):
# every theme/mode pair the main account's `theme` renders (home/theme, its
# index: GTK 3/4 CSS, the wallpaper) plus a GNOME Shell stylesheet in its
# palette, picked from Quick Settings (gnome-themes/extension.js) and applied
# by dotnix-gnome-theme to the whole session: GTK, the shell, the taskbar,
# the start menu, the icons' and accents' shade, the wallpaper. Each account
# has its own theme, in its home.
{
  config,
  lib,
  pkgs,
  base16,
  homes,
  ...
}:
let
  cfg = config.dotnix.desktop;
  hostHome = homes.${config.networking.hostName} or null;
  enabled =
    cfg.enable
    && cfg.gnome.enable
    && cfg.gnome.windowsLike != [ ]
    && hostHome != null
    && hostHome.config.dotnix.theme.enable;
  index = hostHome.config.dotnix.theme.index;
  themes = import ../../home/theme/themes.nix { inherit pkgs; };
  inherit (base16.lib { inherit pkgs lib; }) mkSchemeAttrs;
  default = {
    name = "catppuccin";
    mode = "dark";
  };

  variants = lib.concatLists (
    lib.mapAttrsToList (
      name: theme:
      map (mode: {
        inherit name mode;
        id = "${name}-${mode}";
        c = (mkSchemeAttrs theme.schemes.${mode}).withHashtag;
      }) (lib.attrNames theme.schemes)
    ) themes
  );

  # GNOME's accent: the named one nearest base0D's hue (slate when grey)
  accentOf =
    hex:
    let
      byte = i: lib.fromHexString (builtins.substring (1 + 2 * i) 2 hex);
      r = byte 0;
      g = byte 1;
      b = byte 2;
      max = lib.max r (lib.max g b);
      min = lib.min r (lib.min g b);
      d = max - min;
      h0 =
        if d == 0 then
          0
        else if max == r then
          60 * (g - b) / d
        else if max == g then
          120 + 60 * (b - r) / d
        else
          240 + 60 * (r - g) / d;
      hue = if h0 < 0 then h0 + 360 else h0;
    in
    if d * 100 < max * 20 then
      "slate"
    else if hue < 15 || hue >= 345 then
      "red"
    else if hue < 40 then
      "orange"
    else if hue < 65 then
      "yellow"
    else if hue < 160 then
      "green"
    else if hue < 195 then
      "teal"
    else if hue < 255 then
      "blue"
    else if hue < 290 then
      "purple"
    else
      "pink";

  # the shell in the palette: round surfaces, the accent where GNOME puts it
  shellCss =
    { mode, c, ... }:
    with c;
    ''
      @import url("resource:///org/gnome/shell/theme/gnome-shell-${mode}.css");

      stage { font-family: "Inter"; }

      .popup-menu-content, .quick-settings, .candidate-popup-content,
      .datemenu-popover, .message-list, .switcher-list, .osd-window,
      .resize-popup, .modal-dialog, .workspace-switcher {
        background-color: ${base00};
        color: ${base05};
        border: 1px solid ${base02};
        border-radius: 18px;
        box-shadow: 0 6px 18px rgba(0, 0, 0, 0.25);
      }
      .popup-menu-item { border-radius: 10px; color: ${base05}; }
      .popup-menu-item:hover, .popup-menu-item:focus, .popup-menu-item:active,
      .popup-menu-item.selected { background-color: ${base02}; color: ${base05}; }
      .popup-separator-menu-item .popup-separator-menu-item-separator { background-color: ${base02}; }

      .quick-toggle, .quick-menu-toggle .quick-toggle-arrow {
        background-color: ${base01};
        color: ${base05};
      }
      .quick-toggle:hover, .quick-menu-toggle .quick-toggle-arrow:hover { background-color: ${base02}; }
      .quick-toggle:checked, .quick-menu-toggle .quick-toggle-arrow:checked,
      .quick-toggle:checked:hover {
        background-color: ${base0D};
        color: ${base00};
      }
      .quick-toggle-menu { background-color: ${base01}; color: ${base05}; border-radius: 18px; }
      .quick-settings-system-item .icon-button, .quick-settings .icon-button,
      .message-list .icon-button {
        background-color: ${base01};
        color: ${base05};
      }
      .quick-settings .icon-button:hover { background-color: ${base02}; }

      .slider {
        -barlevel-background-color: ${base02};
        -barlevel-active-background-color: ${base0D};
        -barlevel-overdrive-color: ${base08};
        -slider-handle-border-color: ${base0D};
        color: ${base05};
      }
      .toggle-switch { background-color: ${base02}; }
      .toggle-switch:checked { background-color: ${base0D}; }

      .button, .modal-dialog-button, .notification-button, .hotplug-notification-item {
        background-color: ${base01};
        color: ${base05};
        border-radius: 12px;
      }
      .button:hover, .modal-dialog-button:hover, .notification-button:hover { background-color: ${base02}; }
      .button.default, .modal-dialog-button.default {
        background-color: ${base0D};
        color: ${base00};
      }
      .modal-dialog .modal-dialog-button-box { background-color: ${base01}; }

      .message, .notification-banner, .unlock-dialog-notifications-container .message {
        background-color: ${base01};
        color: ${base05};
        border-radius: 14px;
      }
      .message:hover { background-color: ${base02}; }
      .message .message-title, .message .message-body { color: ${base05}; }

      .calendar, .events-button, .world-clocks-button, .weather-button {
        background-color: ${base01};
        color: ${base05};
        border-radius: 14px;
      }
      .calendar-day-base:hover { background-color: ${base02}; }
      .calendar-today, .calendar-today:selected, .calendar-day-base:selected {
        background-color: ${base0D};
        color: ${base00};
      }

      .search-entry, StEntry {
        background-color: ${base01};
        color: ${base05};
        caret-color: ${base0D};
        selection-background-color: ${base0D};
        selected-color: ${base00};
      }
      StEntry:focus { border-color: ${base0D}; }

      .switcher-list .item-box:selected, .switcher-list .item-box:hover {
        background-color: ${base02};
      }
      .osd-window .level { -barlevel-active-background-color: ${base0D}; -barlevel-background-color: ${base02}; }
    '';

  # share/themes/nix-<id>: GTK from the index, the shell from here
  themePackage = pkgs.runCommandLocal "gnome-themes" { } ''
    ${lib.concatMapStrings (v: ''
      dir=$out/share/themes/nix-${v.id}
      mkdir -p $dir/gnome-shell
      ln -s ${index}/${v.id}/gtk-theme/gtk-3.0 $dir/gtk-3.0
      ln -s ${index}/${v.id}/gtk-theme/gtk-4.0 $dir/gtk-4.0
      cp ${pkgs.writeText "gnome-shell-${v.id}.css" (shellCss v)} $dir/gnome-shell/gnome-shell.css
    '') variants}
  '';

  # what the picker lists and the applier reads: per theme and mode, the
  # colors and GNOME's accent name
  catalog = map (name: {
    inherit name;
    label = lib.concatMapStringsSep " " (
      w: lib.toUpper (builtins.substring 0 1 w) + builtins.substring 1 (-1) w
    ) (lib.splitString "-" name);
    modes = lib.listToAttrs (
      map (v: {
        name = v.mode;
        value = with v.c; {
          bg = base00;
          surface = base01;
          line = base02;
          muted = base04;
          fg = base05;
          accent = base0D;
          red = base08;
          green = base0B;
          yellow = base0A;
          gnomeAccent = accentOf base0D;
        };
      }) (builtins.filter (v: v.name == name) variants)
    );
  }) (lib.attrNames themes);
  catalogFile = pkgs.writeText "themes.json" (builtins.toJSON catalog);

  picker =
    pkgs.runCommand "gnome-shell-extension-dotnix-themes"
      { passthru.extensionUuid = "dotnix-themes@dotnix"; }
      ''
        dir=$out/share/gnome-shell/extensions/dotnix-themes@dotnix
        mkdir -p $dir
        cp ${./gnome-themes/metadata.json} $dir/metadata.json
        cp ${./gnome-themes/extension.js} $dir/extension.js
        cp ${catalogFile} $dir/themes.json
      '';

  # the account's side: its theme in its home and its dconf (the taskbar's
  # and the menu's colors too); with --init only when it has none yet
  apply = pkgs.writeShellApplication {
    name = "dotnix-gnome-theme";
    runtimeInputs = with pkgs; [
      coreutils
      dconf
      jq
    ];
    text = ''
      state=''${XDG_STATE_HOME:-$HOME/.local/state}/gnome-theme
      if [ "''${1:-}" = --init ]; then
        [ -e "$state/name" ] && exit 0
        set -- ${default.name} ${default.mode}
      fi
      name=''${1:?theme name}
      mode=''${2:?dark or light}
      variant=${index}/$name-$mode
      [ -d "$variant" ] || { echo "no theme $name ($mode)" >&2; exit 2; }
      pal=$(jq -ec --arg n "$name" --arg m "$mode" '.[] | select(.name == $n) | .modes[$m]' ${catalogFile})
      color() { jq -r ".$1" <<< "$pal"; }
      w() { dconf write "$1" "$2"; }
      str() { printf "'%s'" "$1"; }

      mkdir -p "$state" "$HOME/.config/gtk-4.0"
      ln -sfn "$variant/gtk4.css" "$HOME/.config/gtk-4.0/gtk.css"

      i=/org/gnome/desktop/interface
      w $i/gtk-theme "$(str "nix-$name-$mode")"
      w $i/color-scheme "$(str "prefer-$mode")"
      w $i/accent-color "$(str "$(color gnomeAccent)")"
      w $i/icon-theme "$(str "Tela-$mode")"
      w /org/gnome/shell/extensions/user-theme/name "$(str "nix-$name-$mode")"
      for k in picture-uri picture-uri-dark; do
        w /org/gnome/desktop/background/$k "$(str "file://$variant/wallpaper.png")"
      done
      w /org/gnome/desktop/screensaver/picture-uri "$(str "file://$variant/wallpaper.png")"

      t=/org/gnome/shell/extensions/dash-to-panel
      w $t/trans-use-custom-bg true
      w $t/trans-bg-color "$(str "$(color bg)")"
      w $t/trans-use-custom-opacity true
      w $t/trans-panel-opacity 0.94
      w $t/dot-color-override true
      for n in 1 2 3 4; do w $t/dot-color-$n "$(str "$(color accent)")"; done
      w $t/focus-highlight-color "$(str "$(color accent)")"

      a=/org/gnome/shell/extensions/arcmenu
      w $a/override-menu-theme true
      w $a/menu-background-color "$(str "$(color bg)")"
      w $a/menu-foreground-color "$(str "$(color fg)")"
      w $a/menu-border-color "$(str "$(color line)")"
      w $a/menu-separator-color "$(str "$(color line)")"
      w $a/menu-item-hover-bg-color "$(str "$(color line)")"
      w $a/menu-item-hover-fg-color "$(str "$(color fg)")"
      w $a/menu-item-active-bg-color "$(str "$(color accent)")"
      w $a/menu-item-active-fg-color "$(str "$(color bg)")"

      echo "$name" > "$state/name"
      echo "$mode" > "$state/mode"
    '';
  };
in
{
  config = lib.mkIf enabled {
    environment.systemPackages = [
      themePackage
      apply
    ];
    dotnix.desktop.gnome.extensions = [
      picker
      pkgs.gnomeExtensions.user-themes
    ];

    # their theme the first time (catppuccin, dark), at login
    systemd.user.services.dotnix-gnome-theme = {
      description = "The account's dotnix theme, the first time";
      wantedBy = [ "gnome-session-initialized.target" ];
      after = [ "gnome-session-initialized.target" ];
      unitConfig.ConditionUser = map (name: "|${name}") cfg.gnome.windowsLike;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe apply} --init";
      };
    };
  };
}
