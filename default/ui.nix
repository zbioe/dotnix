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
  # services.greetd =
  #   let
  #     cmd = "uwsm start hyprland-uwsm.desktop";
  #     command = "${pkgs.greetd.greetd}/bin/agreety --cmd '${cmd}'";
  #   in
  #   {
  #     enable = true;
  #     settings = {
  #       default_session = {
  #         inherit command;
  #       };
  #       initial_session = {
  #         command = cmd;
  #         user = config.modules.user.name;
  #       };
  #     };
  #   };

  services.displayManager = {
    autoLogin = {
      enable = true;
      user = username;
    };
    defaultSession = "hyprland-uwsm";
    sddm = {
      enable = true;
      wayland.enable = true;
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
    ]
    ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);
}
