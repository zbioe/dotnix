{
  config,
  lib,
  pkgs,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.packages.web3;
  electrum-wayland = pkgs.symlinkJoin {
    name = "electrum-wayland";
    paths = [ pkgs.electrum ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/electrum --set QT_QPA_PLATFORM wayland
    '';
  };
in
{
  options.dotnix.packages.web3 = dotlib.mkPackages "wallets";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = dotlib.packagesOf cfg (
      with pkgs;
      [
        status-im # messenger and wallet
        foundry # Ethereum toolkit
        liana # Bitcoin wallet with recovery paths
        electrum-wayland # Bitcoin wallet
      ]
    );
  };
}
