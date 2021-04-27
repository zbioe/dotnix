{ config, pkgs, ... }:

{

  boot = {
    # this will automatically load the zfs password prompt on login
    # and kill the other prompt so boot can continue
    zfs = {
      # could import manually with "zfspool import -f <pool-name>"
      # If it gets error
      # You should only need to do this once
      # from nixos options:
      # https://search.nixos.org/options?channel=20.09&show=boot.zfs.forceImportAll&from=0&size=50&sort=relevance&query=zfs.
      forceImportAll = false;
      # if it's return an error
      # import manualy you edit grup and add kernel params zfs_force=1
      forceImportRoot = false;
      requestEncryptionCredentials = true;
    };
    loader = {
      systemd-boot.enable = true;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      grub = {
        # device = "nodev";
        # boot.loader.grub.copyKernels isi mportant for ZFS
        # From wiki: https://nixos.wiki/wiki/NixOS_on_ZFS
        # Github Issue: https://github.com/openzfs/zfs/issues/260
        # Using NixOS on a ZFS root file system might result
        # in the boot error external pointer tables not supported
        # when the number of hardlinks in the nix store gets very high
        # This can be avoided by adding this option
        copyKernels = true;
        zfsSupport = true;
        enable = true;
        efiSupport = true;
        splashImage = ./background.jpg;
        splashMode = "stretch";
        device = "/dev/disk/by-id/ata-SanDisk_SSD_PLUS_240_GB_174885803778";
        extraEntries = ''
          menuentry "Reboot" {
            reboot
          }
          menuentry "Poweroff" {
            halt
          }
        '';
      };
    };
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [ "intel_pstate=active" "zfs.zfs_arc_max=12884901888" ];
    kernelModules = [ "kvm-intel" "coretemp" ];
    supportedFilesystems = [ "zfs" ];
    blacklistedKernelModules = [ "snd_pcsp" ];
    initrd.kernelModules = [
      "xhci_pci"
      "ehci_pci"
      "ahci"
      "usb_storage"
      "sd_mod"
      "sr_mod"
      "rtsx_usb_sdmmc"
    ];
  };

}
