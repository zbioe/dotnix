{pkgs, config, lib, options, ...}:
with lib;
with lib.my;
let
  cfg = config.modules.keyboard;
in {
  options.modules.keyboard = with types; {
    layout = mkOpt str "br";
    options = mkOpt' (listOf str) ["ctrl:nocaps"] "XDB Options";
  };
  config = mkIf (cfg.layout != "") {
    console.useXkbConfig = true;
    services.xserver.layout = cfg.layout;
    services.xserver.xkbOptions = concatStringsSep "," cfg.options;
  };
}
