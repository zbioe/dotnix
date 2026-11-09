{ inputs, ... }:
{
  imports = [
    ../common.nix
    ./hardware-configuration.nix
    # disk, password and Secure Boot of its install (dotnix-install)
    ./install.nix
    inputs.hardware.nixosModules.lenovo-thinkpad-e14-amd
  ];

  networking.hostName = "te";

  dotnix = {
    hardware = {
      laptop.enable = true;
      graphics.amd = {
        enable = true;
        compute.enable = true;
      };
      keyboard = {
        layout = "br";
        model = "thinkpad";
        variant = "thinkpad";
      };
    };
    storage = {
      # its partitions by label, as dotnix-install makes them
      disk.enable = true;
      impermanence.enable = true;
      # the stick of the old keyfile: `sudo dotnix-key adopt /dev/sdX` once
      usbKey.enable = true;
    };
  };

  # DO NOT CHANGE IT
  system.stateVersion = "25.11";
}
