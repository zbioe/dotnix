{
  config,
  lib,
  ...
}:
let
  inherit (lib) types mkOption mkIf;
  cfg = config.modules.bluetooth;
in
{
  options.modules.bluetooth = with types; {
    enable = mkOption {
      type = bool;
      default = false;
      description = ''
        Enable sound support.
      '';
    };
    powerOnBoot = mkOption {
      type = bool;
      default = true;
      description = ''
        enable Power on boot.
      '';
    };
  };
  config = mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = cfg.powerOnBoot;
    };
    services.blueman.enable = true;
  };
}
