{ config, lib, ... }:
{
  options.dotnix.network.ssh.enable = lib.mkEnableOption "the SSH server (keys only)";

  config = lib.mkIf config.dotnix.network.ssh.enable {
    services.openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };
}
