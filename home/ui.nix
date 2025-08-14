{
  config,
  lib,
  pkgs,
  hyprland,
  hyprland-plugins,
  ...
}:
let
  qt6 = pkgs.qt6;
  qt5 = pkgs.libsForQt5;
in
{
  imports = [
    ../modules/stylix.nix
  ];

  home.packages = with pkgs; [
    qt5.qtgraphicaleffects
    qt5.qtquickcontrols2
    qt5.qtstyleplugin-kvantum
    qt6.qt5compat
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qtwayland
    qt6.qtmultimedia
    qt6.qtsvg
    qt6.qtshadertools
    qt6.qtbase.dev # This includes Qt Widgets headers
    qt6Packages.qtstyleplugin-kvantum
    qt6Packages.qt5compat
  ];

  home.sessionVariables = {
    QT_PLUGIN_PATH = lib.concatStringsSep ":" [
      "${qt6.qtbase}/${qt6.qtbase.qtPluginPrefix}"
      "/run/current-system/sw/lib/qt-6/plugins"
      "/run/current-system/sw/lib/qt-5.15.17/plugins"
    ];
    QML2_IMPORT_PATH = lib.concatStringsSep ":" [
      "/run/current-system/sw/lib/qt-6/qml"
      "/run/current-system/sw/lib/qt-5.15.17/qml"
    ];
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_QUICK_CONTROLS_STYLE = "org.kde.desktop";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_ENABLE_HIGHDPI_SCALING = "1";
    # Ensure Qt Widgets is available
    QT_WIDGETS_LIB = "${qt6.qtbase}/lib";
    LD_LIBRARY_PATH = lib.concatStringsSep ":" [
      "${qt6.qtbase}/lib"
      "/run/current-system/sw/lib"
    ];

    # Override problematic Qt style variable
    QT_STYLE_OVERRIDE = lib.mkForce "";
  };

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style = {
      name = "kvantum";
      package = pkgs.qt6Packages.qtstyleplugin-kvantum;
    };
  };

  programs.anyrun = {
    enable = true;
    config.plugins = [ ];
  };

  programs.wofi = {
    enable = true;
  };

  wayland.windowManager = {
    hyprland = {
      enable = true;
      package = hyprland;
      xwayland.enable = true;
      systemd.variables = [ "--all" ];
      settings = {
        "$mod" = "SUPER";
        exec-once = [
          "waybar"
        ];
        misc = {
          disable_hyprland_logo = true;
          force_default_wallpaper = 0;
        };

        input = {
          follow_mouse = 2;
          sensitivity = 0;
          accel_profile = "adaptive";
          kb_options = "caps:ctrl_modifier";
          kb_layout = "br";
          kb_model = "abnt2";
        };

        bindr = [ "CONTROL, Caps_Lock, exec, ydotool key 1:1 1:0" ];

        monitor = ",preferred,auto,1";

        bind = [
          "$mod, F, fullscreen,"
          "$mod SHIFT, B, exec, uwsm app -- librewolf"
          "$mod, RETURN, exec, uwsm app -- kitty"
          "$mod, P, exec, uwsm app -- wofi --show drun"
          "$mod, Q, killactive,"
          "$mod SHIFT, L, exec, uwsm app -- hyprlock"
          "$mod SHIFT, X, exit,"
          ", Print, exec, uwsm app -- grimblast copy area"
          ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+"
          ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"
          ", XF86MonBrightnessUp, exec, brightnessctl s +5%"
          ", XF86MonBrightnessDown, exec, brightnessctl s 5%-"
        ]
        ++ (
          # workspaces
          # binds $mod + [shift +] {1..9} to [move to] workspace {1..9}
          builtins.concatLists (
            builtins.genList (
              i:
              let
                ws = i + 1;
              in
              [
                "$mod, code:1${toString i}, workspace, ${toString ws}"
                "$mod SHIFT, code:1${toString i}, movetoworkspace, ${toString ws}"
              ]
            ) 9
          )
        );
      };
      plugins = with hyprland-plugins; [
        hyprbars
      ];
    };
  };
  programs.hyprlock = {
    enable = true;
    settings = {
      general = {
        disable_loading_bar = true;
        immediate_render = true;
        hide_cursor = false;
      };
      image = [
        {
          position = "-156.5, -470";
          size = "50";
          rounding = -1;
          zindex = 3;
        }
      ];
    };
  };
  programs = {
    kitty.enable = true;
    # alacritty.enable = true;
  };
}
