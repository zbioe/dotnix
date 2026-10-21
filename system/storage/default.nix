{
  imports = [
    ./disk.nix
    ./impermanence.nix
    ./snapshots.nix
    ./backup.nix
    ./usb-key.nix
  ];

  services.fstrim.enable = true;
}
