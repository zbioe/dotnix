{
  description = "dotnix";

  outputs =
    {
      self,
      bwt,
      home,
      stylix,
      nixpkgs,
      hardware,
      mango,
      noctalia,
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
        inherit bwt;
        inherit unstable;
        home-module = home.nixosModules.home-manager;
      };
      # hosts made by dotnix-install (iso/tools.nix): any other folder in hosts/
      installedHosts = builtins.attrNames (
        nixpkgs.lib.filterAttrs (
          name: type:
          type == "directory"
          && !(builtins.elem name [
            "bx"
            "te"
          ])
        ) (builtins.readDir ./hosts)
      );
      # the home generation every host shares (homeConfigurations below)
      homeActivation = self.homeConfigurations.bx.activationPackage;
      defaultModules = [
        ./modules
        ./default
        programsdb.nixosModules.programs-sqlite
        mango.nixosModules.mango
        home.nixosModules.home-manager
        stylix.nixosModules.stylix
        impermanence.nixosModules.impermanence
      ];
    in
    {
      # system
      nixosConfigurations = {
        # recovery: a console, the disk tools and dotnix-install/-mount
        minimal-iso = nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          modules = [
            "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            ./iso
            ./iso/tools.nix
          ];
        };
        # this whole setup, live from USB and installable (iso/full.nix)
        full-iso = nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = specialArgs // {
            inherit homeActivation;
            dotnix = self;
          };
          modules = defaultModules ++ [ ./iso/full.nix ];
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
      }
      // nixpkgs.lib.genAttrs installedHosts (
        host:
        nixpkgs.lib.nixosSystem {
          inherit system specialArgs;
          modules = defaultModules ++ [
            ./hosts/${host}
            # its home, the first time (then `nh home switch -c <host>`)
            {
              modules.homeActivation = {
                enable = true;
                package = homeActivation;
              };
            }
          ];
        }
      );
      # `nix fmt`
      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt-tree;
      # `nix flake check`: every system and home evaluates (the derivation
      # only, nothing is built) and the nix files are formatted
      checks.${system} =
        let
          pkgs = nixpkgs.legacyPackages.${system};
          evaluates =
            name: drv: pkgs.writeText "evaluates-${name}" (builtins.unsafeDiscardStringContext drv.drvPath);
        in
        nixpkgs.lib.mapAttrs' (
          name: host:
          nixpkgs.lib.nameValuePair "system-${name}" (evaluates name host.config.system.build.toplevel)
        ) self.nixosConfigurations
        // nixpkgs.lib.mapAttrs' (
          name: home: nixpkgs.lib.nameValuePair "home-${name}" (evaluates name home.activationPackage)
        ) self.homeConfigurations
        // {
          format = pkgs.runCommand "nixfmt-check" { nativeBuildInputs = [ pkgs.nixfmt ]; } ''
            cd ${self}
            find . -name '*.nix' -exec nixfmt --check {} +
            touch $out
          '';
        };
      # home-manager
      homeConfigurations =
        let
          makeConfiguration =
            stateVersion:
            let
              pkgs = import nixpkgs {
                inherit system;
                overlays = [ emacs-overlay.overlays.default ];
              };
              hm = home.lib.homeManagerConfiguration {
                inherit pkgs;
                extraSpecialArgs = {
                  inherit stateVersion;
                  inherit username;
                  noctalia = noctalia.packages.${system}.default;
                  inherit unstable;
                };
                modules = [
                  stylix.homeModules.stylix
                  mango.hmModules.mango
                  noctalia.homeModules.default
                  ./home
                ];
              };
            in
            # same live-reloading GTK4 as the system (default/ui.nix)
            hm
            // {
              activationPackage = pkgs.replaceDependencies {
                drv = hm.activationPackage;
                replacements = import ./patches/gtk4-live.nix [
                  pkgs.gtk4
                  unstable.gtk4
                ];
              };
            };
        in
        {
          te = makeConfiguration "25.11";
          bx = makeConfiguration "25.11";
        }
        # the same generation as bx, so an install needs nothing new
        // nixpkgs.lib.genAttrs installedHosts (_: makeConfiguration "25.11");
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05-small";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    hardware = {
      url = "github:NixOS/nixos-hardware/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    programsdb = {
      url = "github:wamserma/flake-programs-sqlite";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix = {
      url = "github:nix-community/stylix/release-26.05";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        systems.follows = "systems";
        flake-parts.follows = "parts";
      };
    };
    # dwl-based compositor of the session (default/ui.nix, home/ui/mango.nix)
    mango = {
      url = "github:DreamMaoMao/mangowc";
      inputs = {
        nixpkgs.follows = "nixpkgs-unstable";
        flake-parts.follows = "parts";
        scenefx.inputs = {
          systems.follows = "systems";
          flake-utils.inputs.systems.follows = "systems";
        };
      };
    };
    # shell (bar, panels, notifications, lock) for the mango session
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
    emacs-overlay = {
      url = "github:nix-community/emacs-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        nixpkgs-stable.follows = "nixpkgs";
      };
    };
    parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    systems.url = "github:nix-systems/default";
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home";
      };
    };
    bwt = {
      url = "github:bwt-dev/bwt";
      flake = false;
    };
  };
}
