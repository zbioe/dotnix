# secrets/*.yaml (sops), decrypted at boot into /run/secrets: by the host's SSH
# key, or by your own age key that dotnix-install leaves on a new host
{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.dotnix.core.secrets;
in
{
  imports = [ inputs.sops.nixosModules.sops ];

  options.dotnix.core.secrets = {
    enable = lib.mkEnableOption "the secrets of secrets/ (sops-nix)";
    keyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/persist/var/lib/sops/age.key";
      description = "Your age key on this host (it must exist); without it, only the SSH host key.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops = {
      defaultSopsFile = ../../secrets/common.yaml;
      # read before impermanence binds /etc/ssh
      age.sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
      age.keyFile = cfg.keyFile;
      gnupg.sshKeyPaths = [ ];
      secrets.user-password.neededForUsers = true;
    };
    dotnix.core.user.passwordFile = lib.mkDefault config.sops.secrets.user-password.path;
  };
}
