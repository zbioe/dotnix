# One theme/mode pair rendered for every app: GTK 3/4 CSS, terminals, Qt,
# Emacs, browsers, the wallpaper. `theme` only moves symlinks to these.
{
  lib,
  pkgs,
  mkSchemeAttrs,
  brave,
  braveTheme,
}:
{
  id,
  mode,
  theme,
  ...
}:
let
  colors = mkSchemeAttrs theme.schemes.${mode};
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

  # terminal palette: base16's usual ANSI mapping
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
  # mango (home/desktop/mango sources this); colors are 0xRRGGBBAA
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
  # Discord through Vencord (system/packages/chat.nix): its themes folder is
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
    icon_theme=
    standard_dialogs=xdgdesktopportal
    style=Fusion
  '';
  # mini.base16 paints the whole UI from the palette; a running nvim reruns it
  nvimTheme = ''
    require("mini.base16").setup({
      palette = {
        ${lib.concatMapStringsSep "\n        " (b: "${b} = \"${c.${b}}\",") bases}
      },
    })
    vim.o.background = "${mode}"
    vim.g.colors_name = "base16-nix-${id}"
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
  ;;; emacs.el -*- lexical-binding: t; -*-
  ${emacsTheme}
  ;; already running: switch now
  (when after-init-time
    (mapc #'disable-theme custom-enabled-themes)
    (load-theme doom-theme t))
  EOF
  cat > $out/emacs/base16-nix-${id}-theme.el <<'EOF'
  ;;; base16-nix-${id}-theme.el -*- lexical-binding: t; -*-
  ${emacsBase16}
  EOF
  cat > $out/nvim.lua <<'EOF'
  ${nvimTheme}
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
''
