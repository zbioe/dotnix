{
  config,
  lib,
  ...
}:
let
  inherit (lib) types mkOption mkIf;
  cfg = config.modules.audio;
in
{
  options.modules.audio = with types; {
    enable = mkOption {
      type = bool;
      default = false;
      description = ''
        Enable sound support.
      '';
    };
  };
  config = mkIf cfg.enable {
    security.rtkit.enable = true;
    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
      jack.enable = true;
    };
  };
}
