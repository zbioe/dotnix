{
  pkgs,
  ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware.nix
  ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "pipe-operators"
  ];
  hardware.enableAllFirmware = true;
  hardware.cpu.amd.updateMicrocode = true;

  nixpkgs.config.allowUnfree = true;

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    initrd.systemd.enable = true;
    supportedFilesystems = {
      btrfs = true;
    };
    loader = {
      efi.canTouchEfiVariables = false;
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        enableCryptodisk = true;
        gfxmodeEfi = "1920x1200";
        efiInstallAsRemovable = true;
      };
    };
  };

  networking.hostName = "tmp"; # Define your hostname.
  networking.networkmanager.enable = true;

  services.openssh.enable = true;
  networking.firewall.enable = false;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.zbioe = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    hashedPassword = "$y$j9T$aUrSFZjFUIfKKBQ/C.bXY/$mS1UQvVwaBs6.777A7vnuMl3kGsWXpU0gY2VdtwdWi0";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOwQjy6iC67tqmTAlin7+KWvy74GdLgLOIQRmtTkDMNY zbioe@i"
    ];
  };
  users.mutableUsers = false;

  time.timeZone = "America/Sao_Paulo";
  i18n.defaultLocale = "pt_BR.UTF-8";
  console = {
    font = "ter-v32n";
    earlySetup = false;
    useXkbConfig = true;
    packages = with pkgs; [ terminus_font ];
  };
  services.xserver.xkb = {
    layout = "br";
    model = "abnt2";
    options = "caps:ctrl_modifier";
  };

  environment.systemPackages = with pkgs; [
    wget
    curl
    btop
    vim
    git
    mkpasswd
    parted
    gptfdisk
  ];

  system.stateVersion = "25.11";
}
