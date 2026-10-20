# Browsers following `theme` live (home/theme). LibreWolf: the nix-theme
# bridge recolors the browser and drives a patched Dark Reader, both add-ons
# from the store through policies. Chromium: the same pair unpacked from the
# store, loaded by the wrapper; the UI itself follows GTK. Brave: see
# default/brave.nix.
{
  lib,
  pkgs,
  unstable,
  base16,
  ...
}:
let
  darkreader = pkgs.callPackage ../pkgs/darkreader { };
  nixTheme = pkgs.callPackage ../pkgs/nix-theme {
    themeSet = import ../home/theme/themes.nix { inherit pkgs; };
    inherit (base16.lib { inherit pkgs lib; }) mkSchemeAttrs;
  };

  librewolf = unstable.librewolf.override {
    nativeMessagingHosts = [ nixTheme ];
    # both add-ons are built here, so they are unsigned
    extraPrefs = ''
      lockPref("xpinstall.signatures.required", false);
    '';
    extraPolicies.ExtensionSettings = {
      ${darkreader.addonId} = {
        installation_mode = "force_installed";
        install_url = "file://${darkreader}/darkreader.xpi";
        # keep AMO from replacing it with the unpatched release
        updates_disabled = true;
      };
      ${nixTheme.addonId} = {
        installation_mode = "force_installed";
        install_url = "file://${nixTheme}/nix-theme.xpi";
      };
    };
  };

  webuiTheme = pkgs.callPackage ../pkgs/webui-theme { };

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
{
  environment.systemPackages = [
    librewolf
    chromium
  ];
  environment.etc."chromium/native-messaging-hosts/nix_theme.json".source =
    "${nixTheme}/etc/chromium/native-messaging-hosts/nix_theme.json";
}
