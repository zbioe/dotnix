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
      settings = {
        General = {
          FastConnectable = true;
        };
      };
    };
    # USB autosuspend drops the link on MediaTek adapters (headsets disconnect
    # mid-use, and bluetoothd 5.86 then crashes on the lost AVDTP session)
    boot.extraModprobeConfig = ''
      options btusb enable_autosuspend=0
    '';
    services.blueman.enable = true;
  };
}
