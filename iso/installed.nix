# iso/reference.nix as dotnix-install fills it in for a machine (iso/tools.nix:
# its name, disk, swap, password, Secure Boot with a TPM, and a
# hardware-configuration.nix like nixos-generate-config's): what
# `nix run .#iso-closure` checks the full ISO can build offline
{ lib, ... }:
{
  networking.hostName = lib.mkForce "installed";
  dotnix = {
    core = {
      user.passwordFile = "/persist/secrets/zbioe.passwd";
      boot = {
        loader = "limine";
        secureBoot.enable = true;
        tpm2.enable = true;
      };
    };
    storage.disk = {
      device = lib.mkForce "/dev/disk/by-id/nvme-installed";
      swapSize = "16G";
    };
  };
  boot = {
    initrd.availableKernelModules = [
      "thunderbolt"
      "usb_storage"
    ];
    kernelModules = [ "kvm-amd" ];
  };
}
