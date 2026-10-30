{
  config,
  lib,
  osConfig,
  ...
}:
{
  options.dotnix.desktop.wayvnc.enable = lib.mkEnableOption "wayvnc" // {
    default = osConfig.dotnix.services.wayvnc.enable;
  };

  config = lib.mkIf config.dotnix.desktop.wayvnc.enable {
    # localhost only: reached through the SSH tunnel, which is the auth
    services.wayvnc = {
      enable = true;
      autoStart = true;
      settings = {
        address = "127.0.0.1";
        inherit (osConfig.dotnix.services.wayvnc) port;
      };
    };
  };
}
