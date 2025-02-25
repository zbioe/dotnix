{ ... }:
{
  imports = [
    ./hardware.nix
    ./boot.nix
    ./config.nix
    ./ui.nix
    ./sound.nix
  ];

  # DO NOT CHANGE IT
  system.stateVersion = "24.11";
}
