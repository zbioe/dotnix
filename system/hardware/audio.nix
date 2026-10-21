{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.hardware.audio;
in
{
  options.dotnix.hardware.audio = {
    enable = lib.mkEnableOption "sound";
    server = lib.mkOption {
      type = lib.types.enum [ "pipewire" ];
      default = "pipewire";
    };
    noiseSuppression.enable = lib.mkEnableOption "a noise-suppressed microphone (rnnoise)";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf (cfg.server == "pipewire") {
        security.rtkit.enable = true;
        services.pipewire = {
          enable = true;
          alsa.enable = true;
          alsa.support32Bit = true;
          pulse.enable = true;
          jack.enable = true;
        };
      })
      (lib.mkIf cfg.noiseSuppression.enable {
        # the headset profile (mic) stays until changed by hand: the noise filter
        # records "passively", which WirePlumber's auto-switch doesn't count, so it
        # kept flipping the headset back to music (A2DP, no mic) under it
        services.pipewire.wireplumber.extraConfig."51-no-bt-autoswitch"."wireplumber.settings" = {
          "bluetooth.autoswitch-to-headset-profile" = false;
        };

        services.pipewire.extraConfig.pipewire."99-rnnoise" = {
          "context.modules" = [
            {
              name = "libpipewire-module-filter-chain";
              args = {
                "node.description" = "Noise-suppressed microphone";
                "media.name" = "Noise-suppressed microphone";
                "filter.graph" = {
                  nodes = [
                    {
                      type = "ladspa";
                      name = "rnnoise";
                      plugin = "${pkgs.rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so";
                      label = "noise_suppressor_mono";
                      control = {
                        "VAD Threshold (%)" = 0.0; # denoise only: never mute a quiet (Bluetooth) mic
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
      })
    ]
  );
}
