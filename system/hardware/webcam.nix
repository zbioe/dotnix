# a virtual camera (/dev/video10) other apps can feed, e.g. the phone through scrcpy
{
  config,
  lib,
  ...
}:
{
  options.dotnix.hardware.webcam.enable = lib.mkEnableOption "a virtual webcam (v4l2loopback)";

  config = lib.mkIf config.dotnix.hardware.webcam.enable {
    boot.extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
    boot.kernelModules = [ "v4l2loopback" ];
    boot.extraModprobeConfig = ''options v4l2loopback video_nr=10 card_label="Android" exclusive_caps=1'';
  };
}
