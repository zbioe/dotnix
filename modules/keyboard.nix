{ pkgs, config, lib, options, ... }:
with lib;
with lib.my;
let cfg = config.modules.keyboard;
in {
  options.modules.keyboard = with types; {
    layout = mkOpt str "br";
    variant = mkOpt str "";
    model = mkOpt str "";
    earlySetup = mkBoolOpt false;
    options = mkOpt' (listOf str) [ "ctrl:nocaps" ] "XDB Options";
  };
  config = mkIf (cfg.layout != "") {
    console = {
      earlySetup = cfg.earlySetup;
      useXkbConfig = true;
      packages = [ pkgs.terminus_font ];
    };
    services.xserver.xkb.layout = cfg.layout;
    services.xserver.xkb.variant = cfg.variant;
    services.xserver.xkb.model = cfg.model;
    services.xserver.xkb.options = concatStringsSep "," cfg.options;
    # services.xserver.displayManager.sessionCommands =
    #   "${pkgs.xorg.xmodmap}/bin/xmodmap " + "${pkgs.writeText "xkb-layout" ''
    #     ! Map umlauts to RIGHT ALT + <key>
    #       keycode 108 = Mode_switch
    #       keysym p = p P bar section ssharp
    #       keysym l = l L backslash
    #   ''}";
  };
}
