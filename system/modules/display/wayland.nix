{ config, pkgs, ... }: {

  # Sway Compositor
  programs.sway = {
    enable = true;
    wrapperFeatures.base = true;
    wrapperFeatures.gtk = true;
    extraPackages = with pkgs; [
      mako
      grim
      wofi
      slurp
      waybar
      swaybg
      swayidle
      swaylock
      xwayland
      qt5.qtwayland
      flashfocus
      wf-recorder
      wl-clipboard
      sway-contrib.grimshot
      xcape
      autorandr
      # firefox-wayland
    ];
    extraSessionCommands = ''
      export GDK_SCALE=1
      export QT_AUTO_SCREEN_SCALE_FACTOR=0
      export SDL_VIDEODRIVER=wayland
      # needs qt5.qtwayland in systemPackages
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
      # Fix for some Java AWT applications (e.g. Android Studio),
      # use this if they aren't displayed properly:
      export _JAVA_AWT_WM_NONREPARENTING=1
    '';
  };
  services.pipewire.enable = true;
  services.flatpak.enable = true;
  security.rtkit.enable = true;
  xdg.portal = {
    enable = true;
    gtkUsePortal = false;
    extraPortals = with pkgs;
      [
        xdg-desktop-portal-wlr
        # xdg-desktop-portal-gtk
      ];
  };

  environment.sessionVariables = {
    # MOZ_ENABLE_WAYLAND = "1";
    # MOZ_USE_XINPUT2 = "1";
    XKB_DEFAULT_OPTIONS = "compose:ralt,ctrl:swapcaps";
    XKB_DEFAULT_LAYOUT = "br";
    XDG_SESSION_TYPE = "wayland";
    XDG_CURRENT_DESKTOP = "sway";
  };
  #  services.greetd = {
  #    enable = true;
  #    restart = true;
  #    settings = {
  #      default_session = {
  #        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd sway";
  #        user = "zbioe";
  #      };
  #      initial_session = {
  #        command = "sway";
  #        user = "zbioe";
  #      };
  #    };
  #  };

}
