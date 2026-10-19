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
      default = false;
      description = ''
        enable Power on boot.
      '';
    };
  };
  config = mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = cfg.powerOnBoot;
      settings = {
        General = {
          FastConnectable = true;
        };
      };
    };
    # the MediaTek adapter doesn't fully support eSCO, so mSBC (wideband) calls
    # keep dropping the voice link; CVSD (narrowband) holds up
    services.pipewire.wireplumber.extraConfig."51-bt-no-msbc"."monitor.bluez.properties" = {
      "bluez5.enable-msbc" = false;
    };
    # USB autosuspend drops the link on MediaTek adapters (headsets disconnect
    # mid-use, and bluetoothd 5.86 then crashes on the lost AVDTP session)
    boot.extraModprobeConfig = ''
      options btusb enable_autosuspend=0
    '';
    services.blueman.enable = true;
  };
}
