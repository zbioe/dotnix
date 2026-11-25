{
  config,
  lib,
  ...
}:
let
  inherit (lib) types mkOption mkIf;
  cfg = config.dotnix.hardware.bluetooth;
in
{
  options.dotnix.hardware.bluetooth = with types; {
    enable = lib.mkEnableOption "bluetooth";
    powerOnBoot = mkOption {
      type = bool;
      default = false;
    };
  };
  config = mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      inherit (cfg) powerOnBoot;
    };
  };
}
