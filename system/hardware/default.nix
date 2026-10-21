{
  imports = [
    ./graphics.nix
    ./audio.nix
    ./bluetooth.nix
    ./keyboard.nix
    ./ddc.nix
    ./webcam.nix
  ];

  hardware.enableAllFirmware = true;
}
