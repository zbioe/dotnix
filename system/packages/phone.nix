{
  config,
  lib,
  pkgs,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.packages.phone;
in
{
  options.dotnix.packages.phone = dotlib.mkPackages "Android phones";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = dotlib.packagesOf cfg (
      with pkgs;
      [
        android-tools # adb
        scrcpy # phone screen on the desktop
        v4l-utils # video devices
        pulseaudio # pactl for the phone's audio
      ]
    );
  };
}
