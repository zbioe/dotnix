# Every output of the flake: hosts (one per folder of hosts/), the ISOs,
# homes, packages, checks and the dev shell.
inputs@{
  self,
  nixpkgs,
  nixpkgs-unstable,
  home,
  emacs-overlay,
  ...
}:
let
  inherit (nixpkgs) lib;
  system = "x86_64-linux";
  username = "zbioe";
  pkgs = nixpkgs.legacyPackages.${system};
  unstable = import nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
    overlays = [ emacs-overlay.overlays.default ];
  };
  noctalia = inputs.noctalia.packages.${system}.default;
  dotlib = import ./options.nix { inherit lib; };

  hostNames = lib.attrNames (
    lib.filterAttrs (_: type: type == "directory") (builtins.readDir ../hosts)
  );

  specialArgs = {
    inherit
      inputs
      nixpkgs
      username
      unstable
      noctalia
      dotlib
      ;
    inherit (inputs) bwt base16;
    inherit (home.packages.${system}) home-manager;
    home-module = home.nixosModules.home-manager;
    # the home every host shares, activated at boot by new installs and the live ISO
    homeActivation = self.homeConfigurations.bx.activationPackage;
  };

  mkHost =
    modules:
    lib.nixosSystem {
      inherit system specialArgs;
      modules = [
        ../system
        inputs.programsdb.nixosModules.programs-sqlite
        inputs.mango.nixosModules.mango
        inputs.impermanence.nixosModules.impermanence
      ]
      ++ modules;
    };

  mkHome =
    name:
    let
      homePkgs = import nixpkgs {
        inherit system;
        overlays = [
          emacs-overlay.overlays.default
          (import ../overlays { inherit noctalia; })
        ];
      };
      hm = home.lib.homeManagerConfiguration {
        pkgs = homePkgs;
        extraSpecialArgs = {
          inherit
            username
            noctalia
            unstable
            dotlib
            ;
          inherit (inputs) base16;
          stateVersion = "25.11";
          ai-memory = inputs.ai-memory.packages.${system}.default;
          # the host's choices, as home-manager names them inside NixOS
          osConfig = self.nixosConfigurations.${name}.config;
        };
        modules = [
          inputs.mango.hmModules.mango
          inputs.noctalia.homeModules.default
          inputs.sops.homeManagerModules.sops
          ../home
        ];
      };
    in
    # the same live-reloading GTK4 as the system (system/desktop)
    hm
    // {
      activationPackage = homePkgs.replaceDependencies {
        drv = hm.activationPackage;
        replacements = import ../overlays/gtk4-live.nix [
          homePkgs.gtk4
          unstable.gtk4
        ];
      };
    };
in
{
  nixosConfigurations = lib.genAttrs hostNames (name: mkHost [ ../hosts/${name} ]) // {
    # recovery: a console, the disk tools and dotnix-install/-mount
    minimal-iso = lib.nixosSystem {
      inherit system specialArgs;
      modules = [
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        ../iso
        ../iso/tools.nix
      ];
    };
    # this whole setup, live from USB and installable
    full-iso = lib.nixosSystem {
      inherit system;
      specialArgs = specialArgs // {
        dotnix = self;
      };
      modules = [
        ../system
        inputs.programsdb.nixosModules.programs-sqlite
        inputs.mango.nixosModules.mango
        inputs.impermanence.nixosModules.impermanence
        ../iso/full.nix
      ];
    };
  };

  homeConfigurations = lib.genAttrs hostNames mkHome;

  packages.${system} = {
    iso-full = self.nixosConfigurations.full-iso.config.system.build.isoImage;
    iso-minimal = self.nixosConfigurations.minimal-iso.config.system.build.isoImage;
    dotnix-key = pkgs.callPackage ../pkgs/dotnix-key { };
    usb-stick = pkgs.callPackage ../pkgs/usb-stick { };
    usb-key-test = pkgs.testers.runNixOSTest ../checks/vm/usb-key.nix;
    usb-stick-test = pkgs.testers.runNixOSTest ../checks/vm/usb-stick.nix;
  };

  checks.${system} = import ../checks { inherit self pkgs lib; };

  apps.${system}.options = {
    type = "app";
    program = lib.getExe (pkgs.callPackage ./options-app.nix { });
    meta.description = "Every dotnix.* option of a host with its value";
  };

  formatter.${system} = pkgs.nixfmt-tree;

  devShells.${system}.default = pkgs.mkShellNoCC {
    packages = with pkgs; [
      nh
      nixfmt-tree
      go
      gopls
      gotools
      self.packages.${system}.dotnix-key
      self.packages.${system}.usb-stick
      cryptsetup
      util-linux
      parted
      dosfstools
      e2fsprogs
      grub2_efi
      qemu_kvm
      OVMF
    ];
  };
}
