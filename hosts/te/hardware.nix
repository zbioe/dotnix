{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [
    "kvm-amd"
    "amdgpu"
  ];
  boot.extraModulePackages = [ ];

  boot.initrd.systemd.services.rollback = {
    description = "Rollback BTRFS root subvolume to a pristine state";
    wantedBy = [ "initrd.target" ];
    after = [ "systemd-cryptsetup@enc.service" ]; # Wait for the luks open
    before = [ "sysroot.mount" ]; # Runs before mount the /
    unitConfig.DefaultDependencies = "no";
    serviceConfig.Type = "oneshot";
    script = ''
      mkdir -p /mnt

      mount -o subvolid=5 /dev/mapper/enc /mnt

      if [ -d /mnt/root ]; then
        btrfs subvolume delete /mnt/root
      fi

      btrfs subvolume snapshot /mnt/root-blank /mnt/root

      umount /mnt
    '';
  };

  fileSystems."/" = {
    device = "/dev/mapper/enc";
    fsType = "btrfs";
    options = [
      "subvol=root"
      "compress=zstd"
      "noatime"
    ];
  };

  boot.initrd.luks.devices."enc".device = "/dev/disk/by-uuid/6809fd8d-bbe9-4415-b5f0-f57a64ce7443";

  fileSystems."/home" = {
    device = "/dev/mapper/enc";
    fsType = "btrfs";
    options = [
      "subvol=home"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/mapper/enc";
    fsType = "btrfs";
    options = [
      "subvol=nix"
      "compress=zstd"
      "noatime"
    ];
  };

  fileSystems."/persist" = {
    device = "/dev/mapper/enc";
    fsType = "btrfs";
    options = [
      "subvol=persist"
      "compress=zstd"
      "noatime"
    ];
    neededForBoot = true;
  };

  fileSystems."/var/log" = {
    device = "/dev/mapper/enc";
    fsType = "btrfs";
    options = [
      "subvol=log"
      "compress=zstd"
      "noatime"
    ];
    neededForBoot = true;
  };

  fileSystems."/var/lib/nodatacow" = {
    device = "/dev/mapper/enc";
    fsType = "btrfs";
    options = [
      "subvol=nodatacow"
      "noatime"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/BE46-97A6";
    fsType = "vfat";
    options = [
      "fmask=0022"
      "dmask=0022"
    ];
  };

  # Binds
  fileSystems."/var/lib/docker" = {
    device = "/var/lib/nodatacow/docker";
    fsType = "none";
    options = [ "bind" ];
  };

  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/353ac003-1244-4840-973a-37c8911a2e3e";
      randomEncryption.enable = true;
    }
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
