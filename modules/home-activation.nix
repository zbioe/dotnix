# The user's home-manager generation (homeConfigurations, standalone, the
# same one `nh home switch` builds) activated by the system at boot, before
# the login screen: on the live ISO every boot (its home starts empty), on a
# freshly installed host only the first time (from then on `nh home switch`
# owns it). The generation is part of the system closure, so this works
# offline.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) types mkOption mkIf;
  cfg = config.modules.homeActivation;
  user = config.modules.user.name;
  home = config.users.users.${user}.home;
in
{
  options.modules.homeActivation = with types; {
    enable = mkOption {
      type = bool;
      default = false;
      description = "Activate the user's home-manager generation at boot.";
    };
    package = mkOption {
      type = package;
      description = "The home-manager activation package (homeConfigurations.<host>.activationPackage).";
    };
    always = mkOption {
      type = bool;
      default = false;
      description = "Activate on every boot (live system), not only when the home has never been activated.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.home-activation = {
      description = "Activate ${user}'s home (home-manager)";
      wantedBy = [ "multi-user.target" ];
      before = [ "display-manager.service" ];
      after = [ "nix-daemon.socket" ];
      requires = [ "nix-daemon.socket" ];
      unitConfig.RequiresMountsFor = [ home ];
      path = [ pkgs.util-linux ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${lib.optionalString (!cfg.always) ''
          if [ -e ${home}/.local/state/nix/profiles/home-manager ]; then exit 0; fi
        ''}
        # no session yet: no systemd user instance to reload, D-Bus started
        # for dconf by home-manager itself; steps that download a lot skip
        # themselves (DOTNIX_BOOT_ACTIVATION, e.g. home/ui/insightful.nix)
        exec runuser -l ${user} -c "DOTNIX_BOOT_ACTIVATION=1 ${cfg.package}/activate"
      '';
    };
  };
}
