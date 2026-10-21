# nix flake check: every host and home evaluates (nothing is built), the Go
# tests, fonts, formatting and dead code
{
  self,
  pkgs,
  lib,
}:
let
  evaluates =
    name: drv: pkgs.writeText "evaluates-${name}" (builtins.unsafeDiscardStringContext drv.drvPath);
  src = lib.fileset.toSource {
    root = ../.;
    fileset = lib.fileset.fileFilter (f: f.hasExt "nix") ../.;
  };
in
lib.mapAttrs' (
  name: host: lib.nameValuePair "system-${name}" (evaluates name host.config.system.build.toplevel)
) self.nixosConfigurations
// lib.mapAttrs' (
  name: home: lib.nameValuePair "home-${name}" (evaluates name home.activationPackage)
) self.homeConfigurations
// {
  inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) dotnix-key usb-stick;
  fonts = import ../home/theme/fonts/check.nix { inherit pkgs; };
  format = pkgs.runCommand "nixfmt-check" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
    cd ${src}
    find . -name '*.nix' -exec nixfmt --check {} +
    touch $out
  '';
  deadnix = pkgs.runCommand "deadnix-check" { nativeBuildInputs = [ pkgs.deadnix ]; } ''
    deadnix --fail ${src}
    touch $out
  '';
  statix = pkgs.runCommand "statix-check" { nativeBuildInputs = [ pkgs.statix ]; } ''
    cd ${src}
    statix check --config ${../statix.toml} .
    touch $out
  '';
}
