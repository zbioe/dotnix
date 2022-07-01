{
  description = "NixOS System Config";

  nixConfig.extra-experimental-features = "nix-command flakes";
  nixConfig.extra-substituters =
    "https://zbioe.cachix.org https://nix-community.cachix.org";
  nixConfig.extra-trusted-public-keys =
    "zbioe.cachix.org-1:7KHSSucix5ZpqsbtlJJcabTZohn7OPJxTWerdQlZIfw= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";

  inputs = {
    # Main package channels
    nixpkgs.url = "github:NixOS/nixpkgs/29d09efbd5da";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/29d09efbd5da";
    nur.url = "github:nix-community/NUR/834d53bf16ac";
    nur.inputs.nixpkgs.follows = "nixpkgs";

    # doom emacs
    doomemacs = {
      url = "github:doomemacs/doomemacs/bea3cc161c0a";
      flake = false;
    };

    # Extra packages
    home-manager.url = "github:rycee/home-manager/70824bb5c790";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Age encrypt secrets for nixos, ecnrypt secrets with your keygen
    agenix.url = "github:ryantm/agenix/0.10.1";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    # Emacs 
    emacs-overlay.url = "github:nix-community/emacs-overlay/18caabdf606d1";
    emacs-overlay.inputs.nixpkgs.follows = "nixpkgs";

    # Hardware
    nixos-hardware.url = "github:nixos/nixos-hardware/0cab18a48de79";
  };
  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, nur, doomemacs, ... }:
    with self; {
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlay = overlay;
      };
      unstable-pkgs = import nixpkgs-unstable {
        inherit system;
        overlay = overlay;
      };
      # unstable-pkgs = import nixpkgs-unstable { inherit system;};
      nur-pkgs = import nur { inherit pkgs; };
      # TODO: fix this
      lib = nixpkgs.lib.extend (self: super: {
        my = import ./lib {
          inherit pkgs inputs;
          lib = self;
        };
      });

      overlay = final: prev: {
        unstable = unstable-pkgs;
        nur = nur-pkgs;
      };

      nixosModules = {
        overlays = {
          nixpkgs.overlays = [ inputs.emacs-overlay.overlay nur.overlay ];
        };
        overrides = {
          nixpkgs.config.packageOverrides = pkgs: {
            nur = nur-pkgs;
            unstable = unstable-pkgs;
          };
        };
        default = {
          nix.extraOptions = "experimental-features = nix-command flakes";
        };
        binaryCaches = {
          nix.binaryCachePublicKeys = [
            "zbioe.cachix.org-1:7KHSSucix5ZpqsbtlJJcabTZohn7OPJxTWerdQlZIfw="
          ];
        };
        unfree = {
          nixpkgs.config.allowUnfreePredicate = pkg:
            builtins.elem (lib.getName pkg) (import ./nixpkgs/unfree.nix);
        };
      };

      nixosConfigurations.nv = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit lib; };
        modules = [
          ./modules
          ./hosts/nv
          # self.nixosModules.options
          self.nixosModules.default
          self.nixosModules.unfree
          self.nixosModules.overlays
          self.nixosModules.overrides
          self.nixosModules.binaryCaches
          inputs.home-manager.nixosModules.home-manager
          inputs.nixos-hardware.nixosModules.common-cpu-intel
          inputs.nixos-hardware.nixosModules.common-gpu-nvidia
          inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
        ];
      };
      #defaultPackage.${system} = self.nixosConfigurations.nv.config.system.build.vm;
      #defaultPackage.${system} = self.nixosConfigurations.nv;
    };
}
