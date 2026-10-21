{
  config,
  lib,
  pkgs,
  home-manager,
  unstable,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.packages.nix;
in
{
  options.dotnix.packages.nix = dotlib.mkPackages "Nix tools";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = dotlib.packagesOf cfg (
      with pkgs;
      [
        home-manager # standalone home switches
        unstable.nixd # language server
        nil # language server
        nixfmt # formatter
        statix # linter
        cachix # binary caches
      ]
    );
  };
}
