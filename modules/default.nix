{ pkgs, config, lib, ... }:
with lib;
with lib.my; {
  imports = [
    ./wm
    ./boot
    ./audio.nix
    ./system.nix
    ./network.nix
    ./keyboard.nix
    ./bluetooth.nix
    ./protonvpn.nix
  ];
  options = with types; {
    user.uid = mkOpt int 1000;
    user.name = mkOpt str "default";
    user.shell = mkOpt package pkgs.fish;
    user.description = mkOpt str "${config.user.name} account";
    user.extraGroups = mkOpt (listOf str) [ "wheel" ];
    user.isNormalUser = mkBoolOpt true;
    user.home = mkOpt str "/home/${config.user.name}";
    user.group = mkOpt str "users";

    host.name = mkOpt str "nixos";
    host.i18n = mkOpt str "pt_BR.UTF-8";

    time.zone = mkOpt str "America/Sao_Paulo";

    dotfiles = {
      dir = mkOpt path "/etc/dotnix";
      binDir = mkOpt path "${config.dotfiles.dir}/bin";
      configDir = mkOpt path "${config.dotfiles.dir}/config";
      modulesDir = mkOpt path "${config.dotfiles.dir}/modules";
    };
  };
  config = {
    security.sudo.wheelNeedsPassword = false;

    home-manager = {
      useUserPackages = true;
      users.${config.user.name} = {
        home = { stateVersion = config.system.stateVersion; };
      };
    };

    i18n.defaultLocale = config.host.i18n;

    users.users.${config.user.name} = config.user;
    nix.settings = let users = [ "root" config.user.name ];
    in {
      trusted-users = users;
      allowed-users = users;
    };

    time.timeZone = config.time.zone;
  };
}
