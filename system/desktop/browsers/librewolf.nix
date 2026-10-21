# LibreWolf following `theme` live: the nix-theme bridge recolors the browser
# and drives a patched Dark Reader, both add-ons from the store
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
    }
    // lib.optionalAttrs cfg.protonPass.enable {
      "78272b6fa58f4a1abaac99321d503a20@proton.me" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/proton-pass/latest.xpi";
      };
    };
  };

in
lib.mkIf cfg.librewolf.enable {
  environment.systemPackages = [ librewolf ];
}
