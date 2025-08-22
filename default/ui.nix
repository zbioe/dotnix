{
  config,
  lib,
  pkgs,
  hyprland,
  username,
  xdg-desktop-portal-hyprland,
  ...
}:

{

  # Display Manager
  services.displayManager = {
    defaultSession = "hyprland-uwsm";
    autoLogin = {
      enable = true;
      user = username;
    };
    sddm =
      let
        sddm_theme = pkgs.where-is-my-sddm-theme.override {
          themeConfig.General = with config.lib.stylix.colors.withHashtag; {
            hideCursor = "true";

            backgroundFill = base00;
            basicTextColor = base05;
            passwordCursorColor = base08;
          };
        };
      in
      {
        enable = true;
        wayland.enable = true;
        theme = "${sddm_theme}/share/sddm/themes/where_is_my_sddm_theme";
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
  xdg.portal.extraPortals = [
    xdg-desktop-portal-hyprland
    pkgs.xdg-desktop-portal-gtk
  ];

  # Hardware
  hardware = {
    # Opengl
    graphics.enable = true;
  };

  # Packages
  environment.systemPackages = with pkgs; [
    # notification
    dunst
    libnotify

    # wallpaper
    swww

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

  ];

  environment.sessionVariables = {
    # https://nixos.wiki/wiki/Wayland#Applications
    NIXOS_OZONE_WL = "1";
  };

  fonts.fontconfig.enable = true;
  fonts.packages =
    with pkgs;
    [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-emoji
      noto-fonts-cjk-serif
      noto-fonts-extra
      symbola
      vegur
      meslo-lgs-nf
      fira-sans
      fira-code
      fira-code-symbols
      roboto
      jetbrains-mono
      material-symbols
      material-icons
      fontconfig
      freetype
      liberation_ttf
      dejavu_fonts
      ubuntu_font_family
      meslo-lgs-nf
    ]
    ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);
}
