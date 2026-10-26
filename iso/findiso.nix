# findiso= (boot this ISO from a file on another disk) for the systemd initrd, which lacks it
{ config, pkgs, ... }:
let
  udevadm = "${config.boot.initrd.systemd.package}/bin/udevadm";
in
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
      iso="" line=x
      for word in $(cat /proc/cmdline); do
        case $word in
        findiso=*) iso=''${word#findiso=} ;;
        esac
      done
      mkdir -p /findiso
      found() {
        mount -o ro "$1" /findiso 2>/dev/null || return 1
        if [ -f "/findiso$iso" ]; then
          losetup --find --read-only --show "/findiso$iso"
          exit 0
        fi
        umount /findiso
        return 1
      }
      # disks as udev finishes with them (a slow USB stick), watched before
      # looking at those already there
      exec {events}< <(exec ${udevadm} monitor --udev --subsystem-match=block --property)
      until [ "$line" = "" ]; do read -r line <&"$events"; done
      for dev in $(blkid -o device); do found "$dev" || true; done
      deadline=$((SECONDS + 60)) action="" dev=""
      while [ "$SECONDS" -lt "$deadline" ] && read -r -t $((deadline - SECONDS)) line <&"$events"; do
        case $line in
        ACTION=*) action=''${line#ACTION=} ;;
        DEVNAME=*) dev=''${line#DEVNAME=} ;;
        "")
          if [ "$action" = add ] || [ "$action" = change ]; then found "$dev" || true; fi
          action="" dev=""
          ;;
        esac
      done
      echo "findiso: $iso not found on any disk" >&2
      exit 1
    '';
  };
}
