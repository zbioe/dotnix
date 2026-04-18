{
  description = "dotnix";

  outputs =
    {
      bwt,
      home,
      stylix,
      nixpkgs,
      hardware,
      hyprland,
      trae-deb,
      programsdb,
      impermanence,
      emacs-overlay,
      nixpkgs-unstable,
      ...
    }:
    let
      username = "zbioe";
      system = "x86_64-linux";
      unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
        overlays = [ emacs-overlay.overlays.default ];
      };
      specialArgs = {
        inherit nixpkgs username;
        inherit (home.packages.${system}) home-manager;
        inherit (hyprland.packages.${system}) hyprland xdg-desktop-portal-hyprland;
        inherit bwt trae-deb;
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
        te = nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          modules = defaultModules ++ [
            hardware.nixosModules.lenovo-thinkpad-e14-amd
            ./hosts/te
          ];
        };
        bx = nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          modules = defaultModules ++ [
            hardware.nixosModules.common-pc
            hardware.nixosModules.common-cpu-amd
            hardware.nixosModules.common-cpu-amd-pstate
            hardware.nixosModules.common-gpu-amd
            hardware.nixosModules.common-pc-ssd
            ./hosts/bx
          ];
        };
      };
      # home-manager
      homeConfigurations =
        let
          makeConfiguration =
            stateVersion:
            home.lib.homeManagerConfiguration {
              extraSpecialArgs = {
                inherit stateVersion;
                inherit username;
                inherit (hyprland.packages.${system}) hyprland;
                inherit unstable;
              };
              pkgs = import nixpkgs {
                inherit system;
                overlays = [ emacs-overlay.overlays.default ];
              };
              modules = [
                stylix.homeModules.stylix
                ./home
              ];
            };
        in
        {
          te = makeConfiguration "25.11";
          bx = makeConfiguration "25.11";
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
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
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
    bwt = {
      url = "github:bwt-dev/bwt";
      flake = false;
    };
    trae-deb = {
      url = "https://lf-cdn.trae.ai/obj/trae-ai-us/pkg/app/releases/stable/2.3.19583/linux/Trae-linux-x64.deb";
      flake = false;
    };
  };
}
