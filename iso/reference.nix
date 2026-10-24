# A host as dotnix-install writes it (iso/tools.nix), on no machine in
# particular: the full ISO carries what building it takes, so installing a
# real one needs no network (iso/live.nix)
{ lib, modulesPath, ... }:
{
  imports = [
    ../hosts/common.nix
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  networking.hostName = "reference";

  dotnix = {
    core.homeActivation.enable = true;
    hardware.keyboard.layout = "br";
    storage = {
      disk = {
        enable = true;
        device = "/dev/disk/by-id/reference";
      };
      impermanence.enable = true;
      snapshots.enable = true;
      backup = {
        enable = true;
        cacheDir = "/var/lib/nodatacow/backup";
      };
    };
  };

  # whichever CPU it lands on
  hardware.cpu = {
    amd.updateMicrocode = true;
    intel.updateMicrocode = true;
  };
  boot.initrd.availableKernelModules = [
    "nvme"
    "ahci"
    "xhci_pci"
    "usbhid"
    "sd_mod"
    "virtio_pci"
    "virtio_blk"
  ];
  nixpkgs.hostPlatform = "x86_64-linux";

  system.stateVersion = lib.trivial.release;
}
