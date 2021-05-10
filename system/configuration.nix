{ config, pkgs, ... }:

{

  imports = [
    ./users.nix
    ./cachix.nix
    ./modules/misc.nix
    ./modules/boot/boot.nix
    ./modules/fonts/fonts.nix
    ./modules/display/X11.nix
    ./hardware-configuration.nix
    ./modules/hardware/hardware.nix
    ./modules/environment/packages.nix
    ./modules/networking/networking.nix
  ];

  system.stateVersion = "21.05";

}

