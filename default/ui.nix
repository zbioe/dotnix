{
  config,
  lib,
  pkgs,
  username,
  unstable,
  ...
}:
let
  fonts = import ../home/theme/fonts/catalog.nix { inherit pkgs; };
in
{
  environment.sessionVariables = {
    # https://nixos.wiki/wiki/Wayland#Applications
    NIXOS_OZONE_WL = "1";
    # XDG_CURRENT_DESKTOP/XDG_SESSION_* come from the session (uwsm)

    # Emacs to use wayland in the right way
    GDK_BACKEND = "wayland";

    # Xwidgets dont fight with hardware aceleration of GPU
    WEBKIT_DISABLE_DMABUF_RENDERER = "1";
    WEBKIT_DISABLE_COMPOSITING_MODE = "1";

    LC_CTYPE = "pt_BR.UTF-8";

    XLOCALEDIR = "${pkgs.libx11}/share/X11/locale";
    XCOMPOSEFILE = "${pkgs.libx11}/share/X11/locale/pt_BR.UTF-8/Compose";

  };
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      fcitx5-gtk
    ];
  };

  # Display Manager
  services.displayManager = {
    defaultSession = "mango-uwsm";
    autoLogin = {
      enable = true;
      user = username;
    };
    sddm = {
      enable = true;
      package = pkgs.kdePackages.sddm;
      theme = "where_is_my_sddm_theme";
      wayland = {
        enable = true;
        compositor = "kwin";
      };
      extraPackages = [
        pkgs.kdePackages.qt5compat
      ];
    };
  };

  programs.fish.enable = true;

  # the session runs under uwsm (systemd units for the compositor and apps);
  # X11 apps through Xwayland (Workpuls among them, home/ui/insightful.nix)
  programs.uwsm.enable = true;
  programs.xwayland.enable = true;
  # GTK settings backend (`theme` writes the color scheme there)
  programs.dconf.enable = true;

  # location from nearby Wi-Fi (like browsers do), for noctalia's weather and
  # sunrise/sunset (home/ui/noctalia.nix asks it through where-am-i)
  services.geoclue2 = {
    enable = true;
    appConfig.geoclue-where-am-i = {
      isAllowed = true;
      isSystem = false;
    };
  };

  # brightness of external monitors (DDC/CI), used by noctalia
  hardware.i2c.enable = true;

  # Secret Service (noctalia calendar accounts, browsers); unlocked at login
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  # mango, run through uwsm so systemd user units see XDG_CURRENT_DESKTOP=mango;
  # its portals: wlr for screen sharing and screenshots, gtk for the rest
  programs.mango = {
    enable = true;
    addLoginEntry = false;
  };
  # (programs.uwsm.waylandCompositors' entry, plus -g -1: uwsm would wait for
  # the system's graphical.target, which waits for docker and network-online,
  # several seconds of an empty screen after login)
  services.displayManager.sessionPackages = [
    (pkgs.writeTextFile {
      name = "mango-uwsm";
      text = ''
        [Desktop Entry]
        Name=Mango (UWSM)
        Comment=Mango compositor managed by UWSM
        Exec=${lib.getExe config.programs.uwsm.package} start -g -1 -F -- /run/current-system/sw/bin/mango
        Type=Application
      '';
      destination = "/share/wayland-sessions/mango-uwsm.desktop";
      derivationArgs.passthru.providedSessions = [ "mango-uwsm" ];
    })
  ];

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = [ "gtk" ];
  };

  # Hardware
  hardware = {
    # Opengl
    graphics.enable = true;
  };

  # Packages
  environment.systemPackages = with pkgs; [
    ddcutil # monitor brightness over DDC/CI
    # notification
    libnotify

    # player manager
    playerctl

    # brightness manager
    brightnessctl

    # printscreen with selection
    # grim -l 0 -g "$(slurp)" - | wl-copy
    wl-clipboard # cli interface to clipboard (xclip anternative)
    wtype # type text from scripts (xdotool for wayland)
    slurp # select utility
    grim # screenshot utility
    tesseract # image to text

    # image manager
    imagemagick # editing and manipulating digital images

    # Diagrama
    mermaid-cli

  ];

  # Qt apps through qt5ct/qt6ct, whose palette and fonts `theme` writes (home/theme)
  qt = {
    enable = true;
    platformTheme = "qt5ct";
  };

  fonts.fontconfig = {
    enable = true;
    useEmbeddedBitmaps = true;
    # the user's choice comes from `theme font` (home/theme/fonts); this is root's and the greeter's
    defaultFonts = {
      sansSerif = [ fonts.default.ui ];
      serif = [ fonts.default.serif ];
      monospace = [ fonts.default.mono ];
      emoji = [ fonts.default.emoji ];
    };
  };
  # every font `theme font` can pick, so any choice applies live
  fonts.packages =
    fonts.packages
    ++ (with pkgs; [
      meslo-lgs-nf
      montserrat
    ]);

  # Games
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
    localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers
  };
  programs.appimage.enable = true;
  programs.appimage.binfmt = true;

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc
      fuse3
      icu
      nss
      openssl
      curl
      libglvnd
      libx11
      libxrandr
      libxext
      krb5
      mesa
      alsa-lib
      libGL
      libpng
      expat
      zlib
    ];
  };
  hardware.graphics.enable32Bit = true;

  # GTK4 reloads ~/.config/gtk-4.0/gtk.css when it changes, so libadwaita apps
  # follow `theme` switches live (home/theme). Swapped into the closure without
  # rebuilding the apps.
  system.replaceDependencies.replacements = import ../patches/gtk4-live.nix [
    pkgs.gtk4
    unstable.gtk4
  ];
}
