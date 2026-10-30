{ config, lib, ... }:
let
  cfg = config.dotnix.services.wayvnc;
in
{
  options.dotnix.services.wayvnc = {
    enable = lib.mkEnableOption "the desktop over VNC, reached through an SSH tunnel";
    port = lib.mkOption {
      type = lib.types.port;
      default = 5900;
    };
    keys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "ssh-ed25519 AAAA... phone" ];
      description = "SSH keys that may open the tunnel to VNC and nothing else (no shell).";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.dotnix.network.ssh.enable;
        message = "dotnix.services.wayvnc: the tunnel needs dotnix.network.ssh.enable";
      }
    ];
    users.users.${config.dotnix.core.user.name}.openssh.authorizedKeys.keys = map (
      k: ''restrict,port-forwarding,permitopen="127.0.0.1:${toString cfg.port}" ${k}''
    ) cfg.keys;
  };
}
