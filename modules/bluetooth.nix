{ pkgs, config, lib, options, ... }:
with lib;
with lib.my;
let cfg = config.modules.bluetooth;
in {
  options.modules.bluetooth = with types; {
    enable = mkBoolOpt false;
    powerOnBoot = mkBoolOpt false;
  };

  config = mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = cfg.powerOnBoot;
    };
    services.blueman.enable = true;
    users.users.${config.user.name}.extraGroups = [ "bluetooth" ];
  };
}
