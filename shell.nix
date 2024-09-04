{
  pkgs ? import <nixpkgs> { },
  unstable ? pkgs,
}:

with pkgs;
let
  nixBin = writeShellScriptBin "nix" ''
    ${nixFlakes}/bin/nix --option experimental-features "nix-command flakes" "$@"
  '';
in
mkShell {
  buildInputs = [
    git
    unstable.nix-zsh-completions
    poetry2nix
    poetry
  ];
  shellHook = ''
    export FLAKE="$(pwd)"
    # export NIXOS_CONFIG="$(pwd)"
    export PATH="$FLAKE/bin:${nixBin}/bin:$PATH"
  '';
}
