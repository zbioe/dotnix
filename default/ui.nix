{
  config,
  lib,
  pkgs,
  hyprland,
  username,
  unstable,
  xdg-desktop-portal-hyprland,
  ...
}:

let
  sddm_theme = pkgs.where-is-my-sddm-theme.override {
    themeConfig.General = with config.lib.stylix.colors.withHashtag; {
      hideCursor = true;
      backgroundFill = "${base00}";
      basicTextColor = "${base05}";
      passwordCursorColor = "${base0B}";
      passwordCharacter = "•";
      passwordInputWidth = "1";
      passwordFontSize = 62;
    };
  };
in
{
  environment.sessionVariables = {
    # https://nixos.wiki/wiki/Wayland#Applications
    NIXOS_OZONE_WL = "1";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_TYPE = "wayland";
    XDG_SESSION_DESKTOP = "Hyprland";

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
    defaultSession = "hyprland-uwsm";
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

  # hyprland
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    package = hyprland;
    portalPackage = xdg-desktop-portal-hyprland;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
    ];
    config = {
      hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];
      };
      common = {
        default = [ "gtk" ];
      };
    };
  };

  # Hardware
  hardware = {
    # Opengl
    graphics.enable = true;
  };

  # Packages
  environment.systemPackages = with pkgs; [
    # notification
    libnotify

    # wallpaper
    awww

    # player manager
    playerctl

    # brightness manager
    brightnessctl

    # printscreen with selection
    # grim -l 0 -g "$(slurp)" - | wl-copy
    wl-clipboard # cli interface to clipboard (xclip anternative)
    wtype # write with hyprland
    slurp # select utility
    grim # screenshot utility
    grimblast # screenshot
    tesseract # image to text

    # image manager
    imagemagick # editing and manipulating digital images

    # Diagrama
    mermaid-cli

    # sddm theme
    sddm_theme
  ];

  fonts.fontconfig.enable = true;
  fonts.fontconfig.useEmbeddedBitmaps = true;
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    meslo-lgs-nf
    fira-code
    inter
    material-icons
    iosevka
    jetbrains-mono
    hack-font
    nerd-fonts.symbols-only
    roboto
    montserrat
  ];

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
}
