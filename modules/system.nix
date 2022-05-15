{pkgs, config, lib, options, ...}:
with lib;
with lib.my;
let 
  cfg = config.modules.system;
in {
  options.modules.system = with types; {
    stateVersion = mkOpt' nonEmptyStr "21.05" "system and home state version";
  };
  
  config = {
    home-manager.users.${config.user.name}.home.stateVersion = cfg.stateVersion;
    system.stateVersion = cfg.stateVersion;
  };
}
