{
  config,
  lib,
  pkgs,
  dotlib,
  unstable,
  ...
}:
let
  cfg = config.dotnix.desktop;
  sessions.mango = "mango-uwsm";
  inherit (lib) mkIf mkOption types;
in
{
  imports = [
    ./mango.nix
    ./sddm.nix
    ./fonts.nix
    ./browsers
    ./boot-screens.nix
    ./activity.nix
  ];

  options.dotnix.desktop = {
    enable = lib.mkEnableOption "the graphical desktop";
    mango.enable = dotlib.mkItem cfg "the mango session";
    default = dotlib.mkMain [ "mango" ] "session logged into";
    greeter = mkOption {
      type = types.nullOr (types.enum [ "sddm" ]);
      default = null;
    };
    autoLogin = lib.mkEnableOption "logging into the default session without the greeter";
    inputMethod = mkOption {
      type = types.nullOr (types.enum [ "fcitx5" ]);
      default = null;
    };
    secrets = mkOption {
      type = types.nullOr (types.enum [ "gnome-keyring" ]);
      default = null;
      description = "Who answers the Secret Service (browsers, noctalia's calendar, backups).";
    };
  };

  config = mkIf cfg.enable {
    assertions = [ (dotlib.assertMain "dotnix.desktop" cfg) ];

    environment.sessionVariables = {
      NIXOS_OZONE_WL = "1";
      GDK_BACKEND = "wayland";
      # Emacs xwidgets fight the GPU's hardware acceleration without these
      WEBKIT_DISABLE_DMABUF_RENDERER = "1";
      WEBKIT_DISABLE_COMPOSITING_MODE = "1";
    };

    i18n.inputMethod = mkIf (cfg.inputMethod == "fcitx5") {
      enable = true;
      type = "fcitx5";
      fcitx5.waylandFrontend = true;
      fcitx5.addons = [ pkgs.fcitx5-gtk ];
    };

    services.gnome.gnome-keyring.enable = cfg.secrets == "gnome-keyring";
    # its keyrings without a password broke on secrets holding a newline (Proton VPN's)
    nixpkgs.overlays = lib.optional (cfg.secrets == "gnome-keyring") (
      _: prev: {
        gnome-keyring = prev.gnome-keyring.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ../../overlays/patches/gnome-keyring-textual-secret-escape.patch
          ];
        });
      }
    );

    services.displayManager.defaultSession = mkIf (cfg.default != null) sessions.${cfg.default};
    services.displayManager.autoLogin = mkIf cfg.autoLogin {
      enable = true;
      user = config.dotnix.core.user.name;
    };

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = [ "gtk" ];
    };
    # GTK settings backend (`theme` writes the color scheme there)
    programs.dconf.enable = true;
    # Qt apps through qt5ct/qt6ct, whose palette and fonts `theme` writes
    qt = {
      enable = true;
      platformTheme = "qt5ct";
    };
    # GTK4 reloads its gtk.css when it changes, so libadwaita apps follow `theme`
    # live; swapped into the closure without rebuilding the apps
    system.replaceDependencies.replacements = import ../../overlays/gtk4-live.nix [
      pkgs.gtk4
      unstable.gtk4
    ];

    # location from nearby Wi-Fi, for noctalia's weather and sunrise/sunset
    services.geoclue2 = {
      enable = true;
      appConfig.geoclue-where-am-i = {
        isAllowed = true;
        isSystem = false;
      };
    };

    services.udev.packages = [ pkgs.gnome-settings-daemon ];
    services.gvfs.enable = true;
    services.udisks2.enable = true;
    services.tumbler.enable = true;
  };
}
