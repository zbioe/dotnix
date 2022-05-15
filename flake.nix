{
  description = "NixOS System Config";

  nixConfig.extra-experimental-features = "nix-command flakes";
  nixConfig.extra-substituters = "https://zbioe.cachix.org https://nix-community.cachix.org";
  nixConfig.extra-trusted-public-keys = "zbioe.cachix.org-1:7KHSSucix5ZpqsbtlJJcabTZohn7OPJxTWerdQlZIfw= nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=";

  inputs = {
    # Main package channels
    nixpkgs.url = "nixpkgs/nixos-21.11";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";

    # Extra packages
    home-manager.url = "github:rycee/home-manager/release-21.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Age encrypt secrets for nixos, ecnrypt secrets with your keygen
    agenix.url = "github:ryantm/agenix/0.10.1";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    # Emacs 
    emacs-overlay.url  = "github:nix-community/emacs-overlay";

    # Hardware
    nixos-hardware.url = "github:nixos/nixos-hardware";
  };
  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, ... }: {
    nixosModules = {
      overlays = {
        nixpkgs.overlays = inputs.emacs-overlay.overlay;
      };
      binaryCaches = {
        nix.binaryCachePublicKeys = [
          "zbioe.cachix.org-1:7KHSSucix5ZpqsbtlJJcabTZohn7OPJxTWerdQlZIfw="
        ];
      };
    };
    nixosConfigurations.nv = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardaware/nv.nix
        ./system.nix
        inputs.self.nixosModules.overlays
        inputs.self.nixosModules.binaryCaches
        inputs.home-manager.nixosModules.home-manager
        inputs.nixos-harware.nixosModules.common-gpu-nvidia
        inputs.nixos-harware.nixosModules.common-cpu-intel
        inputs.nixos-harware.nixosModules.common-pc-laptop-ssd
      ];
    };
  };
}
