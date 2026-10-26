{
  description = "dotnix";

  # hosts, homes, ISOs, packages and checks: lib/default.nix
  outputs = inputs: import ./lib inputs;

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
    # prebuilt nix-index database: command-not-found and comma (system/core)
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # the disk layout, declared once for the hosts and dotnix-install (system/storage/disk.nix)
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # base16 scheme loader of the themes (home/theme)
    base16 = {
      url = "github:SenchoPens/base16.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # dwl-based compositor of the session (system/desktop, home/desktop/mango)
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
    # secrets/*.yaml, decrypted at boot into /run/secrets (system/core/secrets.nix)
    sops = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # the editor (home/editors): Emacs and its packages pinned by twist.nix
    zmacs = {
      url = "github:zbioe/zmacs";
      inputs.systems.follows = "systems";
    };
    # long-term memory shared by the coding agents (home/dev)
    ai-memory.url = "github:akitaonrails/ai-memory";
    # Proton's own build of the newest stable Proton Pass (pkgs/proton-pass)
    proton-pass = {
      url = "file+https://proton.me/download/PassDesktop/linux/x64/ProtonPass.deb";
      flake = false;
    };
    bwt = {
      url = "github:bwt-dev/bwt";
      flake = false;
    };
  };
}
