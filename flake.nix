{
  description = "NixOS System Config";

  nixConfig.extra-experimental-features = "nix-command flakes";
  nixConfig.extra-substituters = "https://zbioe.cachix.org https://nix-community.cachix.org";
  nixConfig.extra-trusted-public-keys = "zbioe.cachix.org-1:7KHSSucix5ZpqsbtlJJcabTZohn7OPJxTWerdQlZIfw= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";

  inputs = {
    # Main package channels
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11-small";
    nur.url = "github:nix-community/NUR";
    nixos-cli.url = "github:water-sucks/nixos";

    # Extra packages
    home-manager.url = "github:nix-community/home-manager/release-24.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # doom emacs
    doomemacs = {
      url = "github:doomemacs/doomemacs";
      flake = false;
    };

    # Grub theme
    darkmatter-grub-theme = {
      url = "github:zbioe/darkmatter-grub-theme";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # brain fuck
    bf-nix.url = "github:water-sucks/brainfuck.nix";
    bf-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Sops for nixos, ecnrypt secrets
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Emacs 
    emacs-overlay.url = "github:nix-community/emacs-overlay/18caabdf606d1";
    emacs-overlay.inputs.nixpkgs.follows = "nixpkgs";

    # Hardware
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };
  outputs =
    inputs@{
      self,
      nixpkgs,
      nur,
      doomemacs,
      sops-nix,
      bf-nix,
      nixos-cli,
      ...
    }:
    with self;
    {
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        overlays = overlays;
      };
      nur-pkgs = import nur { inherit pkgs; };
      # TODO: fix this
      lib = nixpkgs.lib.extend (
        self: super: {
          my = import ./lib {
            inherit pkgs inputs;
            lib = self;
          };
        }
      );

      overlays = [
        (final: prev: { nur = nur-pkgs; })
        bf-nix.overlays.default
      ];

      nixosModules = {
        overlays = {
          nixpkgs.overlays = [
            inputs.emacs-overlay.overlay
            nur.overlays.default
          ];
        };
        overrides = {
          nixpkgs.config.packageOverrides = pkgs: { nur = nur-pkgs; };
        };
        default = {
          nix.extraOptions = "experimental-features = nix-command flakes";
        };
        binaryCaches = {
          nix.settings.trusted-public-keys = [
            "zbioe.cachix.org-1:7KHSSucix5ZpqsbtlJJcabTZohn7OPJxTWerdQlZIfw="
          ];
        };
        unfree = {
          nixpkgs.config.allowUnfreePredicate =
            pkg: builtins.elem (lib.getName pkg) (import ./nixpkgs/unfree.nix);
          nixpkgs.config.allowUnsupportedSystem = true;
        };
      };

      nixosConfigurations =
        let
          defaultModules = [
            ./modules
            # self.nixosModules.options
            inputs.darkmatter-grub-theme.nixosModule
            self.nixosModules.default
            self.nixosModules.unfree
            self.nixosModules.overlays
            self.nixosModules.overrides
            self.nixosModules.binaryCaches
            inputs.home-manager.nixosModules.home-manager
            inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x1-6th-gen
            # encrypt app
            sops-nix.nixosModules.sops
            # nixos management tool
            nixos-cli.nixosModules.nixos-cli
          ];
        in
        {
          ln = nixpkgs.lib.nixosSystem {
            inherit system;
            specialArgs = {
              inherit lib;
            };
            modules = defaultModules ++ [ ./hosts/ln ];
          };
        };
      defaultPackage.${system} = self.nixosConfigurations.ln.config.system.build.vm;
      defaultPackage.${system} = self.nixosConfigurations.ln;
    };
}
