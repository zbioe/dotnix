{ config, pkgs, ... }:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware.nix
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.supportedFilesystems = {
    btrfs = true;
  };
  hardware.enableAllFirmware = true;
  nixpkgs.config.allowUnfree = true;

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = false;
    device = "nodev";
    efiSupport = true;
    enableCryptodisk = true;
  };

  networking.hostName = "am"; # Define your hostname.
  networking.networkmanager.enable = true;

  services.openssh.enable = true;
  networking.firewall.enable = false;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.zbioe = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    hashedPassword = "$y$j9T$aUrSFZjFUIfKKBQ/C.bXY/$mS1UQvVwaBs6.777A7vnuMl3kGsWXpU0gY2VdtwdWi0";
  };

  time.timeZone = "America/Sao_Paulo";
  i18n.defaultLocale = "pt_BR.UTF-8";
  console = {
    font = "ter-v32n";
    earlySetup = false;
    useXkbConfig = true;
    packages = with pkgs; [ terminus_font ];
  };

  environment.systemPackages = with pkgs; [
    wget
    btop
    vim
    git
    mkpasswd
  ];

  system.stateVersion = "24.11";
}
