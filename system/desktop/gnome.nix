# The GNOME session, next to mango at the login screen, and for the accounts
# listed a Windows-like layout (what Zorin OS ships): a taskbar at the bottom
# with a start menu, the tray, icons on the desktop and the three window
# buttons. Those are defaults of a dconf profile of their own, picked by an
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
    environment.systemPackages = extensions;
    # (the browsers and the mail are the desktop's own)
    environment.gnome.excludePackages = with pkgs; [
      gnome-tour
      epiphany
      geary
      gnome-music
      gnome-maps
      gnome-contacts
    ];

    programs.dconf.profiles.${profile}.databases = [
      {
        settings = {
          "org/gnome/shell" = {
            enabled-extensions = map (e: e.extensionUuid) extensions;
            favorite-apps = lib.optional (cfg.browsers.default != null) browsers.${cfg.browsers.default} ++ [
              "org.gnome.Nautilus.desktop"
              "org.gnome.TextEditor.desktop"
              "org.gnome.Calculator.desktop"
            ];
          };
          "org/gnome/shell/extensions/arcmenu".menu-layout = "Windows";
          "org/gnome/desktop/wm/preferences".button-layout = "appmenu:minimize,maximize,close";
          "org/gnome/desktop/interface" = {
            enable-hot-corners = false;
            clock-show-weekday = true;
            show-battery-percentage = true;
          };
          "org/gnome/desktop/input-sources".sources = [
            (lib.gvariant.mkTuple [
              "xkb"
              (keyboard.layout + lib.optionalString (keyboard.variant != "") "+${keyboard.variant}")
            ])
          ];
        };
      }
    ];

    systemd.tmpfiles.rules = [
      "d /var/lib/AccountsService 0775 root root -"
      "d /var/lib/AccountsService/users 0700 root root -"
    ]
    ++ lib.concatMap (name: [
      "d ${home name}/.config 0700 ${name} users -"
      "d ${home name}/.config/environment.d 0755 ${name} users -"
      "f+ ${home name}/.config/environment.d/10-dotnix.conf 0644 ${name} users - DCONF_PROFILE=${profile}"
      # the session the login screen picks for them (not kept across boots)
      "f /var/lib/AccountsService/users/${name} 0600 root root - [User]\\nSession=gnome\\n"
    ]) cfg.gnome.windowsLike;
  };
}
