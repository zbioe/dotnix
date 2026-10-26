# nix flake check: every host and home evaluates (nothing is built), the Go
# tests, fonts, formatting, dead code and the Lua and Python linters
{
  self,
  pkgs,
  lib,
}:
let
  evaluates =
    name: drv: pkgs.writeText "evaluates-${name}" (builtins.unsafeDiscardStringContext drv.drvPath);
  # without the GTK4 swap (system/desktop, lib/default.nix): replaceDependencies
  # needs the whole closure built to evaluate, the rest of the host doesn't
  unswapped =
    host:
    host.extendModules {
      specialArgs.homeActivation = self.homeConfigurations.bx.config.home.activationPackage;
      modules = [ { system.replaceDependencies.replacements = lib.mkForce [ ]; } ];
    };
  sources =
    exts:
    lib.fileset.toSource {
      root = ../.;
      fileset = lib.fileset.fileFilter (f: lib.any f.hasExt exts) ../.;
    };
  src = sources [ "nix" ];
  luaSrc = sources [
    "lua"
    "luau"
  ];
  pySrc = sources [ "py" ];
in
lib.mapAttrs' (
  name: host:
  lib.nameValuePair "system-${name}" (evaluates name (unswapped host).config.system.build.toplevel)
) self.nixosConfigurations
// lib.mapAttrs' (
  name: home: lib.nameValuePair "home-${name}" (evaluates name home.config.home.activationPackage)
) self.homeConfigurations
// {
  inherit (self.packages.${pkgs.stdenv.hostPlatform.system}) dotnix-key usb-stick;
  fonts = import ../home/theme/fonts/check.nix { inherit pkgs; };
  # (fails to evaluate when a module pick is wrong)
  facter =
    assert import ./facter.nix { inherit lib; };
    pkgs.writeText "facter-check" "";
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
  stylua = pkgs.runCommand "stylua-check" { nativeBuildInputs = [ pkgs.stylua ]; } ''
    cd ${luaSrc}
    stylua --check --config-path ${../stylua.toml} .
    touch $out
  '';
  ruff = pkgs.runCommand "ruff-check" { nativeBuildInputs = [ pkgs.ruff ]; } ''
    cd ${pySrc}
    ruff check --no-cache .
    touch $out
  '';
}
