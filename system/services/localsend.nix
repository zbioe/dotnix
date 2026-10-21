{ config, lib, ... }:
{
  options.dotnix.services.localsend.enable =
    lib.mkEnableOption "LocalSend (AirDrop-like file sharing)";

  config.programs.localsend.enable = config.dotnix.services.localsend.enable;
}
