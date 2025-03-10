{
  description = "d";

  outputs =
    {
      self,
      hardware,
      home,
      programsdb,
      nvf,
      stylix,
      nixpkgs,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      specialArgs = {
        inherit nixpkgs;
        inherit (self.packages.${system}) nvf;
      };
      minimalDefaultModules = [
        ./modules
        ./default
      ];
      defaultModules = minimalDefaultModules ++ [
        programsdb.nixosModules.programs-sqlite
        home.nixosModules.home-manager
        stylix.homeManagerModules.stylix
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
          modules = minimalDefaultModules ++ [
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
      packages."${system}" = {
        nvf =
          (nvf.lib.neovimConfiguration {
            pkgs = import nixpkgs { inherit system; };
            modules = [
              ./nvf
            ];
          }).neovim;
      };
    };
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11-small";
    hardware.url = "github:NixOS/nixos-hardware/master";
    home = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    programsdb = {
      url = "github:wamserma/flake-programs-sqlite";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        utils.follows = "utils";
      };
    };
    stylix = {
      url = "github:danth/stylix/release-24.11";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home";
        systems.follows = "systems";
        flake-utils.follows = "utils";
      };
    };
    nvf = {
      url = "github:notashelf/nvf";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
        flake-utils.follows = "utils";
        nil.follows = "nil";
      };
    };
    nil = {
      url = "github:oxalica/nil";
      inputs = {
        flake-utils.follows = "utils";
        nixpkgs.follows = "nixpkgs";
      };
    };
    utils = {
      url = "github:zimbatm/flake-utils";
      inputs.systems.follows = "systems";
    };
    systems.url = "github:nix-systems/default";
  };
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
}
