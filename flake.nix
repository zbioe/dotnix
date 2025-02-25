{
  description = "System";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11-small";
  };

  outputs =
    { self, nixpkgs, ... }:
    {
      nixosConfigurations =
        let
          system = "x86_64-linux";
        in
        {
          iso = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
              ./iso
              ./users
            ];
          };
          am = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              ./hosts/am
              ./modules
            ];
          };
        };
    };
}
