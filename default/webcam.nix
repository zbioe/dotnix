{ config, pkgs, ... }:

{
  boot.extraModulePackages = with config.boot.kernelPackages; [
    v4l2loopback
  ];

  boot.kernelModules = [ "v4l2loopback" ];

  boot.extraModprobeConfig = ''options v4l2loopback video_nr=10 card_label="Android" exclusive_caps=1'';

  environment.systemPackages = with pkgs; [
    scrcpy # transmission of screen
    v4l-utils # list devices
    ffmpeg # stream receiver
    pulseaudio # audio
    android-tools # adb
  ];

  # enable  ADB
  programs.adb.enable = true;

  services.pipewire.extraConfig.pipewire."99-rnnoise" = {
    "context.modules" = [
      {
        name = "libpipewire-module-filter-chain";
        args = {
          "node.description" = "Microfone sem ruído";
          "media.name" = "Microfone sem ruído";
          "filter.graph" = {
            nodes = [
              {
                type = "ladspa";
                name = "rnnoise";
                plugin = "${pkgs.rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so";
                label = "noise_suppressor_mono";
                control = {
                  "VAD Threshold (%)" = 50.0;
                  "VAD Grace Period (ms)" = 200;
                  "Retroactive VAD Grace (ms)" = 0;
                };
              }
            ];
          };
          "audio.rate" = 48000;
          "audio.position" = [ "MONO" ];
          "capture.props" = {
            "node.name" = "capture.rnnoise_source";
            "node.passive" = true;
          };
          "playback.props" = {
            "node.name" = "rnnoise_source";
            "media.class" = "Audio/Source";
          };
        };
      }
    ];
  };
}
