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
    default = dotlib.mkMain [
      "librewolf"
      "chromium"
      "brave"
    ] "browser that opens links";
  };

  config.assertions = [ (dotlib.assertMain "dotnix.desktop.browsers" cfg) ];
}
