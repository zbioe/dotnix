# The GNOME session, next to mango at the login screen, and for the accounts
# listed a Windows-like layout (what Zorin OS ships): a taskbar at the bottom
# with a start menu, the tray, icons on the desktop and the three window
# buttons, with NixOS's logo and wallpaper, Inter, the Tela icons and the
# Bibata cursor. Those are defaults of a dconf profile of their own, picked by an
# environment.d file in their home, so they stay free to change them and
# the other accounts see none of it.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.desktop;
  profile = "dotnix-windows-like";
  extensions = with pkgs.gnomeExtensions; [
    dash-to-panel # the taskbar
    arcmenu # its start menu
    appindicator # tray icons
    desktop-icons-ng-ding # files on the desktop
  ];
  browsers = {
    brave = "brave-browser.desktop";
    chromium = "chromium-browser.desktop";
    librewolf = "librewolf.desktop";
  };
  keyboard = config.services.xserver.xkb;
  source = keyboard.layout + lib.optionalString (keyboard.variant != "") "+${keyboard.variant}";
  wallpapers = pkgs.nixos-artwork.wallpapers;
  logo = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
  pinned = lib.optional (cfg.browsers.default != null) browsers.${cfg.browsers.default} ++ [
    "org.gnome.Nautilus.desktop"
    "org.gnome.TextEditor.desktop"
    "org.gnome.Calculator.desktop"
  ];
  # the taskbar: the menu, the windows, then the tray, the clock and the
  # desktop's corner; its own apps button gives way to the menu (keyed by
  # monitor: by index, which it falls back to)
  taskbar = lib.genAttrs [ "0" "1" "2" "3" ] (
    _:
    lib.imap0
      (i: element: {
        inherit element;
        visible =
          !lib.elem element [
            "showAppsButton"
            "activitiesButton"
          ];
        position = if i < 4 then "stackedTL" else "stackedBR";
      })
      [
        "showAppsButton"
        "activitiesButton"
        "leftBox"
        "taskbar"
        "centerBox"
        "rightBox"
        "dateMenu"
        "systemMenu"
        "desktopButton"
      ]
  );
  # what the system starts for every session and GNOME already does itself
  # (Bluetooth), or that is the main account's (its phone, its input method)
  notStarted = [
    "blueman"
    "org.fcitx.Fcitx5"
    "org.kde.kdeconnect.daemon"
  ];
  home = name: config.users.users.${name}.home;
in
{
  options.dotnix.desktop.gnome = {
    enable = lib.mkEnableOption "the GNOME session";
    windowsLike = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "amanda" ];
      description = "Accounts logged into GNOME, laid out like Windows.";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.gnome.enable) {
    services.desktopManager.gnome.enable = true;
    # GNOME's own pick of portals (the camera's permission, the dialogs) in
    # GNOME sessions; mango's list replaced it, leaving them to guesswork
    xdg.portal.configPackages = [ pkgs.gnome-session ];
    environment.systemPackages = extensions;
    # only the session is the system's: GNOME's apps (and their file
    # associations) go to the accounts below, and what it would run or
    # open for every account stays off
    services.gnome.core-apps.enable = false;
    services.avahi.enable = false;
    services.dleyna.enable = false;
    services.gnome = {
      rygel.enable = false;
      gnome-user-share.enable = false;
      gnome-remote-desktop.enable = false;
      gnome-initial-setup.enable = false;
      gnome-browser-connector.enable = false;
    };
    environment.gnome.excludePackages = [
      pkgs.gnome-tour
      pkgs.orca
    ];
    users.users = lib.genAttrs cfg.gnome.windowsLike (_: {
      packages = with pkgs; [
        nautilus # files
        gnome-text-editor
        gnome-calculator
        loupe # images
        papers # PDFs
        showtime # videos
        file-roller # archives
        gnome-system-monitor
        gnome-console
        snapshot # camera
        cameractrls-gtk4 # its color, brightness and focus
        tela-icon-theme
        bibata-cursors
        adw-gtk3 # GTK3 apps looking like the rest
      ];
    });

    fonts.packages = [ pkgs.inter ];

    # links open in the desktop's browser (their own choice wins)
    environment.etc."xdg/gnome-mimeapps.list" = lib.mkIf (cfg.browsers.default != null) {
      text = ''
        [Default Applications]
        ${lib.concatMapStrings (type: "${type}=${browsers.${cfg.browsers.default}}\n") [
          "x-scheme-handler/http"
          "x-scheme-handler/https"
          "text/html"
          "application/xhtml+xml"
        ]}
      '';
    };

    # the camera app allowed without asking (the portal refused it
    # without a prompt), at each login of theirs
    systemd.user.services.dotnix-camera-allowed = lib.mkIf (cfg.gnome.windowsLike != [ ]) {
      description = "The camera app allowed to use the camera";
      wantedBy = [ "gnome-session-initialized.target" ];
      after = [ "gnome-session-initialized.target" ];
      # (|: any of them)
      unitConfig.ConditionUser = map (name: "|${name}") cfg.gnome.windowsLike;
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe pkgs.flatpak} permission-set devices camera org.gnome.Snapshot yes";
      };
    };

    programs.dconf.profiles.${profile}.databases = [
      {
        # what makes it this layout holds even over what the extensions
        # saved on their first run; the rest are defaults
        locks = [
          "/org/gnome/shell/extensions/dash-to-panel/panel-element-positions"
          "/org/gnome/shell/extensions/arcmenu/menu-layout"
          "/org/gnome/shell/extensions/arcmenu/menu-button-icon"
          # the ThinkPad's layout, whose right Ctrl is the ? key
          "/org/gnome/desktop/input-sources/sources"
          # the camera on (its privacy switch)
          "/org/gnome/desktop/privacy/disable-camera"
        ];
        settings = {
          "org/gnome/shell" = {
            enabled-extensions = map (e: e.extensionUuid) extensions;
            favorite-apps = pinned;
          };
          "org/gnome/shell/extensions/dash-to-panel" = {
            panel-element-positions = builtins.toJSON taskbar;
            # the desktop at login, not the overview
            hide-overview-on-startup = true;
            animate-appicon-hover = true;
            appicon-margin = lib.gvariant.mkInt32 4;
            appicon-padding = lib.gvariant.mkInt32 6;
          };
          "org/gnome/shell/extensions/arcmenu" = {
            # (its own layout is the menu Zorin's came from)
            menu-layout = "arcmenu";
            # the categories first, then their apps
            default-menu-view = "Categories_List";
            menu-button-icon = logo;
            menu-button-icon-size = lib.gvariant.mkInt32 28;
            pinned-apps = map (id: [ (lib.gvariant.mkDictionaryEntry "id" id) ]) (
              pinned ++ [ "org.gnome.Settings.desktop" ]
            );
          };
          "org/gnome/desktop/wm/preferences".button-layout = "appmenu:minimize,maximize,close";
          "org/gnome/mutter".center-new-windows = true;
          "org/gnome/desktop/interface" = {
            enable-hot-corners = false;
            clock-show-weekday = true;
            show-battery-percentage = true;
            accent-color = "blue";
            gtk-theme = "adw-gtk3";
            icon-theme = "Tela";
            cursor-theme = "Bibata-Modern-Classic";
            cursor-size = lib.gvariant.mkInt32 16;
            font-name = "Inter 11";
            document-font-name = "Inter 11";
          };
          "org/gnome/desktop/background" = {
            picture-uri = "file://${wallpapers.nineish.gnomeFilePath}";
            picture-uri-dark = "file://${wallpapers.nineish-dark-gray.gnomeFilePath}";
          };
          "org/gnome/desktop/screensaver".picture-uri = "file://${wallpapers.nineish.gnomeFilePath}";
          "org/gnome/desktop/peripherals/touchpad".tap-to-click = true;
          "org/gnome/desktop/privacy".disable-camera = false;
          "org/gnome/desktop/input-sources".sources = [
            (lib.gvariant.mkTuple [
              "xkb"
              source
            ])
          ];
        };
      }
    ];

    systemd.tmpfiles.rules = [
      "d /var/lib/AccountsService 0775 root root -"
      "d /var/lib/AccountsService/users 0700 root root -"
    ]
    ++ lib.concatMap (
      name:
      [
        "d ${home name}/.config 0700 ${name} users -"
        "d ${home name}/.config/environment.d 0755 ${name} users -"
        "f+ ${home name}/.config/environment.d/10-dotnix.conf 0644 ${name} users - DCONF_PROFILE=${profile}"
        "d ${home name}/.config/autostart 0755 ${name} users -"
        # GNOME's portal choice where the portal always looks (its own config
        # dir): started early by the shell, it missed the system's (the
        # camera was refused without asking)
        "d ${home name}/.config/xdg-desktop-portal 0755 ${name} users -"
        "L+ ${home name}/.config/xdg-desktop-portal/gnome-portals.conf - - - - ${pkgs.gnome-session}/share/xdg-desktop-portal/gnome-portals.conf"
      ]
      ++ map (
        entry:
        "f+ ${home name}/.config/autostart/${entry}.desktop 0644 ${name} users - [Desktop Entry]\\nHidden=true\\n"
      ) notStarted
      ++ [
        # the session the login screen picks for them (not kept across boots)
        "f /var/lib/AccountsService/users/${name} 0600 root root - [User]\\nSession=gnome\\n\\n[InputSource0]\\nxkb=${source}\\n"
      ]
    ) cfg.gnome.windowsLike;
  };
}
