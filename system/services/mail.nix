{
  config,
  lib,
  pkgs,
  unstable,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.services.mail;
in
{
  options.dotnix.services.mail = {
    enable = lib.mkEnableOption "mail";
    protonBridge.enable = dotlib.mkItem cfg "Proton Mail Bridge (IMAP/SMTP on localhost)";
    mu.enable = dotlib.mkItem cfg "mu and mbsync (mu4e in Emacs)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.protonBridge.enable {
      services.protonmail-bridge = {
        enable = true;
        package = unstable.protonmail-bridge;
        path = with pkgs; [
          pass
          gnupg
        ];
      };
      systemd.user.services.protonmail-bridge = {
        wants = [ "gpg-agent.service" ];
        after = [
          "gpg-agent.service"
          "graphical-session.target"
        ];
      };
    })
    (lib.mkIf cfg.mu.enable {
      environment.systemPackages = with unstable; [
        mu # mail indexer
        isync # mbsync: IMAP to maildir
        emacsPackages.mu4e # mu's Emacs client
      ];
    })
  ];
}
