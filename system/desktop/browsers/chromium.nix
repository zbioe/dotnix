# Chromium following `theme` live: the same add-ons as LibreWolf, loaded by
# the wrapper; its own pages through pkgs/webui-theme
{
  config,
  lib,
  pkgs,
  unstable,
  base16,
  ...
}:
let
  cfg = config.dotnix.desktop.browsers;
  darkreader = pkgs.callPackage ../../../pkgs/darkreader { };
  nixTheme = pkgs.callPackage ../../../pkgs/nix-theme {
    themeSet = import ../../../home/theme/themes.nix { inherit pkgs; };
    inherit (base16.lib { inherit pkgs lib; }) mkSchemeAttrs;
  };

  webuiTheme = pkgs.callPackage ../../../pkgs/webui-theme { };

  # its own pages in the palette too (pkgs/webui-theme). Only the last
  # --enable/--disable-features counts, so the wrapper's list is repeated.
  chromium = webuiTheme.chromium (
    unstable.chromium.override {
      commandLineArgs = [
        "--load-extension=${darkreader}/chromium,${nixTheme}/chromium"
        # Chromium dropped --load-extension from its defaults
        "--disable-features=DisableLoadExtensionCommandLineSwitch"
        # internal pages, and the focused address bar, built from the theme colors
        "--enable-features=WaylandWindowDecorations,WebuiRefresh2026,WebUIOmniboxPopup,WebUIOmniboxFullPopup"
      ];
    }
  );
in
lib.mkIf cfg.chromium.enable {
  environment.systemPackages = [ chromium ];
  environment.etc."chromium/native-messaging-hosts/nix_theme.json".source =
    "${nixTheme}/etc/chromium/native-messaging-hosts/nix_theme.json";
}
