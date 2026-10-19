# full-iso: this whole setup (system + the user's home) as a live USB that
# boots on any PC, and installs itself from there (`dotnix-install`, offline:
# everything is already in the image). Nothing private goes in: no keys, no
# passwords besides the default user one ("weakPass", modules/default.nix),
# an empty keyring; files come back from the backup (`backup setup`).
{
  config,
  lib,
  pkgs,
  modulesPath,
  dotnix,
  homeActivation,
  ...
}:
{
  imports = [
    "${modulesPath}/installer/cd-dvd/iso-image.nix"
    # initrd modules and firmware for whatever machine it lands on
    "${modulesPath}/profiles/all-hardware.nix"
    ./tools.nix
  ];

  modules.host.name = "dotnix-live";

  # the ISO boots with its own loader (isolinux / GRUB EFI from iso-image)
  modules.boot.enable = lib.mkForce false;
  boot.plymouth.enable = lib.mkForce false;

  isoImage = {
    edition = "dotnix";
    volumeID = "DOTNIX";
    makeEfiBootable = true;
    makeUsbBootable = true;
    # the smallest image (a 32 GB drive): slower to build, as fast to read
    squashfsCompression = "zstd -Xcompression-level 19";
  };

  # the home of `nh home switch -c bx`, applied at every boot
  modules.homeActivation = {
    enable = true;
    package = homeActivation;
    always = true;
  };

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
    lib.unique (sources dotnix);

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
  # no nodatacow subvolume to bind these from (default/): plain directories
  fileSystems =
    lib.genAttrs
      [
        "/var/lib/flatpak"
        "/var/lib/waydroid"
        "/var/lib/cloudflare-warp"
      ]
      (_: {
        enable = lib.mkForce false;
      });
}
