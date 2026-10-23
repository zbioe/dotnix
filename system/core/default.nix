{
  imports = [
    ./users.nix
    ./locale.nix
    ./boot.nix
    ./security.nix
    ./secrets.nix
    ./hardening.nix
    ./time.nix
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

  # command-not-found from a prebuilt nix-index, and `, cmd` runs what isn't installed
  programs.nix-index-database.comma.enable = true;
  environment.variables.EDITOR = "nvim";

  systemd.tmpfiles.rules = [
    # the user reads the boot log
    "a+ /var/log/boot.log - - - - u:1000:r"
    "w /sys/class/leds/platform::micmute/brightness - - - - 0"
  ];
}
