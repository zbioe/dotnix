{ pkgs, config, lib, options, ... }:
with lib;
with lib.my;
let cfg = config.modules.keyboard;
in {
  options.modules.keyboard = with types; {
    layout = mkOpt str "br";
    variant = mkOpt str "";
    model = mkOpt str "";
    options = mkOpt' (listOf str) [ "ctrl:nocaps" ] "XDB Options";
  };
  config = mkIf (cfg.layout != "") {
    console.useXkbConfig = true;
    services.xserver.layout = cfg.layout;
    services.xserver.xkbVariant = cfg.variant;
    services.xserver.xkbModel = cfg.model;
    services.xserver.xkbOptions = concatStringsSep "," cfg.options;
  };
}
