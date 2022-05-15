{pkgs, config, lib, ...}:
with lib;
with lib.my;
{
  imports = [
    ./boot
    ./system.nix
  ];
  options = with types; {
    user = mkOpt attrs {};
    dotfiles = {
      dir        = mkOpt path "/etc/dotnix";
      binDir     = mkOpt path "${config.dotfiles.dir}/bin";
      configDir  = mkOpt path "${config.dotfiles.dir}/config";
      modulesDir = mkOpt path "${config.dotfiles.dir}/modules";
    };
  };
  config = {
    user = let
      user = config.user.name;
      name = if elem user [ "" "default" ] then "zbioe" else user;
    in {
      inherit name;
      description = "The primary user account";
      extraGroups = [ "wheel" ];
      isNormalUser = true;
      home = "/home/${name}";
      group = "users";
      uid = 1000;
    };

    home-manager = {
      useUserPackages = true;
      users.${config.user.name} = {
        home = {
          stateVersion = config.system.stateVersion;
        };
      };
    };

    users.users.${config.user.name} = config.user;
    nix = let users = [ "root" config.user.name]; in {
      trustedUsers = users;
      allowedUsers = users;
    };
  };
}
