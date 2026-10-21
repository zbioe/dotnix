{
  imports = [
    ./users.nix
    ./locale.nix
    ./boot.nix
    ./security.nix
    ./secrets.nix
    ./compat.nix
    ./home-activation.nix
    ./updates.nix
  ];

  # compressed swap in RAM first (the disk swap stays as overflow), and
  # kill the biggest offender before the desktop freezes
  zramSwap.enable = true;
  services.earlyoom = {
    enable = true;
    enableNotifications = true;
  };

  programs.command-not-found.enable = true;
  environment.variables.EDITOR = "nvim";

  systemd.tmpfiles.rules = [
    # the user reads the boot log
    "a+ /var/log/boot.log - - - - u:1000:r"
    "w /sys/class/leds/platform::micmute/brightness - - - - 0"
  ];
}
