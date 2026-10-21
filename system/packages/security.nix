{
  config,
  lib,
  pkgs,
  unstable,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.packages.security;
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
        openssl # crypto toolkit
        mkpasswd # password hashes
        go-2fa # 2FA codes
        unstable.proton-pass # Proton Pass

        # web pentest
        caido-desktop # web security proxy
        burpsuite # web security proxy
        zap # web security scanner
      ]
    );
  };
}
