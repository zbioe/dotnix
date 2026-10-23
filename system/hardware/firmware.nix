# firmware updates through fwupd (LVFS): `fwupdmgr get-updates`, then
# `fwupdmgr update`; the Activity dashboard counts the pending ones
{
  config,
  lib,
  ...
}:
{
  options.dotnix.hardware.firmware.enable = lib.mkEnableOption "firmware updates (fwupd)";

  config = lib.mkIf config.dotnix.hardware.firmware.enable {
    services.fwupd.enable = true;
  };
}
