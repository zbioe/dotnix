{
  description = "System";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11-small";
    hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs =
    {
      self,
      nixpkgs,
      hardware,
      ...
    }:
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
              hardware.nixosModules.common-cpu-intel
              hardware.nixosModules.common-gpu-nvidia
              hardware.nixosModules.common-pc-laptop
              hardware.nixosModules.common-pc-ssd
              ./hosts/am
              ./modules
              ./users
            ];
          };
        };
    };
}
