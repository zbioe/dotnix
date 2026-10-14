{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:
let
  darkreader = pkgs.callPackage ../../pkgs/darkreader { };
  nixTheme = pkgs.callPackage ../../pkgs/nix-theme {
    themeSet = config.theme.themes;
    inherit (config.stylix.base16) mkSchemeAttrs;
  };
  webuiTheme = pkgs.callPackage ../../pkgs/webui-theme { };
  braveTheme = pkgs.callPackage ../../pkgs/brave-theme { brave = unstable.brave; };
in
{
  imports = [
    ../../modules/stylix.nix
    ../theme
    ./mango.nix
    ./noctalia.nix
    ./rebuild.nix
    ./wifi-prefer.nix
    ./flake-updates.nix
    ./insightful.nix
    ./kdeconnect.nix
  ];

  stylix = {
    icons = {
      enable = true;
      package = pkgs.papirus-icon-theme;
      dark = "Papirus-Dark";
      light = "Papirus-Light";
    };
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 16; # smallest Bibata size (3 fell back to it anyway)
    };
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

  modules.stylix = {
    enable = true;
    autoEnable = true;
    theme = "gruvbox-dark-medium";
    polarity = "dark";
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

  # Dark Reader bridge of Brave (programs.brave below)
  xdg.configFile."BraveSoftware/Brave-Browser/NativeMessagingHosts/nix_theme.json".source =
    "${nixTheme}/etc/chromium/native-messaging-hosts/nix_theme.json";

  # Brave opens links; mimeapps.list stays user-managed, only these entries
  home.activation.defaultBrowser = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run ${pkgs.xdg-utils}/bin/xdg-mime default brave-browser.desktop \
      x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml
  '';

  # color-scheme, gtk-theme and icon-theme are set live by `theme`
  dconf.settings."org/gnome/desktop/interface".font-name =
    with config.stylix.fonts;
    "${sansSerif.name} ${toString sizes.applications}";
  programs = {
    bat = {
      enable = true;
    };
    foot = {
      enable = true;
      server.enable = true;
      settings = {
        main = {
          term = "xterm-256color";
        };
      };
    };
    alacritty = {
      enable = true;
      package = unstable.alacritty;
    };
    ghostty = {
      enable = true;
      package = unstable.ghostty;
      systemd.enable = true;
      installVimSyntax = true;
      installBatSyntax = true;
      enableBashIntegration = true;
      enableFishIntegration = true;
    };
    kitty = {
      enable = true;
      package = unstable.kitty;
      settings = {
        hide_window_decorations = "yes";
        titlebar_style = "none";
        window_border_width = 0;
        draw_minimal_borders = "no";
        placement_strategy = "top-right";
        tab_bar_style = "hidden";
        window_padding_width = 0;
        window_margin_width = 0;
        font_size = 10.26;
      };
    };
    yazi = {
      enable = true;
      enableFishIntegration = true;
      shellWrapperName = "yy";
    };
    # Dark Reader and its own pages following `theme`, as Chromium
    # (default/librewolf.nix); the browser itself on a theme extension of the
    # palette (pkgs/brave-theme), set up by the launcher. Only the last
    # --enable/--disable-features counts, so the package's own lists are
    # repeated here.
    brave = {
      enable = true;
      package = webuiTheme.brave { inherit (braveTheme) prelaunch; } (
        unstable.brave.override {
          commandLineArgs = lib.concatStringsSep " " [
            "--enable-wayland-ime"
            "--load-extension=${darkreader}/chromium,${nixTheme}/chromium"
            # + the address bar dropdown as a themable page, as in Chromium
            "--enable-features=AcceleratedVideoDecodeLinuxGL,AcceleratedVideoEncoder,WaylandWindowDecorations,WebUIOmniboxPopup,WebUIOmniboxFullPopup"
            "--disable-features=OutdatedBuildDetector,UseChromeOSDirectVideoDecoder,DisableLoadExtensionCommandLineSwitch"
          ];
        }
      );
    };
  };
  gtk = {
    enable = true;
    gtk3.extraConfig = {
      gtk-key-theme-name = "Emacs";
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig.gtk-key-theme-name = "Emacs";
    theme = lib.mkForce {
      name = "Gruvbox-Material-Dark";
      package = pkgs.gruvbox-material-gtk-theme;
    };
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
  ];

}
