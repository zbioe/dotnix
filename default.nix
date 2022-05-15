{pkgs, config, lib, ...}:
with lib;
with lib.my;
{
  imports = [
    ./boot.nix
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
      user = builtins.getEnv "USER";
      name = if elem user [ "" "root" ] then "zbioe" else user;
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

    users.users.${config.user.name} = mkAliasDefinitions options.user;
    nix.settings = let users = [ "root" config.user.name]; in {
      trusted-users = users;
      allowed-users = users;
    };
  };
}
