{
  config,
  lib,
  pkgs,
  ...
}:

{
  description = "System";

  inputs = {
    nixpkgs.url = "github:NixOS/nixos-24.11-small";
  };

  outputs =
    let
      system = "x86_64-linux";
    in
    { self, nixpkgs }:
    {
      nixosConfigurations = {
        workstation = {
          system = system;
          modules = [
            ./hosts/workstation
            ./modules
          ];
        };
      };
    };
}
