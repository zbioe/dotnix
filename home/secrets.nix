# Your secrets (secrets/*.yaml for you only), decrypted at login into
# $XDG_RUNTIME_DIR/secrets with your age key
{ config, ... }:
{
  sops.age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";
}
