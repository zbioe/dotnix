{pkgs, config, lib, options, ...}:
with lib;
with lib.my;
let 
  cfg = config.modules.wm.herbstluft;
in {
  options.modules.wm.herbstluft = with types; {
    enable = mkBoolOpt false;
  };
  config = mkIf cfg.enable {
    services.xserver.windowManager.herbstluftwm.enable = true;
  };
}
