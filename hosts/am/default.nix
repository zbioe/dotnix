{ ... }:
{
  imports = [
    ./hardware.nix
    ./boot.nix
    ./config.nix
    ./ui.nix
    ./sound.nix
    ./nvidia.nix
  ];

  # DO NOT CHANGE IT
  system.stateVersion = "24.11";
}
