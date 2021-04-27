{ pkgs, ... }:

let
  haskellPkgs = with pkgs.haskellPackages; [
    brittany # code formatter
    cabal2nix # convert cabal projects to nix
    cabal-install # package manager
    ghc # compiler
    haskell-language-server # haskell IDE (ships with ghcide)
    hoogle # documentation
    nix-tree # visualize nix dependencies
    hlint # flycheck linter
    cabal # package manager
  ];
in { home.packages = with pkgs; [ haskell ] ++ haskellPkgs; }
