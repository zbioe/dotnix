{ ... }:
{
  imports = [
    ./hardware.nix
    ./boot.nix
    ./config.nix
  ];

  # DO NOT CHANGE IT
  system.stateVersion = "24.11";
}
