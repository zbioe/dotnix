# brightness of external monitors over DDC/CI, used by noctalia
{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.dotnix.hardware.ddc.enable = lib.mkEnableOption "monitor control over DDC/CI";

  config = lib.mkIf config.dotnix.hardware.ddc.enable {
    hardware.i2c.enable = true;
    environment.systemPackages = [ pkgs.ddcutil ];
  };
}
