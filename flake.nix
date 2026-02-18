{
  description = "dotnix";

  outputs =
    {
      home,
      stylix,
      nixpkgs,
      nixpkgs-unstable,
      hardware,
      hyprland,
      programsdb,
      impermanence,
      ...
    }:
    let
      username = "zbioe";
      system = "x86_64-linux";
      unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      specialArgs = {
        inherit nixpkgs username;
        inherit (home.packages.${system}) home-manager;
        inherit (hyprland.packages.${system}) hyprland xdg-desktop-portal-hyprland;
        inherit unstable;
        home-module = home.nixosModules.home-manager;
      };
      defaultModules = [
        ./modules
        ./default
        programsdb.nixosModules.programs-sqlite
        home.nixosModules.home-manager
        stylix.nixosModules.stylix
        impermanence.nixosModules.impermanence
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
        te = nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          modules = defaultModules ++ [
            hardware.nixosModules.lenovo-thinkpad-e14-amd
            ./hosts/te
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
                inherit unstable;
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
          te = makeConfiguration "25.11" "thinkpad" "thinkpad";
        };
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11-small";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    hardware.url = "github:NixOS/nixos-hardware/master";
    home = {
      url = "github:nix-community/home-manager/release-25.11";
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
      url = "github:nix-community/stylix/release-25.11";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
        flake-parts.follows = "parts";
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
    impermanence.url = "github:nix-community/impermanence";
  };
}
