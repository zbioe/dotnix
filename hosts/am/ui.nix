{
  config,
  lib,
  pkgs,
  hyprland,
  xdg-desktop-portal-hyprland,
  ...
}:

{

  # Display Manager
  services.greetd =
    let
      command = "uwsm start hyprland-uwsm.desktop";
    in
    {
      enable = true;
      settings = {
        default_session = {
          inherit command;
        };
        initial_session = {
          inherit command;
          user = config.modules.user.name;
        };
      };
    };

  programs.tmux.enable = true;
  programs.fish.enable = true;

  programs.xwayland.enable = true;

  # hyprland
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    package = hyprland;
    portalPackage = xdg-desktop-portal-hyprland;
    xwayland.enable = true;
  };
  xdg.portal.extraPortals = [
    xdg-desktop-portal-hyprland
    pkgs.xdg-desktop-portal-gtk
  ];

  # Hardware
  hardware = {
    # Opengl
    graphics.enable = true;

    # Most wayland compositors need this
    nvidia.modesetting.enable = true;
  };

  # Packages
  environment.systemPackages = with pkgs; [
    # notification
    dunst
    libnotify

    # wallpaper
    swww

    # file manager
    nautilus

    # disk utility
    gnome-disk-utility

    # GTK
    gtk3
    gtk4

    # Dev
    github-desktop
    python313
    gedit
    vscode

    # player manager
    playerctl

    # brightness manager
    brightnessctl

    # printscreen with selection
    # grim -l 0 -g "$(slurp)" - | wl-copy
    wl-clipboard # cli interface to clipboard (xclip anternative)
    slurp # select utility
    grim # screenshot utility
    grimblast # screenshot

    # image manager
    imagemagick # editing and manipulating digital images
    wl-color-picker
    gcolor3

    # plasma apply wallpaper
    # kdePackages.plasma-workspace

    # Qt6 related kits（for slove Qt5Compat problem）
    qt6.qt5compat
    qt6.qtbase
    qt6.qtquick3d
    qt6.qtwayland
    qt6.qtdeclarative
    qt6.qtsvg
    qt5.qtgraphicaleffects
    qt5.qtquickcontrols2

    # alternate options
    kdePackages.qt5compat
    libsForQt5.qt5ct
    libsForQt5.qt5.qtgraphicaleffects

  ];

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    noto-fonts-cjk-serif
    fira-sans
    fira-code
    fira-code-symbols
    roboto
    nerd-fonts._0xproto
    nerd-fonts.droid-sans-mono
    jetbrains-mono
    material-symbols
    material-icons
    fontconfig
    freetype
    liberation_ttf
    dejavu_fonts
    ubuntu_font_family
  ];

  # quickshell
  environment.sessionVariables = {
    QT_QPA_PLATFORM = "wayland;xcb";
    QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
    QT_QUICK_CONTROLS_STYLE = "org.kde.desktop";
    FONTCONFIG_PATH = "/etc/fonts";
    FREETYPE_PROPERTIES = "truetype:interpreter-version=40";
  };

  # Environment variables for Qt/QML
  environment.variables = {
    QML2_IMPORT_PATH = "${pkgs.qt6.qt5compat}/lib/qt-6/qml:${pkgs.qt6.qtbase}/lib/qt-6/qml";
    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_ENABLE_HIGHDPI_SCALING = "1";
    QT_QPA_PLATFORMTHEME = "qt5ct";

    # X11/AppImage compatibility for Wayland
    DISPLAY = ":0";
    XDG_SESSION_TYPE = "wayland";
    GDK_BACKEND = "wayland,x11";
    CLUTTER_BACKEND = "wayland";
    SDL_VIDEODRIVER = "wayland";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_WAYLAND_FORCE_DPI = "physical";

    # Additional X11/Electron compatibility
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    ELECTRON_ENABLE_LOGGING = "1";
    ELECTRON_ENABLE_STACK_DUMPING = "1";
    CHROME_EXTRA_ARGS = "--enable-features=Vulkan,VulkanFromANGLE --disable-gpu-sandbox --no-sandbox --disable-dev-shm-usage";

    # Override problematic Qt style variable
    QT_STYLE_OVERRIDE = "";
  };
}
