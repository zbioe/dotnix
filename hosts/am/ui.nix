{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Compositor
  programs.hyprland = {
    enable = true;
    # nvidiaPatches = true;
    xwayland.enable = true;
  };

  environment.sessionVariables = {
    # If your cursor becomes invisible
    WLR_NO_HARDWARE_CURSORS = "1";
    # Hint electron apps to use wayland
    NIXOS_OZONE_WL = "1";
  };

  # Display Manager
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.greetd}/bin/agreety --cmd Hyprland";
      };
      initial_session = {
        command = "Hyprland";
        user = "zbioe";
      };
    };
  };

  # Hardware
  hardware = {
    # Opengl
    graphics.enable = true;

    # Most wayland compositors need this
    nvidia.modesetting.enable = true;
  };

  # Portal
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  # Packages
  environment.systemPackages = with pkgs; [
    # terminal
    kitty
    alacritty
    # bar
    (waybar.overrideAttrs (oldAttrs: {
      mesonFlags = oldAttrs.mesonFlags ++ [ "-Dexperimental=true" ];
    }))
    # notification
    dunst
    libnotify
    # wallpaper
    swww

    # launcher
    wofi

    # file manager
    pcmanfm

    # player manager
    playerctl

    # brightness manager
    brightnessctl

    # printscreen with selection
    # grim -l 0 -g "$(slurp)" - | wl-copy
    wl-clipboard # cli interface to clipboard (xclip anternative)
    slurp # select utility
    grim # screenshot utility
  ];

  fonts.packages = with pkgs; [
    nerdfonts
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-emoji
    liberation_ttf
    fira-code
    fira-code-symbols
    dina-font
    proggyfonts
  ];
}
