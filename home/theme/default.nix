# Live theme switching: every theme/mode pair is prebuilt (variant.nix) and
# `theme` (theme.sh) moves symlinks and pokes the running apps.
{
  config,
  lib,
  pkgs,
  unstable,
  base16,
  ...
}:
let
  cfg = config.dotnix.theme;
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  inherit (base16.lib { inherit pkgs lib; }) mkSchemeAttrs;

  stateDir = "${config.xdg.stateHome}/theme";

  # the settings.ini home-manager would write (cursor, key theme...); `theme`
  # writes them itself with the active theme, icons and dark preference
  gtkSettings = pkgs.runCommandLocal "gtk-settings" { } ''
    mkdir $out
    cp ${pkgs.writeText "gtk3" config.xdg.configFile."gtk-3.0/settings.ini".text} $out/gtk-3.0.ini
    cp ${pkgs.writeText "gtk4" config.xdg.configFile."gtk-4.0/settings.ini".text} $out/gtk-4.0.ini
  '';

  brave = config.programs.brave.enable;
  braveTheme = pkgs.callPackage ../../pkgs/brave-theme { inherit (unstable) brave; };

  variants = lib.concatMap (
    name:
    map (mode: {
      inherit name mode;
      id = "${name}-${mode}";
      theme = cfg.themes.${name};
    }) (lib.attrNames cfg.themes.${name}.schemes)
  ) (lib.attrNames cfg.themes);

  mkVariant = import ./variant.nix {
    inherit
      lib
      pkgs
      mkSchemeAttrs
      brave
      braveTheme
      ;
  };

  # noctalia palette "nix-<theme>" (home/desktop/noctalia), dark and light
  noctaliaPalette =
    theme:
    lib.mapAttrs (
      _: scheme:
      let
        c = (mkSchemeAttrs scheme).withHashtag;
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
      jq # theme icons
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
      THEME_DEFAULT_NAME=${cfg.default.name}
      THEME_DEFAULT_MODE=${cfg.default.mode}
      THEME_SUNRISE=${cfg.auto.sunrise}
      THEME_SUNSET=${cfg.auto.sunset}
      GTK_SETTINGS=${gtkSettings}
      ${cfg.fonts.script}
      ${cfg.icons.script}
      ${builtins.readFile ./theme.sh}
    '';
  };

  schemeType = types.either types.path (types.attrsOf types.str);
in
{
  imports = [
    ./fonts
    ./icons
    ./plugin.nix
  ];

  options.dotnix.theme = {
    enable = mkEnableOption "live theme switching (`theme`)";
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

  config = mkIf cfg.enable {
    dotnix.theme.themes = import ./themes.nix { inherit pkgs; };

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

    # native host of the nix-theme browser extension (system/desktop/browsers);
    # LibreWolf looks in ~/.librewolf, not where the nixpkgs wrapper links it
    home.file.".librewolf/native-messaging-hosts/nix_theme.json".source = "${
      pkgs.callPackage ../../pkgs/nix-theme { }
    }/lib/mozilla/native-messaging-hosts/nix_theme.json";

    programs.foot.settings.main.include = [ "${stateDir}/current/foot.ini" ];
    programs.fzf.defaultOptions = [ "--color=16" ];
    programs.bat.config.theme = "base16";
    programs.opencode.tui.theme = "system";
    programs.kitty.extraConfig = "include ${stateDir}/current/kitty.conf";
    programs.ghostty.settings = {
      config-file = [ "?${stateDir}/current/ghostty" ];
      # `theme` reloads it on every switch: no toast each time
      app-notifications = "no-config-reload";
    };
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
