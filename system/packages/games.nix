{
  config,
  lib,
  pkgs,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.packages.games;
in
{
  options.dotnix.packages.games = dotlib.mkPackages "games";

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };
    environment.systemPackages = dotlib.packagesOf cfg (
      with pkgs;
      [
        lutris # game launcher
      ]
    );
  };
}
