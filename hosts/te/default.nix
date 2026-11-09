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

  # full speed on AC, saving on battery
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      CPU_DRIVER_OPMODE_ON_AC = "active";
      CPU_DRIVER_OPMODE_ON_BAT = "active";
    };
  };

  # DO NOT CHANGE IT
  system.stateVersion = "25.11";
}
