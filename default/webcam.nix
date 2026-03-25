{ config, pkgs, ... }:

{
  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback
  ];
  
  boot.kernelModules = [ "v4l2loopback" ];

  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=10 card_label="Android Camera" exclusive_caps=1
  '';

  environment.systemPackages = with pkgs; [
    scrcpy        # transmission of screen
    v4l-utils     # list devices
    android-tools # adb
  ];

  # enable  ADB
  programs.adb.enable = true;
}
