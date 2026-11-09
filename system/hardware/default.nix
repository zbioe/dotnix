{
  imports = [
    ./graphics.nix
    ./audio.nix
    ./bluetooth.nix
    ./keyboard.nix
    ./ddc.nix
    ./webcam.nix
    ./firmware.nix
    ./laptop.nix
  ];

  hardware.enableAllFirmware = true;

  # batteries: the laptop's, and those of Bluetooth headsets and mice, for
  # the bar. Low and critical as the bar warns (home/desktop/noctalia); at 3%
  # it shuts down cleanly instead of dying
  services.upower = {
    enable = true;
    percentageLow = 20;
    percentageCritical = 5;
    percentageAction = 3;
    criticalPowerAction = "PowerOff";
  };
}
