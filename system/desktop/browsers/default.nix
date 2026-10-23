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
    chromiumExtensions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Chrome Web Store ids Chromium and Brave install and keep updated.";
    };
    default = dotlib.mkMain [
      "librewolf"
      "chromium"
      "brave"
    ] "browser that opens links";
  };

  config = {
    assertions = [ (dotlib.assertMain "dotnix.desktop.browsers" cfg) ];

    dotnix.desktop.browsers.chromiumExtensions = lib.optional cfg.protonPass.enable "ghmbeldphafepmbegfdlkpapadhbakde";

    # one forcelist for every extension: policy files don't merge their lists,
    # one of them just wins
    environment.etc =
      let
        policy = builtins.toJSON {
          ExtensionInstallForcelist = map (
            id: "${id};https://clients2.google.com/service/update2/crx"
          ) cfg.chromiumExtensions;
        };
      in
      lib.mkIf (cfg.chromiumExtensions != [ ]) {
        "chromium/policies/managed/extensions.json" = lib.mkIf cfg.chromium.enable { text = policy; };
        "brave/policies/managed/extensions.json" = lib.mkIf cfg.brave.enable { text = policy; };
      };
  };
}
