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
    programsdb = {
      url = "github:wamserma/flake-programs-sqlite";
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
    # secrets/*.yaml, decrypted at boot into /run/secrets (system/core/secrets.nix)
    sops = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Doom Emacs (home/editors/emacs.nix): its packages come from `doom sync`
    doomemacs = {
      # held at the last release with modules in tree; v3 fetches them apart
      url = "github:doomemacs/doomemacs/43912efdcbc9d63f84becfd6cfde86dec04c168d";
      flake = false;
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
