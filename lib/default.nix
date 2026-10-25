# Every output of the flake: hosts (one per folder of hosts/), the ISOs,
# homes, packages, checks and the dev shell.
inputs@{
  self,
  nixpkgs,
  nixpkgs-unstable,
  home,
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
    # every host's home, for what a host does with its own (system/services/cache.nix)
    homes = self.homeConfigurations;
  };

  # the desktop: every host and the full ISO
  baseModules = [
    ../system
    inputs.nix-index-database.nixosModules.nix-index
    inputs.disko.nixosModules.disko
    inputs.mango.nixosModules.mango
    inputs.impermanence.nixosModules.impermanence
  ];

  mkHost =
    modules:
    lib.nixosSystem {
      inherit system specialArgs;
      modules = baseModules ++ modules;
    };

  mkHome =
    name:
    let
      homePkgs = import nixpkgs {
        inherit system;
        overlays = [ (import ../overlays { inherit noctalia; }) ];
      };
      osConfig = self.nixosConfigurations.${name}.config;
      hm = home.lib.homeManagerConfiguration {
        pkgs = homePkgs;
        extraSpecialArgs = {
          inherit
            username
            noctalia
            unstable
            dotlib
            ;
          inherit (inputs) base16 zmacs;
          # the host's choices, as home-manager names them inside NixOS
          inherit osConfig;
          # the home starts with its host: same release
          inherit (osConfig.system) stateVersion;
          ai-memory = inputs.ai-memory.packages.${system}.default;
        };
        modules = [
          inputs.mango.hmModules.mango
          inputs.noctalia.homeModules.default
          inputs.sops.homeManagerModules.sops
          inputs.zmacs.homeModules.default
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

  # the live system of the full ISO and of install-test (iso/live.nix)
  liveArgs = specialArgs // {
    dotnix = self;
    installReference = mkHost [ ../iso/reference.nix ];
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
      specialArgs = liveArgs;
      modules = baseModules ++ [ ../iso/full.nix ];
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
    disk-test = pkgs.testers.runNixOSTest (import ../checks/vm/disk.nix { inherit inputs dotlib; });
    secure-boot-test = pkgs.testers.runNixOSTest (
      import ../checks/vm/secure-boot.nix { inherit inputs dotlib; }
    );
    sbctl-keys-test = pkgs.testers.runNixOSTest (
      import ../checks/vm/sbctl-keys.nix { inherit inputs dotlib; }
    );
    adopt-test = pkgs.testers.runNixOSTest (import ../checks/vm/adopt.nix { inherit inputs dotlib; });
    install-test = pkgs.testers.runNixOSTest (
      import ../checks/vm/install.nix {
        inherit nixpkgs;
        modules = baseModules;
        specialArgs = liveArgs;
      }
    );
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
