# findiso= (boot this ISO from a file on another disk) for the systemd initrd, which lacks it
{ config, pkgs, ... }:
{
  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "usb_storage"
    "uas"
    "sd_mod"
    "loop"
  ];
  boot.initrd.supportedFilesystems = [
    "ext4"
    "vfat"
    "exfat"
  ];
  # tells usb-stick (and its GRUB menu) this NixOS ISO boots from a file
  isoImage.contents = [
    {
      source = pkgs.writeText "dotnix-findiso" "";
      target = "/.dotnix-findiso";
    }
  ];
  # the loop device gets the ISO's label, so /iso mounts as from a CD
  boot.initrd.systemd.services.findiso = {
    description = "Find the ISO file given by findiso=";
    wantedBy = [ "initrd.target" ];
    after = [
      "systemd-udev-trigger.service"
      "systemd-modules-load.service"
    ];
    unitConfig = {
      DefaultDependencies = false;
      ConditionKernelCommandLine = "findiso";
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [
      pkgs.coreutils
      config.boot.initrd.systemd.package.util-linux
    ];
    script = ''
      iso=""
      for word in $(cat /proc/cmdline); do
        case $word in
        findiso=*) iso=''${word#findiso=} ;;
        esac
      done
      mkdir -p /findiso
      for _ in $(seq 120); do
        for dev in $(blkid -o device); do
          mount -o ro "$dev" /findiso 2>/dev/null || continue
          if [ -f "/findiso$iso" ]; then
            losetup --find --read-only --show "/findiso$iso"
            exit 0
          fi
          umount /findiso
        done
        sleep 0.5
      done
      echo "findiso: $iso not found on any disk" >&2
      exit 1
    '';
  };
}
