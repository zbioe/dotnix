{pkgs, config, lib, options, ...}:
with lib;
with lib.my;
let 
  cfg = config.modules.audio;
in {
  options.modules.audio = with types; {
    enable = mkBoolOpt true;
  };
  config = mkIf cfg.enable {
    sound.enable = true;
    hardware.pulseaudio.enable = true;
    hardware.pulseaudio.support32Bit = true;
    hardware.pulseaudio.package = pkgs.pulseaudioFull;
    users.users.${config.user.name}.extraGroups = [
      "audio"
    ];
    hardware.firmware = [ pkgs.alsa-firmware ];
  };
}
