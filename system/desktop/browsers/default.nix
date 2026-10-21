# Brave itself is installed per user (home); here its system side
{
  config,
  lib,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.desktop.browsers;
in
{
  imports = [
    ./librewolf.nix
    ./chromium.nix
    ./brave.nix
  ];

  options.dotnix.desktop.browsers = {
    enable = lib.mkEnableOption "the browsers";
    librewolf.enable = dotlib.mkItem cfg "LibreWolf";
    chromium.enable = dotlib.mkItem cfg "Chromium";
    brave.enable = dotlib.mkItem cfg "Brave";
    protonPass.enable = lib.mkEnableOption "the Proton Pass extension in every browser";
    default = dotlib.mkMain [
      "librewolf"
      "chromium"
      "brave"
    ] "browser that opens links";
  };

  config = {
    assertions = [ (dotlib.assertMain "dotnix.desktop.browsers" cfg) ];

    # Chromium and Brave install it from the Chrome Web Store, and keep it updated
    environment.etc =
      let
        policy = builtins.toJSON {
          ExtensionInstallForcelist = [
            "ghmbeldphafepmbegfdlkpapadhbakde;https://clients2.google.com/service/update2/crx"
          ];
        };
      in
      lib.mkIf cfg.protonPass.enable {
        "chromium/policies/managed/proton-pass.json" = lib.mkIf cfg.chromium.enable { text = policy; };
        "brave/policies/managed/proton-pass.json" = lib.mkIf cfg.brave.enable { text = policy; };
      };
  };
}
