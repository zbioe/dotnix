# The whole desktop, live and installing itself (`dotnix-install`) offline,
# with nothing private in it; the live user's password is weakPass. The full
# ISO boots it (iso/full.nix), checks/vm/install.nix tests it.
{
  config,
  lib,
  pkgs,
  dotnix,
  installReference,
  ...
}:
let
  ref = installReference;
  # the host before system.replaceDependencies swaps GTK4 in: a new host is
  # built from these packages, then swapped too
  refBase = ref.extendModules {
    modules = [ { system.replaceDependencies.replacements = lib.mkForce [ ]; } ];
  };
  refPkgs = ref.pkgs;
  outputs = [ "out" ] ++ ref.config.environment.extraOutputsToInstall;
  # kept as they are: this system's own swap would turn them into the
  # swapped ones the new host can't be built from
  unswapped = [
    refBase.config.system.build.toplevel
    # the home too swaps GTK4 in (lib/default.nix)
    dotnix.homeConfigurations.bx.config.home.activationPackage
  ]
  ++ lib.concatMap (
    p: map (o: p.${o}) (lib.intersectLists (p.outputs or [ "out" ]) outputs)
  ) ref.config.environment.systemPackages;
  # zmacs' twist reads package headers through derivations of its own nixpkgs
  inherit (pkgs.stdenv.hostPlatform) system;
  zmacs = dotnix.inputs.zmacs.packages.${system};
  zmacsPkgs = dotnix.inputs.zmacs.inputs.nixpkgs.legacyPackages.${system};
in
{
  imports = [
    ../hosts/common.nix
    ./tools.nix
  ];

  networking.hostName = "dotnix-live";

  dotnix = {
    # the ISO boots with its own loader (isolinux / GRUB EFI from iso-image)
    core.boot.enable = lib.mkForce false;
    # no secrets on a live system: weakPass is the user's password
    core.secrets.enable = lib.mkForce false;
    core.user.passwordFile = lib.mkForce null;
    network.wifi.enable = lib.mkForce false;
    hardware.keyboard = {
      layout = "br";
      model = "br";
      variant = "br";
    };
    # the home of `nh home switch -c bx`, applied at every boot
    core.homeActivation = {
      enable = true;
      always = true;
    };
  };
  boot.plymouth.enable = lib.mkForce false;

  # the flake itself, to install from (and to look at)
  environment.etc."dotnix".source = dotnix;
  # and what evaluating it reads (every input's source, recursively), so
  # dotnix-install works offline
  system.extraDependencies =
    let
      sources =
        flake:
        [ flake.outPath ]
        ++ lib.concatMap sources (
          lib.attrValues (lib.filterAttrs (_: i: i ? outPath) (flake.inputs or { }))
        );
    in
    lib.unique (sources dotnix)
    # and what building a new host takes: a host like it (iso/reference.nix),
    # its packages with the outputs system-path links but doesn't keep, the
    # tools of what only that host builds (units, /etc, initrd, disko) and
    # of what evaluating it builds (themes, Proton Pass' version, zmacs)
    ++ unswapped
    ++ [
      ref.config.system.build.toplevel
      ref.config.system.build.destroyFormatMount
      # baked into the initrd, so in no closure
      ref.config.hardware.cpu.amd.microcodePackage
      ref.config.hardware.cpu.intel.microcodePackage
    ]
    ++ (with refPkgs; [
      stdenv
      stdenvNoCC
      shellcheck-minimal
      bashInteractive.dev
      kmod.dev
      texinfo
      base16-schemes
      dpkg
    ])
    ++ [
      zmacs.nix-elpa
      zmacsPkgs.emacs-pgtk.src
    ]
    ++ map (p: p.src) (lib.filter lib.isDerivation (lib.attrValues zmacs.emacs.elispPackages))
    ++ (with zmacsPkgs; [
      stdenv
      stdenvNoCC
      git
      ripgrep
    ]);

  # (the initrd too, as by default)
  system.replaceDependencies.cutoffPackages = unswapped ++ [ config.system.build.initialRamdisk ];

  # the installer in the launcher (iso/tools.nix)
  environment.systemPackages = [
    (pkgs.makeDesktopItem {
      name = "dotnix-install";
      desktopName = "Install dotnix";
      comment = "Install this system on this machine's disk";
      exec = "foot --title=\"Install dotnix\" dotnix-install";
      icon = "system-software-install";
      categories = [ "System" ];
    })
  ];

  system.stateVersion = lib.trivial.release;

  # a live root is overlayfs on tmpfs: docker's btrfs driver can't work there
  virtualisation.docker.daemon.settings.storage-driver = lib.mkForce "overlay2";
  # no nodatacow subvolume to bind these from: plain directories
  fileSystems =
    lib.genAttrs
      [
        "/var/lib/docker"
        "/var/lib/flatpak"
        "/var/lib/waydroid"
        "/var/lib/cloudflare-warp"
      ]
      (_: {
        enable = lib.mkForce false;
      });
}
