# The home activated at boot, before the login screen: on the live ISO every
# time, on a new install only the first (then `nh home switch` owns it).
{
  config,
  lib,
  pkgs,
  homeActivation,
  ...
}:
let
  inherit (lib) types mkOption mkIf;
  cfg = config.dotnix.core.homeActivation;
  user = config.dotnix.core.user.name;
  home = config.users.users.${user}.home;

  # a new install, online once: the flake's history from upstream (with this
  # host in it after dotnix-adopt, else its files kept), then the first
  # rebuild (hosts/<host>/hardware.nix, and secrets/ once adopted)
  firstboot = pkgs.writeShellApplication {
    name = "dotnix-firstboot";
    runtimeInputs = with pkgs; [
      coreutils
      git
      nh
    ];
    text = ''
      flake=''${NH_FLAKE:-$HOME/dotnix}
      host=$(uname -n)
      cd "$flake"
      git fetch -q origin
      if git cat-file -e "origin/main:hosts/$host/default.nix" 2>/dev/null; then
        git reset -q --hard origin/main
      else
        git reset -q origin/main
        git add "hosts/$host"
        echo "hosts/$host isn't upstream yet: dotnix-adopt $host's address on a machine with your age key, then this again"
      fi
      nh os switch -H "$host" "$flake"
      nh home switch -c "$host" "$flake"
    '';
  };
in
{
  options.dotnix.core.homeActivation = with types; {
    enable = mkOption {
      type = bool;
      default = false;
      description = "Activate the user's home-manager generation at boot.";
    };
    package = mkOption {
      type = package;
      default = homeActivation;
      defaultText = lib.literalExpression "homeConfigurations.bx.activationPackage";
      description = "The home-manager activation package (homeConfigurations.<host>.activationPackage).";
    };
    always = mkOption {
      type = bool;
      default = false;
      description = "Activate on every boot (live system), not only when the home has never been activated.";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ firstboot ];
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
        # themselves (DOTNIX_BOOT_ACTIVATION, e.g. home/desktop/insightful)
        exec runuser -l ${user} -c "DOTNIX_BOOT_ACTIVATION=1 ${cfg.package}/activate"
      '';
    };
  };
}
