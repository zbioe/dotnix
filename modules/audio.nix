{
  pkgs,
  config,
  lib,
  options,
  ...
}:
with lib;
with lib.my;
let
  cfg = config.modules.audio;
in
{
  options.modules.audio = with types; {
    enable = mkBoolOpt true;
  };
  config = mkIf cfg.enable {
    hardware.pulseaudio.enable = false;
    hardware.pulseaudio.support32Bit = false;
    hardware.pulseaudio.package = pkgs.pulseaudioFull;
    users.users.${config.user.name}.extraGroups = [ "audio" ];
    hardware.firmware = [ pkgs.alsa-firmware ];
  };
}
