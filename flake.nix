{
  description = "dotnix";

  outputs =
    {
      self,
      nvf,
      home,
      stylix,
      nixpkgs,
      hardware,
      hyprland,
      programsdb,
      ...
    }:
    let
      username = "zbioe";
      system = "x86_64-linux";
      specialArgs = {
        inherit nixpkgs username;
        inherit (self.packages.${system}) nvf;
        inherit (home.packages.${system}) home-manager;
        inherit (hyprland.packages.${system}) hyprland xdg-desktop-portal-hyprland;
        home-module = home.nixosModules.home-manager;
      };
      defaultModules = [
        ./modules
        ./default
        programsdb.nixosModules.programs-sqlite
        home.nixosModules.home-manager
        stylix.nixosModules.stylix
      ];
    in
    {
      # system
      nixosConfigurations = {
        minimal-iso = nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./iso
          ];
        };
        am = nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          modules = defaultModules ++ [
            hardware.nixosModules.common-cpu-intel
            hardware.nixosModules.common-gpu-nvidia
            hardware.nixosModules.common-pc-laptop
            hardware.nixosModules.common-pc-ssd
            ./hosts/am
          ];
        };
        ln = nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          modules = defaultModules ++ [
            hardware.nixosModules.lenovo-thinkpad-x1-6th-gen
            ./hosts/ln
          ];
        };
      };
      # home-manager
      homeConfigurations =
        let
          makeConfiguration =
            stateVersion: input_model: input_variant:
            home.lib.homeManagerConfiguration {
              extraSpecialArgs = {
                inherit stateVersion;
                inherit username;
                inherit input_model input_variant;
                inherit (hyprland.packages.${system}) hyprland;
              };
              pkgs = import nixpkgs { inherit system; };
              modules = [
                stylix.homeModules.stylix
                ./home
              ];
            };
        in
        {
          am = makeConfiguration "24.11" "abnt2" "";
          ln = makeConfiguration "25.05" "thinkpad" "thinkpad";
        };

      # nvim
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
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05-small";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    hardware.url = "github:NixOS/nixos-hardware/master";
    home = {
      url = "github:nix-community/home-manager/release-25.05";
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
      url = "github:nix-community/stylix/release-25.05";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
        flake-parts.follows = "parts";
      };
    };
    nvf = {
      url = "github:notashelf/nvf";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
        flake-compat.follows = "compat";
        flake-parts.follows = "parts";
        mnw.follows = "mnw";
      };
    };
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs = {
        nixpkgs.follows = "nixpkgs-unstable";
        systems.follows = "systems";
      };
    };
    mnw.url = "github:Gerg-L/mnw";
    compat = {
      url = "git+https://git.lix.systems/lix-project/flake-compat.git";
      flake = false;
    };
    utils = {
      url = "github:zimbatm/flake-utils";
      inputs.systems.follows = "systems";
    };
    parts = {
      url = "github:hercules-ci/flake-parts";
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
