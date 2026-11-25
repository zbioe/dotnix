{
  config,
  lib,
  unstable,
  ...
}:
let
  cfg = config.dotnix.services.onePassword;
in
{
  options.dotnix.services.onePassword.enable = lib.mkEnableOption "1Password (GUI and CLI)";

  config = lib.mkIf cfg.enable {
    programs._1password = {
      enable = true;
      package = unstable._1password-cli;
    };

    programs._1password-gui = {
      enable = true;
      package = unstable._1password-gui;
      polkitPolicyOwners = [ config.dotnix.core.user.name ];
    };

    # NixOS wraps Brave and LibreWolf under .<name>-wrapped; 1Password requires 0755
    environment.etc."1password/custom_allowed_browsers" = {
      mode = "0755";
      text = ''
        .brave-wrapped
        brave
        chromium
        .librewolf-wrapped
        librewolf
      '';
    };
  };
}
