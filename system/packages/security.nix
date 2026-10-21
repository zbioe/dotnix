{
  config,
  lib,
  pkgs,
  unstable,
  inputs,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.packages.security;
  proton-pass = pkgs.callPackage ../../pkgs/proton-pass {
    inherit (unstable) proton-pass;
    src = inputs.proton-pass;
  };
in
{
  options.dotnix.packages.security = dotlib.mkPackages "passwords and security tools";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = dotlib.packagesOf cfg (
      with pkgs;
      [
        pass # password store
        gnupg # GNU privacy guard
        age # file encryption
        sops # edits secrets/*.yaml
        ssh-to-age # a host's age key from its SSH key
        openssl # crypto toolkit
        mkpasswd # password hashes
        go-2fa # 2FA codes
        proton-pass # Proton Pass, newest stable

        # web pentest
        caido-desktop # web security proxy
        burpsuite # web security proxy
        zap # web security scanner
      ]
    );
  };
}
