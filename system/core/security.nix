{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.core.sudo;
  pamEither = pkgs.callPackage ../../pkgs/pam-either { };
  sudoAuth = config.security.pam.services.sudo.rules.auth;
in
{
  options.dotnix.core.sudo.fingerprintOrPassword.enable = lib.mkEnableOption ''
    sudo taking the fingerprint or the password, whichever comes first
    (pam_either, pkgs/pam-either), instead of the reader first and the
    password only after it times out'';

  config = lib.mkMerge [
    {
      # sudo asks for the fingerprint (fprintd, where there's a reader) or the
      # password: nothing running as the user becomes root unnoticed
      security.sudo.wheelNeedsPassword = true;
      # once authenticated, sudo doesn't ask again for 30 minutes in any of the
      # user's terminals (not only the one it was asked in)
      security.sudo.extraConfig = ''
        Defaults timestamp_type=global
        Defaults timestamp_timeout=30
      '';

      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
        # GTK prompt from gcr (themed like the rest; curses on a tty)
        pinentryPackage = pkgs.pinentry-gnome3;
      };
    }

    (lib.mkIf cfg.fingerprintOrPassword.enable {
      assertions = [
        {
          assertion = config.services.fprintd.enable;
          message = "dotnix.core.sudo.fingerprintOrPassword needs a fingerprint reader (services.fprintd)";
        }
      ];

      security.pam.services = {
        # the two ways in, each a service of its own that pam_either runs
        # side by side
        sudo-fprint.text = ''
          auth required ${config.services.fprintd.package}/lib/security/pam_fprintd.so
        '';
        sudo-password.text = ''
          auth required ${config.security.pam.package}/lib/security/pam_unix.so
        '';
        sudo = {
          # the reader runs inside pam_either now, not ahead of the password
          fprintAuth = false;
          # success ends the stack and a wrong answer or a cancel fails it;
          # pam_either failing to run is ignored, so the plain password rule
          # below takes over and a broken module can't lock sudo
          rules.auth.either = {
            order = sudoAuth.unix.order - 10;
            control = "[success=done service_err=ignore system_err=ignore module_unknown=ignore open_err=ignore symbol_err=ignore default=die]";
            modulePath = "${pamEither}/lib/security/pam_either.so";
            args = [
              "helper=${lib.getExe pamEither}"
              "sudo-fprint"
              "sudo-password"
            ];
          };
        };
      };
    })
  ];
}
