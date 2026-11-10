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
  imports = [ ./chess.nix ];

  options.dotnix.packages.games = dotlib.mkPackages "games";

  config = lib.mkIf cfg.enable {
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };
    # the installed games and their caches: Steam downloads them again, and
    # a 69 GB game kept the backup from finishing for days; the saves stay
    # (Steam Cloud, and Proton's prefixes in steamapps/compatdata)
    dotnix.storage.backup.exclude =
      map (d: ".local/share/Steam/steamapps/${d}") [
        "common"
        "shadercache"
        "downloading"
        "temp"
        "workshop"
      ]
      # Steam's own runtime, which it reinstalls
      ++ map (d: ".local/share/Steam/${d}") [
        "ubuntu12_32"
        "ubuntu12_64"
        "steamrt64"
        "package"
        "logs"
      ];
    environment.systemPackages = dotlib.packagesOf cfg (
      with pkgs;
      [
        lutris # game launcher
      ]
    );
  };
}
