{
  imports = [
    ./graphics.nix
    ./display-watch.nix
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
  # it reads the battery's charge limit (udev's CHARGE_LIMIT) once, when it
  # starts: started before udev got to the battery, it took the limit as
  # unsupported and the bar's and GNOME's switch went grey
  systemd.services.upower = {
    wants = [ "systemd-udev-settle.service" ];
    after = [ "systemd-udev-settle.service" ];
  };
}
