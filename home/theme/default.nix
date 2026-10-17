# Live theme switching.
#
# Every theme/mode pair is rendered at build time into its own store path
# (GTK 3/4 CSS, terminal colors, Qt, browsers, emacs). `theme` only moves
# symlinks and pokes the running apps, so switching is instant and nothing is
# generated at runtime. GTK4/libadwaita apps follow the swap thanks to
# patches/gtk4-reload-user-css.patch (applied system-wide in default/ui.nix).
{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:
let
  cfg = config.theme;
  inherit (lib) mkOption types;

  base16 = config.stylix.base16;

  stateDir = "${config.xdg.stateHome}/theme";

  # the settings.ini home-manager would write (cursor, key theme...); `theme`
  # writes them itself with the active theme, icons and dark preference
  gtkSettings = pkgs.runCommandLocal "gtk-settings" { } ''
    mkdir $out
    cp ${pkgs.writeText "gtk3" config.xdg.configFile."gtk-3.0/settings.ini".text} $out/gtk-3.0.ini
    cp ${pkgs.writeText "gtk4" config.xdg.configFile."gtk-4.0/settings.ini".text} $out/gtk-4.0.ini
  '';

  brave = config.programs.brave.enable;
  braveTheme = pkgs.callPackage ../../pkgs/brave-theme { brave = unstable.brave; };

  variants = lib.concatMap (
    name:
    map (mode: {
      inherit name mode;
      id = "${name}-${mode}";
      theme = cfg.themes.${name};
    }) (lib.attrNames cfg.themes.${name}.schemes)
  ) (lib.attrNames cfg.themes);

  mkVariant =
    {
      id,
      mode,
      theme,
      ...
    }:
    let
      colors = base16.mkSchemeAttrs theme.schemes.${mode};
      c = colors.withHashtag;
      bases = map (n: "base0${n}") [
        "0"
        "1"
        "2"
        "3"
        "4"
        "5"
        "6"
        "7"
        "8"
        "9"
        "A"
        "B"
        "C"
        "D"
        "E"
        "F"
      ];

      gtkCss = colors {
        template = ./gtk.css.mustache;
        extension = ".css";
      };
      adwGtk3 = "${pkgs.adw-gtk3}/share/themes/adw-gtk3${lib.optionalString (mode == "dark") "-dark"}";

      # terminal palette, same mapping as stylix's foot target
      ansi = with c; [
        base00
        base08
        base0B
        base0A
        base0D
        base0E
        base0C
        base05
        base03
        base08
        base0B
        base0A
        base0D
        base0E
        base0C
        base07
      ];
      footColors = ''
        foreground=${colors.base05}
        background=${colors.base00}
        ${lib.concatImapStrings (
          i: color:
          let
            n = i - 1;
          in
          "${
            if n < 8 then "regular${toString n}" else "bright${toString (n - 8)}"
          }=${lib.removePrefix "#" color}\n"
        ) ansi}
      '';
      osc = code: value: "\\033]${code};${value}\\007";
      termSeq = lib.concatStrings (
        [
          (osc "10" c.base05)
          (osc "11" c.base00)
          (osc "12" c.base05)
          (osc "17" c.base02)
          (osc "19" c.base05)
        ]
        ++ lib.imap0 (i: color: osc "4;${toString i}" color) ansi
      );

      emacsTheme =
        if theme.emacs.${mode} or null != null then
          ''
            (setq doom-theme '${theme.emacs.${mode}})
          ''
        else
          ''
            (add-to-list 'custom-theme-load-path "${placeholder "out"}/emacs")
            (setq doom-theme 'base16-nix-${id})
          '';
      # Brave's theme extension (pkgs/brave-theme): one surface in the
      # background color, as the bar above it: tab strip, tabs (the active one
      # told apart by its text in the accent) and toolbar. The address bar's
      # dropdown is outlined by its page (webui-theme/brave.css); its window
      # (omnibox_background) is made transparent in the pack (brave-theme).
      braveColors = with c; {
        frame = base00;
        frame_inactive = base00;
        background_tab = base00;
        background_tab_inactive = base00;
        toolbar = base00;
        toolbar_text = base05;
        toolbar_button_icon = base05;
        tab_text = base0D;
        tab_background_text = base04;
        bookmark_text = base05;
        omnibox_text = base05;
        omnibox_background = base00;
        ntp_background = base00;
        ntp_text = base05;
        ntp_link = base0D;
      };

      # browser UI (WebExtension theme API) and Dark Reader, see pkgs/nix-theme
      browserJson = pkgs.writeText "browser-${id}.json" (
        builtins.toJSON {
          # names the page fallback the Chromium side registers (pkgs/nix-theme)
          inherit id;
          browser = {
            colors = with c; {
              frame = base00;
              frame_inactive = base00;
              tab_background_text = base04;
              tab_selected = base00;
              tab_text = base05;
              tab_line = base0D;
              tab_loading = base0D;
              toolbar = base00;
              toolbar_text = base05;
              toolbar_top_separator = base00;
              toolbar_bottom_separator = base02;
              toolbar_field = base00;
              toolbar_field_text = base05;
              toolbar_field_border = base02;
              toolbar_field_focus = base00;
              toolbar_field_text_focus = base05;
              toolbar_field_border_focus = base0D;
              toolbar_field_highlight = base02;
              toolbar_field_highlight_text = base05;
              icons = base05;
              icons_attention = base0D;
              button_background_hover = base02;
              button_background_active = base03;
              popup = base00;
              popup_text = base05;
              popup_border = base02;
              popup_highlight = base02;
              popup_highlight_text = base05;
              sidebar = base00;
              sidebar_text = base05;
              sidebar_border = base02;
              sidebar_highlight = base02;
              sidebar_highlight_text = base05;
              ntp_background = base00;
              ntp_text = base05;
              # new tab search box and cards
              ntp_card_background = base01;
            };
            properties = {
              color_scheme = mode;
              content_color_scheme = mode;
            };
          };
          darkreader = with c; {
            mode = if mode == "dark" then 1 else 0;
            darkSchemeBackgroundColor = base00;
            darkSchemeTextColor = base05;
            lightSchemeBackgroundColor = base00;
            lightSchemeTextColor = base05;
            selectionColor = base02;
            # none: the page scrollbars come from pkgs/nix-theme (its own,
            # derived from one color, gets a dark track on light themes)
            scrollbarColor = "";
            # no filters on top: the palette exactly as it is
            brightness = 100;
            contrast = 100;
            sepia = 0;
            grayscale = 0;
          };
        }
      );
      # mango (home/ui/mango.nix sources this); colors are 0xRRGGBBAA
      mangoConf = with colors; ''
        root_color=0x${base00}ff
        border_color=0x${base02}ff
        focus_color=0x${base0D}ff
        urgent_color=0x${base08}ff
        maximized_screen_color=0x${base0B}ff
        scratchpad_color=0x${base0E}ff
        global_color=0x${base0C}ff
        overlay_color=0x${base0A}ff
        drop_color=0x${base0D}55
        split_color=0x${base09}ff
        jump_label_decorate_fg_color=0x${base05}ff
        jump_label_decorate_bg_color=0x${base01}ff
        jump_label_decorate_focus_fg_color=0x${base00}ff
        jump_label_decorate_focus_bg_color=0x${base0D}ff
        jump_label_decorate_border_color=0x${base0D}ff
      '';
      # NixOS snowflake art in the theme colors (shared with the boot screens)
      inherit (import ./art.nix { inherit pkgs lib colors; }) wallpaper;
      fishColors = with colors; ''
        set -g fish_color_autosuggestion ${base03}
        set -g fish_color_cancel -r
        set -g fish_color_command green
        set -g fish_color_comment ${base03}
        set -g fish_color_cwd green
        set -g fish_color_cwd_root red
        set -g fish_color_end brblack
        set -g fish_color_error red
        set -g fish_color_escape yellow
        set -g fish_color_history_current --bold
        set -g fish_color_host normal
        set -g fish_color_match --background=brblue
        set -g fish_color_normal normal
        set -g fish_color_operator blue
        set -g fish_color_param ${base04}
        set -g fish_color_quote yellow
        set -g fish_color_redirection cyan
        set -g fish_color_search_match bryellow --background=${base02}
        set -g fish_color_selection white --bold --background=${base02}
        set -g fish_color_status red
        set -g fish_color_user brgreen
        set -g fish_color_valid_path --underline
        set -g fish_pager_color_completion normal
        set -g fish_pager_color_description yellow --dim
        set -g fish_pager_color_prefix white --bold
        set -g fish_pager_color_progress brwhite --background=cyan
      '';
      kittyConf = ''
        foreground ${c.base05}
        background ${c.base00}
        selection_foreground ${c.base05}
        selection_background ${c.base02}
        cursor ${c.base05}
        cursor_text_color ${c.base00}
        url_color ${c.base0D}
        active_border_color ${c.base0D}
        inactive_border_color ${c.base02}
        active_tab_foreground ${c.base05}
        active_tab_background ${c.base02}
        inactive_tab_foreground ${c.base04}
        inactive_tab_background ${c.base01}
        ${lib.concatImapStrings (i: color: "color${toString (i - 1)} ${color}\n") ansi}
      '';
      ghosttyConf = ''
        background = ${c.base00}
        foreground = ${c.base05}
        cursor-color = ${c.base05}
        selection-background = ${c.base02}
        selection-foreground = ${c.base05}
        ${lib.concatImapStrings (i: color: "palette = ${toString (i - 1)}=${color}\n") ansi}
      '';
      alacrittyToml =
        let
          names = [
            "black"
            "red"
            "green"
            "yellow"
            "blue"
            "magenta"
            "cyan"
            "white"
          ];
          group =
            offset:
            lib.listToAttrs (lib.imap0 (i: n: lib.nameValuePair n (lib.elemAt ansi (i + offset))) names);
        in
        (pkgs.formats.toml { }).generate "alacritty-${id}.toml" {
          colors = {
            primary = {
              background = c.base00;
              foreground = c.base05;
            };
            cursor = {
              text = c.base00;
              cursor = c.base05;
            };
            selection = {
              text = c.base05;
              background = c.base02;
            };
            normal = group 0;
            bright = group 8;
          };
        };
      # Discord through Vencord (default/packages.nix): its themes folder is
      # watched, so `theme` copying this file in restyles it live. Discord
      # mixes every color from a few scales (neutral-1..100 light to dark,
      # primary-100..900, brand/blurple), so the scales are redrawn from the
      # palette and everything built on them follows, whichever light/dark
      # Discord itself is set to.
      discordCss =
        let
          # past the background: darker sidebars on dark palettes, the
          # palette's own tints on light ones
          beyond =
            if mode == "dark" then
              [
                [
                  78
                  "color-mix(in oklab, ${c.base00}, #000 35%)"
                ]
                [
                  100
                  "color-mix(in oklab, ${c.base00}, #000 70%)"
                ]
              ]
            else
              [
                [
                  78
                  c.base01
                ]
                [
                  100
                  c.base02
                ]
              ];
          # neutral index -> color, along Discord's use of the scale.
          # Discord dark: text 1-27, popouts 60-62, chat 64, sidebars 66-78
          onDark = [
            [
              0
              c.base07
            ]
            [
              1
              c.base06
            ]
            [
              4
              c.base05
            ]
            [
              16
              c.base04
            ]
            [
              27
              c.base03
            ]
            [
              45
              c.base02
            ]
            [
              60
              c.base01
            ]
            [
              64
              c.base00
            ]
          ]
          ++ beyond;
          # Discord light: chat 1, sidebars 2-7, muted text 41-47, text 72-76
          onLight = [
            [
              0
              c.base00
            ]
            [
              1
              c.base00
            ]
            [
              7
              c.base01
            ]
            [
              25
              c.base02
            ]
            [
              33
              c.base03
            ]
            [
              45
              c.base04
            ]
            [
              72
              c.base05
            ]
            [
              76
              c.base06
            ]
            [
              100
              c.base07
            ]
          ];
          # color at index n: mixed between the anchors around it
          at =
            anchors: n:
            let
              hi = lib.findFirst (a: lib.head a >= n) (lib.last anchors) anchors;
              lo = lib.findFirst (a: lib.head a <= n) (lib.head anchors) (lib.reverseList anchors);
              span = lib.head hi - lib.head lo;
              pct = if span == 0 then 0 else (n - lib.head lo) * 100 / span;
            in
            if pct == 0 then
              lib.last lo
            else
              "color-mix(in oklab, ${lib.last lo}, ${lib.last hi} ${toString pct}%)";
          # accent shades: low numbers lighter, high darker
          accent =
            n: max:
            let
              mid = max / 2;
              pct = (if n < mid then mid - n else n - mid) * 80 / mid;
            in
            "color-mix(in oklab, ${c.base0D}, ${if n < mid then "#fff" else "#000"} ${toString pct}%)";
          scale = [
            100
            130
            160
            200
            230
            260
            300
            330
            345
            360
            400
            430
            460
            500
            530
            560
            600
            630
            645
            660
            700
            730
            760
            800
            830
            860
            900
          ];
          decl = name: value: "  --${name}: ${value} !important;";
          scales =
            selector: anchors:
            [ "${selector} {" ]
            ++ map (n: decl "neutral-${toString n}" (at anchors n)) (lib.range 1 100)
            ++ map (n: decl "primary-${toString n}" (at anchors (n * 100 / 940))) scale
            ++ map (n: decl "brand-${toString n}" (accent n 1000)) scale
            ++ map (n: decl "blurple-${toString n}" (accent n 100)) (lib.range 1 100)
            ++ [
              (decl "white" (lib.last (lib.head anchors)))
              "}"
            ];
        in
        lib.concatStringsSep "\n" (
          [
            "/**"
            " * @name nix-theme"
            " * @description Active dotnix theme (${id}), written by `theme`."
            " * @author dotnix"
            " */"
          ]
          ++ scales ":root, .theme-dark, .theme-darker, .theme-midnight" onDark
          ++ scales ".theme-light" onLight
          ++ [
            ":root, .custom-theme-background {"
            # Discord's own gradient "app themes" tint everything; keep the palette
            (decl "custom-theme-base-color-amount" "0%")
            (decl "custom-theme-text-color-amount" "0%")
            (decl "custom-theme-border-color-amount" "0%")
            (decl "custom-theme-background" c.base00) # under the see-through panels
          ]
          # and the white/black veils they lay over each surface
          ++ map (n: decl "background-gradient-${n}" "none") [
            "app-frame"
            "chat"
            "chat-preview"
            "low"
            "lower"
            "lowest"
            "high"
            "higher"
            "highest"
          ]
          ++ [
            (decl "text-link" c.base0D)
            (decl "text-brand" c.base0D)
            (decl "control-brand-foreground" c.base0D)
            (decl "control-brand-foreground-new" c.base0D)
            (decl "mention-foreground" c.base0A)
            (decl "mention-background" "${c.base0A}22")
            (decl "status-danger" c.base08)
            (decl "status-positive" c.base0B)
            (decl "status-warning" c.base0A)
            (decl "text-feedback-critical" c.base08)
            (decl "text-feedback-positive" c.base0B)
            (decl "text-feedback-warning" c.base0A)
            "}"
          ]
        );

      # Qt (qt5ct/qt6ct, Fusion style): palette roles in QPalette::ColorRole order
      qtRoles = with c; [
        base05 # WindowText
        base01 # Button
        base03 # Light
        base02 # Midlight
        base00 # Dark
        base02 # Mid
        base05 # Text
        base07 # BrightText
        base05 # ButtonText
        base00 # Base
        base00 # Window
        base00 # Shadow
        base0D # Highlight
        base00 # HighlightedText
        base0D # Link
        base0E # LinkVisited
        base01 # AlternateBase
        base00 # NoRole
        base01 # ToolTipBase
        base05 # ToolTipText
        base03 # PlaceholderText
        base0D # Accent (Qt 6 only)
      ];
      qtDisabled = lib.imap0 (
        i: color:
        if
          lib.elem i [
            0
            6
            8
          ]
        then
          c.base03
        else
          color
      ) qtRoles;
      qtColors =
        n:
        let
          join = roles: lib.concatStringsSep ", " (lib.take n roles);
        in
        ''
          [ColorScheme]
          active_colors=${join qtRoles}
          disabled_colors=${join qtDisabled}
          inactive_colors=${join qtRoles}
        '';
      qtctConf = qt: ''
        [Appearance]
        color_scheme_path=${placeholder "out"}/${qt}-colors.conf
        custom_palette=true
        icon_theme=${if mode == "dark" then cfg.icons.dark else cfg.icons.light}
        standard_dialogs=xdgdesktopportal
        style=Fusion

        [Fonts]
        fixed="${config.stylix.fonts.monospace.name},${toString config.stylix.fonts.sizes.applications}"
        general="${config.stylix.fonts.sansSerif.name},${toString config.stylix.fonts.sizes.applications}"
      '';
      emacsBase16 = ''
        (require 'base16-theme)
        (defvar base16-nix-${id}-theme-colors
          '(${lib.concatMapStringsSep "\n    " (b: ":${b} \"${c.${b}}\"") bases})
          "Colors of the ${id} theme.")
        (deftheme base16-nix-${id})
        (base16-theme-define 'base16-nix-${id} base16-nix-${id}-theme-colors)
        (provide-theme 'base16-nix-${id})
      '';
    in
    pkgs.runCommandLocal "theme-${id}" { } ''
      mkdir -p $out/gtk-theme/gtk-3.0 $out/gtk-theme/gtk-4.0 $out/emacs

      # GTK3 (and plain GTK4) follow a named theme, reloaded when gtk-theme changes
      for v in 3 4; do
        {
          echo '@import url("file://${adwGtk3}/gtk-'$v'.0/gtk.css");'
          cat ${gtkCss}
        } > $out/gtk-theme/gtk-$v.0/gtk.css
      done

      # GTK4/libadwaita: swapped into ~/.config/gtk-4.0/gtk.css
      cp ${gtkCss} $out/gtk4.css

      cat > $out/foot.ini <<'EOF'
      [colors-dark]
      ${footColors}
      [colors-light]
      ${footColors}
      EOF

      printf '${termSeq}' > $out/terminal.seq

      cat > $out/emacs.el <<'EOF'
      ${emacsTheme}
      ;; already running: switch now
      (when after-init-time
        (mapc #'disable-theme custom-enabled-themes)
        (load-theme doom-theme t))
      EOF
      cat > $out/emacs/base16-nix-${id}-theme.el <<'EOF'
      ${emacsBase16}
      EOF

      cp ${browserJson} $out/browser.json
      ${lib.optionalString brave ''
        cp -r ${braveTheme.theme id braveColors} $out/brave-theme
        echo '${builtins.toJSON (braveTheme.prefs c)}' > $out/brave.json
        echo '${c.base00}' > $out/brave-color
      ''}

      cp ${wallpaper} $out/wallpaper.png
      cat > $out/mango.conf <<'EOF'
      ${mangoConf}
      EOF
      cat > $out/fish.fish <<'EOF'
      ${fishColors}
      EOF
      cat > $out/kitty.conf <<'EOF'
      ${kittyConf}
      EOF
      cat > $out/ghostty <<'EOF'
      ${ghosttyConf}
      EOF
      cp ${alacrittyToml} $out/alacritty.toml
      cat > $out/discord.css <<'EOF'
      ${discordCss}
      EOF
      cat > $out/qt5ct-colors.conf <<'EOF'
      ${qtColors 21}
      EOF
      cat > $out/qt6ct-colors.conf <<'EOF'
      ${qtColors 22}
      EOF
      cat > $out/qt5ct.conf <<'EOF'
      ${qtctConf "qt5ct"}
      EOF
      cat > $out/qt6ct.conf <<'EOF'
      ${qtctConf "qt6ct"}
      EOF

      echo ${mode} > $out/mode
    '';

  # noctalia palette "nix-<theme>" (home/ui/noctalia.nix), dark and light
  noctaliaPalette =
    theme:
    lib.mapAttrs (
      _: scheme:
      let
        c = (base16.mkSchemeAttrs scheme).withHashtag;
        ansi =
          names:
          lib.genAttrs [
            "black"
            "red"
            "green"
            "yellow"
            "blue"
            "magenta"
            "cyan"
            "white"
          ] (n: c.${names.${n}});
      in
      {
        mPrimary = c.base0D;
        mOnPrimary = c.base00;
        mSecondary = c.base0E;
        mOnSecondary = c.base00;
        mTertiary = c.base0C;
        mOnTertiary = c.base00;
        mError = c.base08;
        mOnError = c.base00;
        mSurface = c.base00;
        mOnSurface = c.base05;
        mSurfaceVariant = c.base01;
        mOnSurfaceVariant = c.base04;
        mOutline = c.base03;
        mShadow = "#000000";
        mHover = c.base02;
        mOnHover = c.base05;
        terminal = {
          background = c.base00;
          foreground = c.base05;
          cursor = c.base05;
          cursorText = c.base00;
          selectionBg = c.base02;
          selectionFg = c.base05;
          normal = ansi {
            black = "base00";
            red = "base08";
            green = "base0B";
            yellow = "base0A";
            blue = "base0D";
            magenta = "base0E";
            cyan = "base0C";
            white = "base05";
          };
          bright = ansi {
            black = "base03";
            red = "base08";
            green = "base0B";
            yellow = "base0A";
            blue = "base0D";
            magenta = "base0E";
            cyan = "base0C";
            white = "base07";
          };
        };
      }
    ) theme.schemes;

  index = pkgs.linkFarm "themes" (
    map (v: {
      name = v.id;
      path = mkVariant v;
    }) variants
  );

  themeCmd = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs = with pkgs; [
      coreutils
      glib
      procps
      dconf
      gawk
      systemd
      util-linux # flock, logger
    ];
    text = ''
      index=${index}
      state=${stateDir}
      mkdir -p "$state"
      cmd="theme $*"

      # one change at a time: a second `theme` waits for the first, so the
      # state (and the boot splash synced from it) ends at the last choice
      case "''${1:-status}" in
        list | status | icon | entries) ;;
        *)
          exec 8>"$state/.lock"
          if [ "''${1:-}" = noctalia-mode ]; then
            # busy means it is our own `theme-mode-set` echoing back
            flock -n 8 || exit 0
          else
            flock 8
          fi
          ;;
      esac

      name=$(cat "$state/name" 2>/dev/null || echo ${cfg.default.name})
      mode=$(cat "$state/mode" 2>/dev/null || echo ${cfg.default.mode})

      usage() {
        echo "usage: theme [list | status | set NAME [dark|light] | mode dark|light | toggle | auto [on|off|toggle] | entries | pick LINE | apply]"
      }

      # today's sunrise and sunset ("HH:MM HH:MM", local time) at the position
      # in $state/location ("LAT LON", written by the locator); the fixed
      # theme.auto times without a position or near the poles
      sun() {
        local lat lon times=""
        if read -r lat lon 2>/dev/null < "$state/location"; then
          times=$(awk -v lat="$lat" -v lon="$lon" -v doy="$(date +%j)" -v tz="$(date +%z)" '
            BEGIN {
              pi = atan2(0, -1); r = pi / 180; g = 2 * pi / 365 * (doy - 1)
              eq = 229.18 * (0.000075 + 0.001868 * cos(g) - 0.032077 * sin(g) \
                - 0.014615 * cos(2 * g) - 0.040849 * sin(2 * g))
              d = 0.006918 - 0.399912 * cos(g) + 0.070257 * sin(g) - 0.006758 * cos(2 * g) \
                + 0.000907 * sin(2 * g) - 0.002697 * cos(3 * g) + 0.00148 * sin(3 * g)
              x = cos(90.833 * r) / (cos(lat * r) * cos(d)) - sin(lat * r) / cos(lat * r) * sin(d) / cos(d)
              if (x > 1 || x < -1) exit
              ha = atan2(sqrt(1 - x * x), x) / r
              off = (substr(tz, 1, 1) == "-" ? -1 : 1) * (substr(tz, 2, 2) * 60 + substr(tz, 4, 2))
              rise = (720 - 4 * (lon + ha) - eq + off + 1440) % 1440
              set = (720 - 4 * (lon - ha) - eq + off + 1440) % 1440
              printf "%02d:%02d %02d:%02d\n", rise / 60, rise % 60, set / 60, set % 60
            }')
        fi
        echo "''${times:-${cfg.auto.sunrise} ${cfg.auto.sunset}}"
      }

      # atomic symlink swap: inotify sees a rename, never a missing file
      swap() {
        ln -sfn "$1" "$2.tmp.$$"
        mv -Tf "$2.tmp.$$" "$2"
      }

      apply() {
        local v="$index/$name-$mode"
        if [ ! -d "$v" ]; then
          # single-mode themes (zenburn): keep the mode they have
          if [ "$mode" = dark ]; then mode=light; else mode=dark; fi
          v="$index/$name-$mode"
        fi
        if [ ! -d "$v" ]; then
          echo "theme: no theme '$name'" >&2
          exit 1
        fi
        echo "$name" > "$state/name"
        echo "$mode" > "$state/mode"
        # the pair in one file, last: what the boot screens follow
        # (modules/theme-boot.nix), never half of a change
        echo "$name-$mode" > "$state/boot.tmp"
        mv -f "$state/boot.tmp" "$state/boot"
        # who changed it, for when the theme is not the expected one
        logger -t theme "$name-$mode ($cmd, from $(ps -o args= -p "$PPID" 2>/dev/null | cut -c1-100))" || true
        swap "$v" "$state/current"

        # GTK4/libadwaita (patched gtk reloads it live)
        mkdir -p "$HOME/.config/gtk-4.0"
        swap "$v/gtk4.css" "$HOME/.config/gtk-4.0/gtk.css"

        # settings.ini: what GTK reads without dconf (Electron, Chromium,
        # XWayland and unwrapped apps), with this theme instead of a fixed one
        for g in 3 4; do
          f=$HOME/.config/gtk-$g.0/settings.ini
          mkdir -p "''${f%/*}"
          {
            grep -v '^gtk-theme-name=\|^gtk-icon-theme-name=\|^gtk-application-prefer-dark-theme=' \
              "${gtkSettings}/gtk-$g.0.ini"
            echo "gtk-theme-name=nix-$name-$mode"
            if [ "$mode" = dark ]; then
              echo "gtk-icon-theme-name=${cfg.icons.dark}"
            else
              echo "gtk-icon-theme-name=${cfg.icons.light}"
            fi
            # GTK4 has no dark variants of a named theme (libadwaita warns)
            if [ "$g" = 3 ]; then
              echo "gtk-application-prefer-dark-theme=$([ "$mode" = dark ] && echo 1 || echo 0)"
            fi
          } > "$f.tmp.$$"
          mv -f "$f.tmp.$$" "$f"
        done

        # GTK3, plain GTK4, icons, and the dark/light preference (portal, browsers)
        dconf write /org/gnome/desktop/interface/color-scheme "'prefer-$mode'"
        dconf write /org/gnome/desktop/interface/gtk-theme "'nix-$name-$mode'"
        if [ "$mode" = dark ]; then
          dconf write /org/gnome/desktop/interface/icon-theme "'${cfg.icons.dark}'"
        else
          dconf write /org/gnome/desktop/interface/icon-theme "'${cfg.icons.light}'"
        fi

        # running terminals (foot directly, tmux panes via their own pty)
        for pts in /dev/pts/[0-9]*; do
          if [ -O "$pts" ] && [ -w "$pts" ]; then
            timeout 1 cp "$v/terminal.seq" "$pts" 2>/dev/null || true
          fi
        done

        # running fish shells: a universal variable change fires their handler
        fish -c "set -U __nix_theme $name-$mode-$(date +%s%N)" 2>/dev/null || true

        if command -v emacsclient >/dev/null; then
          timeout 5 emacsclient --eval "(load \"$v/emacs.el\" nil t)" >/dev/null 2>&1 || true
        fi

        # Qt: qt5ct/qt6ct reload when their config directory changes
        for qt in qt5ct qt6ct; do
          mkdir -p "$HOME/.config/$qt"
          # a fresh copy, not a store link: QSettings caches by size+mtime and
          # every store file has the same mtime
          install -m 644 "$v/$qt.conf" "$HOME/.config/$qt/$qt.conf.tmp.$$"
          mv -f "$HOME/.config/$qt/$qt.conf.tmp.$$" "$HOME/.config/$qt/$qt.conf"
        done

        # Discord (Vencord watches its themes folder); a real file, not a link
        if [ -d "$HOME/.config/Vencord/themes" ]; then
          install -m 644 "$v/discord.css" "$HOME/.config/Vencord/themes/.nix-theme.css.$$"
          mv -f "$HOME/.config/Vencord/themes/.nix-theme.css.$$" "$HOME/.config/Vencord/themes/nix-theme.css"
        fi

        # kitty/ghostty: reload config (open windows already got the palette above)
        pkill -USR1 -f '^/nix/store/[^ ]*/bin/\.?kitty(-wrapped)?( |$)' || true
        pkill -USR2 -f '^/nix/store/[^ ]*/bin/\.?ghostty(-wrapped)?( |$)' || true

        # mango session: border colors; noctalia: palette and mode
        mmsg dispatch reload_config >/dev/null 2>&1 || true
        if command -v noctalia >/dev/null && noctalia msg theme-mode-get >/dev/null 2>&1; then
          noctalia msg color-scheme-set custom "nix-$name" >/dev/null 2>&1 || true
          noctalia msg wallpaper-set "$v/wallpaper.png" >/dev/null 2>&1 || true
          [ "$(noctalia msg theme-mode-get 2>/dev/null)" = "$mode" ] ||
            noctalia msg theme-mode-set "$mode" >/dev/null 2>&1 || true
        fi

        # Brave (pkgs/brave-theme): the palette's theme pack into the folder
        # its theme extension is installed from; running, it rereads it when
        # the reload service (default/brave.nix) toggles its theme policy
        if [ -d "$v/brave-theme" ]; then
          mkdir -p "$state/brave-theme"
          for f in manifest.json "Cached Theme.pak"; do
            install -m 644 "$v/brave-theme/$f" "$state/brave-theme/.$f.$$"
            mv -f "$state/brave-theme/.$f.$$" "$state/brave-theme/$f"
          done
          if pgrep -u "$(id -u)" -x brave >/dev/null && [ -w /run/nix-theme ]; then
            cat "$v/brave-color" > /run/nix-theme/brave-reload
          fi
        fi
      }

      case "''${1:-status}" in
        list)
          find -L "$index" -mindepth 1 -maxdepth 1 -printf '%f\n' | sed -E 's/-(dark|light)$//' | sort -u
          ;;
        status)
          echo "$name $mode"
          ;;
        icon)
          if [ "$mode" = dark ]; then echo "󰖔"; else echo "󰖨"; fi
          ;;
        set)
          name=''${2:?$(usage)}
          mode=''${3:-$mode}
          apply
          ;;
        # noctalia's theme_mode_changed hook (home/ui/noctalia.nix): its own
        # Light/Dark switch; a stale event (noctalia already moved on) is
        # dropped, so it can never undo a newer choice
        noctalia-mode)
          [ "''${2:?$(usage)}" = "$mode" ] && exit 0
          [ "$(noctalia msg theme-mode-get 2>/dev/null)" = "$2" ] || exit 0
          echo off > "$state/auto"
          mode=$2
          apply
          ;;
        mode)
          [ "''${2:?$(usage)}" = "$mode" ] && exit 0
          echo off > "$state/auto" # a manual choice ends the day/night schedule
          mode=$2
          apply
          ;;
        toggle)
          echo off > "$state/auto"
          if [ "$mode" = dark ]; then mode=light; else mode=dark; fi
          apply
          ;;
        auto)
          case "''${2:-toggle}" in
            on | off) auto=$2 ;;
            *) if [ "$(cat "$state/auto" 2>/dev/null)" = on ]; then auto=off; else auto=on; fi ;;
          esac
          echo "$auto" > "$state/auto"
          if [ "$auto" = on ]; then exec "$0" auto-tick; fi
          ;;
        # light between sunrise and sunset, dark otherwise; run at login and
        # at each transition (a transient timer armed here, see theme-auto-next)
        auto-tick)
          [ "$(cat "$state/auto" 2>/dev/null)" = on ] || exit 0
          read -r rise set < <(sun)
          echo "$rise $set" > "$state/sun"
          now=$(date +%H%M)
          if [ "$now" -ge "''${rise/:/}" ] && [ "$now" -lt "''${set/:/}" ]; then
            want=light next=$set
          else
            want=dark next=$rise
          fi
          systemctl --user stop theme-auto-next.timer 2>/dev/null || true
          systemd-run --user --quiet --unit=theme-auto-next --on-calendar="*-*-* $next:00" || true
          [ "$want" = "$mode" ] && exit 0
          mode=$want
          apply
          ;;
        # noctalia launcher provider (/theme): "title<TAB>description" lines
        entries)
          auto=$(cat "$state/auto" 2>/dev/null || echo off)
          current() { [ "$1" = yes ] && printf ' · current'; }
          printf 'Light\tlight mode%s\n' "$(current "$([ "$auto" != on ] && [ "$mode" = light ] && echo yes)")"
          printf 'Dark\tdark mode%s\n' "$(current "$([ "$auto" != on ] && [ "$mode" = dark ] && echo yes)")"
          read -r rise set < <(sun)
          printf 'Auto\tlight at %s, dark at %s · %s\n' "$rise" "$set" "$([ "$auto" = on ] && echo on || echo off)"
          "$0" list | while read -r t; do
            printf '%s\ttheme%s\n' "$t" "$(current "$([ "$t" = "$name" ] && echo yes)")"
          done
          ;;
        pick)
          choice=''${2:?$(usage)}
          choice=''${choice%%$'\t'*}
          case "$choice" in
            Light) exec "$0" mode light ;;
            Dark) exec "$0" mode dark ;;
            Auto) exec "$0" auto toggle ;;
            *)
              name=$choice
              apply
              ;;
          esac
          ;;
        apply)
          apply
          ;;
        *)
          usage
          exit 1
          ;;
      esac
    '';
  };

  schemeType = types.either types.path (types.attrsOf types.str);
in
{
  options.theme = {
    themes = mkOption {
      description = "Themes available to `theme`, each with dark and/or light base16 schemes.";
      type = types.attrsOf (
        types.submodule {
          options = {
            schemes = mkOption {
              type = types.attrsOf schemeType;
              description = "base16 scheme per mode (`dark`, `light`): a yaml path or an inline palette.";
            };
            emacs = mkOption {
              type = types.attrsOf (types.nullOr types.str);
              default = {
                dark = null;
                light = null;
              };
              description = "Doom theme per mode; null generates one from the base16 palette.";
            };
          };
        }
      );
    };
    default = {
      name = mkOption {
        type = types.str;
        default = "gruvbox";
      };
      mode = mkOption {
        type = types.enum [
          "dark"
          "light"
        ];
        default = "dark";
      };
    };
    icons = {
      dark = mkOption {
        type = types.str;
        default = config.stylix.icons.dark;
      };
      light = mkOption {
        type = types.str;
        default = config.stylix.icons.light;
      };
    };
    auto = {
      sunrise = mkOption {
        type = types.str;
        default = "06:00";
        description = "`theme auto`: light from this time (HH:MM) while the position is unknown.";
      };
      sunset = mkOption {
        type = types.str;
        default = "18:00";
        description = "`theme auto`: dark from this time (HH:MM) while the position is unknown.";
      };
    };
    package = mkOption {
      type = types.package;
      readOnly = true;
      default = themeCmd;
    };
    noctaliaPalettes = mkOption {
      type = types.attrsOf types.anything;
      readOnly = true;
      default = lib.mapAttrs' (
        name: theme: lib.nameValuePair "nix-${name}" (noctaliaPalette theme)
      ) cfg.themes;
      description = "Noctalia palettes for every theme, named nix-<theme>.";
    };
  };

  config = {
    theme.themes = import ./themes.nix { inherit pkgs; };

    # these targets now come from the active theme instead of stylix
    stylix.targets = {
      gtk.enable = false;
      vencord.enable = false;
      foot.enable = false;
      emacs.enable = false;
      fish.enable = false;
      # terminal programs: plain ANSI colors follow the live terminal palette
      fzf.enable = false;
      bat.enable = false;
      yazi.enable = false;
      starship.enable = false;
      gdu.enable = false;
      opencode.enable = false;
      kitty.enable = false;
      ghostty.enable = false;
      alacritty.enable = false;
    };

    # gtk-theme is set live through dconf (by `theme`), never in settings.ini
    gtk.gtk4.theme = null;
    # written by `theme` (see gtkSettings): a fixed file pinned every app
    # without dconf to one theme and to dark
    xdg.configFile."gtk-3.0/settings.ini".enable = lib.mkForce false;
    xdg.configFile."gtk-4.0/settings.ini".enable = lib.mkForce false;

    home.packages = [ cfg.package ];

    # named GTK themes: nix-<theme>-<mode>
    xdg.dataFile = lib.listToAttrs (
      map (v: {
        name = "themes/nix-${v.id}";
        value.source = "${index}/${v.id}/gtk-theme";
      }) variants
    );

    # native host of the nix-theme browser extension (default/librewolf.nix);
    # LibreWolf looks in ~/.librewolf, not where the nixpkgs wrapper links it
    home.file.".librewolf/native-messaging-hosts/nix_theme.json".source = "${
      pkgs.callPackage ../../pkgs/nix-theme { }
    }/lib/mozilla/native-messaging-hosts/nix_theme.json";

    programs.foot.settings.main.include = "${stateDir}/current/foot.ini";
    programs.fzf.defaultOptions = [ "--color=16" ];
    programs.bat.config.theme = "base16";
    programs.opencode.tui.theme = "system";
    programs.kitty.extraConfig = "include ${stateDir}/current/kitty.conf";
    programs.ghostty.settings.config-file = "?${stateDir}/current/ghostty";
    programs.alacritty.settings.general.import = [ "${stateDir}/current/alacritty.toml" ];
    # fish: colors of the active theme, reloaded live through `set -U __nix_theme`
    # (see `theme apply`); new shells also re-send the terminal palette
    programs.fish.interactiveShellInit = ''
      function __nix_theme_apply --on-variable __nix_theme
        test -r ${stateDir}/current/fish.fish; and source ${stateDir}/current/fish.fish
      end
      __nix_theme_apply
      test -r ${stateDir}/current/terminal.seq; and isatty stdout; and cat ${stateDir}/current/terminal.seq
    '';

    # Chromium has no live theme API: GTK mode follows the GTK theme that
    # `theme` switches (Brave runs a theme extension, pkgs/brave-theme). The
    # setting lives in each profile's Preferences, which the browser rewrites
    # on exit, so only touch it while closed.
    home.activation.chromiumGtkTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for prefs in "$HOME"/.config/chromium/*/Preferences; do
        [ -f "$prefs" ] || continue
        if ${pkgs.procps}/bin/pgrep -u "$USER" -x chromium >/dev/null; then
          echo "theme: close chromium to switch it to the GTK theme (then switch again)"
          continue
        fi
        run ${pkgs.jq}/bin/jq '.extensions.theme.system_theme = 1
          | .extensions.theme.id = ""
          | .browser.theme.color_scheme2 = 0' "$prefs" > "$prefs.tmp"
        run mv "$prefs.tmp" "$prefs"
      done
    '';

    # Vencord: create the themes folder and enable nix-theme.css (its other
    # settings stay as Vencord keeps them)
    home.activation.vencordTheme = lib.hm.dag.entryBetween [ "theme" ] [ "writeBoundary" ] ''
      run mkdir -p "$HOME/.config/Vencord/themes" "$HOME/.config/Vencord/settings"
      settings="$HOME/.config/Vencord/settings/settings.json"
      [ -s "$settings" ] || echo '{}' > "$settings"
      run ${pkgs.jq}/bin/jq '.enabledThemes = ((.enabledThemes // []) - ["nix-theme.css"] + ["nix-theme.css"])' \
        "$settings" > "$settings.tmp"
      run mv "$settings.tmp" "$settings"
    '';

    # `theme auto`: light/dark at login; auto-tick then arms the transient
    # theme-auto-next.timer for the next sunrise/sunset
    systemd.user.services.theme-auto = {
      Unit.Description = "Day/night theme mode";
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe cfg.package} auto-tick";
      };
    };
    systemd.user.services.theme-auto-next = {
      Unit.Description = "Day/night theme mode (sunrise/sunset)";
      Service = {
        Type = "oneshot";
        ExecStart = "${lib.getExe cfg.package} auto-tick";
      };
    };
    systemd.user.timers.theme-auto = {
      Unit.Description = "Day/night theme mode";
      Timer.OnStartupSec = "5s";
      Install.WantedBy = [ "timers.target" ];
    };

    # after every switch: re-point to this generation's store paths
    home.activation.theme =
      lib.hm.dag.entryBetween [ "reloadSystemd" ] [ "linkGeneration" "dconfSettings" ]
        ''
          run ${lib.getExe cfg.package} apply || true
        '';
  };
}
