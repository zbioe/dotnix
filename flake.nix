{
  description = "System";

  nixConfig = {
    extra-experimental-features = "nix-command flakes";
    extra-substituters = [
      "https://cachix.cachix.org"
      "https://cache.flox.dev"
      "https://hyprland.cachix.org"
      "https://nix-community.cachix.org"
    ];

    extra-trusted-public-keys = [
      "cachix.cachix.org-1:eWNHQldwUO7G2VkjpnjDbWwy4KQ/HNxht7H4SSoMckM="
      "flox-cache-public-1:7F4OyH7ZCnFhcze3fJdfyXYLQw/aV7GEed86nQ7IsOs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11-small";
    hardware.url = "github:NixOS/nixos-hardware/master";
    home = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    programsdb = {
      url = "github:wamserma/flake-programs-sqlite";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      hardware,
      home,
      programsdb,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      specialArgs = {
        inherit inputs nixpkgs;
      };
      defaultModules = [
        ./modules
        ./default
        programsdb.nixosModules.programs-sqlite
      ];
      amDefaultModules = defaultModules ++ [
        hardware.nixosModules.common-cpu-intel
        hardware.nixosModules.common-gpu-nvidia
        hardware.nixosModules.common-pc-laptop
        hardware.nixosModules.common-pc-ssd
        ./hosts/am
      ];
    in
    {
      nixosConfigurations = {
        minimal-iso = nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          modules = defaultModules ++ [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./iso
          ];
        };
        am-iso = nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          modules = amDefaultModules ++ [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ];
        };
        am = nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          modules = amDefaultModules;
        };
      };
    };
}
