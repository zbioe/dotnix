# Brave is a user package; LibreWolf and Chromium come from the system
{
  config,
  lib,
  osConfig,
  pkgs,
  unstable,
  base16,
  ...
}:
let
  cfg = config.dotnix.desktop.browsers;
  desktopFiles = {
    brave = "brave-browser.desktop";
    librewolf = "librewolf.desktop";
    chromium = "chromium-browser.desktop";
  };
  darkreader = pkgs.callPackage ../../pkgs/darkreader { };
  nixTheme = pkgs.callPackage ../../pkgs/nix-theme {
    themeSet = config.dotnix.theme.themes;
    inherit (base16.lib { inherit pkgs lib; }) mkSchemeAttrs;
  };
  webuiTheme = pkgs.callPackage ../../pkgs/webui-theme { };
  braveTheme = pkgs.callPackage ../../pkgs/brave-theme { inherit (unstable) brave; };
in
{
  options.dotnix.desktop.browsers = {
    brave.enable = lib.mkEnableOption "Brave" // {
      default = osConfig.dotnix.desktop.browsers.brave.enable;
    };
    default = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum (lib.attrNames desktopFiles));
      default = osConfig.dotnix.desktop.browsers.default;
      description = "The browser that opens links.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.brave.enable {
      # Dark Reader bridge of Brave (programs.brave below)
      xdg.configFile."BraveSoftware/Brave-Browser/NativeMessagingHosts/nix_theme.json".source =
        "${nixTheme}/etc/chromium/native-messaging-hosts/nix_theme.json";

      programs = {
        # Dark Reader and its own pages following `theme`, as Chromium
        # (system/desktop/browsers); the browser itself on a theme extension of the
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
    })
    (lib.mkIf (cfg.default != null) {
      # mimeapps.list stays user-managed, only these entries
      home.activation.defaultBrowser = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        run ${pkgs.xdg-utils}/bin/xdg-mime default ${desktopFiles.${cfg.default}} \
          x-scheme-handler/http x-scheme-handler/https text/html application/xhtml+xml
      '';
    })
  ];
}
