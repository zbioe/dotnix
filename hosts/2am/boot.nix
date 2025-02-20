{ config, lib, pkgs, ... }:

{
 boot = {
      loader = {
        efi.canTouchEfiVariables = true;
        grub = {
          enable = true;
          device = "nodev";
          efiSupport = true;
        };
      };
      initrd.luks.devices.cryptroot.device = "/dev/disk/by-label/boot";
}
