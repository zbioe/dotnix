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
        # (not the login screen's user, nor other accounts)
        unitConfig.ConditionUser = config.dotnix.core.user.name;
        wants = [ "gpg-agent.service" ];
        after = [
          "gpg-agent.service"
          "graphical-session.target"
        ];
      };
    })
  ];
}
