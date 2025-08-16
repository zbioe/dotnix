{
  config,
  lib,
  pkgs,
  ...
}:
let
  qt6 = pkgs.qt6;
  qt5 = pkgs.libsForQt5;
in
{

  stylix.cursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 3;
  };

  modules.stylix = {
    enable = true;
    autoEnable = true;
    theme = "gruvbox-dark-medium";
  };

  stylix.targets.gtk.extraCss = ''
    .default-decoration {
      min-height: 0;
      padding: 0;
      border-width: 0;
    }
    .headerbar {
      min-height: 0;
      padding: 0;
      border-width: 0;
    }
    window decoration {
      margin: 0;
      padding: 0;
      border: none;
      box-shadow: none;
    }
    window.csd {
      margin: 0;
      padding: 0;
      border: none;
    }
  '';

  gtk = {
    enable = true;
    gtk3.extraConfig = {
      gtk-decoration-layout = "";
    };
    gtk4.extraConfig = {
      gtk-decoration-layout = "";
    };
  };

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

    # Disable all client side decorations
    # WAYLAND_DISPLAY = "no";
    GTK_CSD = "0";
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
    kitty = {
      enable = true;
      settings = {
        hide_window_decorations = "yes";
        titlebar_style = "none";
        window_border_width = 0;
        draw_minimal_borders = "yes";
        placement_strategy = "top-right";
        tab_bar_style = "hidden";
        window_padding_width = 0;
        window_margin_width = 0;
      };
    };
    alacritty.enable = true;
  };
}
