{
  osConfig,
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./terminals.nix
    ./browsers.nix
    ./librewolf
    ./mango
    ./noctalia
    ./rebuild.nix
    ./wifi
    ./vpn
    ./pass
    ./updates
    ./insightful
    ./kdeconnect.nix
  ];

  options.dotnix.desktop.enable = lib.mkEnableOption "the desktop (cursor, icons, GTK, apps)" // {
    default = osConfig.dotnix.desktop.enable;
  };

  config = lib.mkIf config.dotnix.desktop.enable {
    home.pointerCursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 16; # smallest Bibata size (3 fell back to it anyway)
      gtk.enable = true;
      x11.enable = true;
    };

    # Papirus has no icon of its own for these apps: point their icon names at
    # the closest Papirus one (user hicolor wins over the apps' own), so the
    # launcher and bars keep one look. Brand icons Papirus lacks stay as they are.
    xdg.dataFile =
      lib.mapAttrs'
        (name: target: {
          name = "icons/hicolor/scalable/apps/${name}.svg";
          value.source = "${pkgs.papirus-icon-theme}/share/icons/Papirus/64x64/apps/${target}.svg";
        })
        {
          zap = "zaproxy";
          scrcpy = "guiscrcpy";
          "com.jaoushingan.WaydroidHelper" = "waydroid";
          "network.cycles.wdisplays" = "preferences-desktop-display";
          bottom-system-monitor = "utilities-system-monitor";
          oxker = "docker-desktop";
          yazi = "system-file-manager";
          tectonic = "texstudio";
          noctalia = "preferences-desktop";
          input-keyboard = "preferences-desktop-keyboard";
          blueman-device = "blueman";
          freelens = "kontena-lens";
          mtkclient = "android-file-transfer";
        };
    # its desktop file comes with no icon at all
    xdg.desktopEntries.mtkclient = {
      name = "MTKClient";
      comment = "MediaTek flash and repair tool";
      exec = "mtk_gui";
      icon = "mtkclient";
      categories = [ "Development" ];
    };

    # Fcitx can't hand the keyboard layout to mango (it comes from the mango
    # config anyway): no warning about it at every login
    xdg.configFile."fcitx5/conf/notifications.conf" = {
      force = true;
      text = ''
        [HiddenNotifications]
        0=wayland-diagnose-other
      '';
    };

    xdg.configFile."kdeglobals".text = ''
      [UiSettings]
      ColorScheme=qt6ct
    '';

    programs = {
      bat = {
        enable = true;
      };
      yazi = {
        enable = true;
        enableFishIntegration = true;
        shellWrapperName = "yy";
      };
    };
    gtk = {
      enable = true;
      # theme, icons and dark preference: set by `theme` (home/theme)
      gtk3.extraConfig.gtk-key-theme-name = "Emacs";
      gtk4.extraConfig.gtk-key-theme-name = "Emacs";
    };
    home.packages = with pkgs; [
      libnotify
      networkmanagerapplet
      wirelesstools
      brightnessctl
      wl-clipboard
      hyprpicker
      nautilus
      gruvbox-gtk-theme
      gruvbox-material-gtk-theme
      # kubernetes
      freelens-bin
      k9s
      kdash
      seabird
      kubetui
      reco
    ];
  };
}
