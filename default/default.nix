{
  pkgs,
  nixpkgs,
  unstable,
  home-module,
  ...
}:
{
  imports = [
    ./ui.nix
    ./tmux.nix
    ./config.nix
    ./packages.nix
    ./samba.nix
  ];

  hardware.enableAllFirmware = true;
  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [
      "ventoy-1.1.05"
    ];
  };

  nix = {
    nixPath = [
      "nixpkgs=${pkgs.path}"
      "unstable=${unstable.path}"
      "home-manager=${home-module}"
    ];
    registry = {
      nixpkgs.flake = nixpkgs;
    };
    settings = {
      # Manual optimise storage: nix-store --optimise
      # https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-auto-optimise-store
      auto-optimise-store = true;
      builders-use-substitutes = true;
    };
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 10d";
    };
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
      tarball-ttl = 900
    '';
  };

  networking.networkmanager.enable = true;
  networking.firewall.enable = true;
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
    "2606:4700:4700::1111"
    "2606:4700:4700::1001"
  ];

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  programs.dconf.enable = true;

  services = {
    udev = {
      enable = true;
      packages = with pkgs; [ gnome-settings-daemon ];
    };

    #
    dbus = {
      enable = true;
      packages = with pkgs; [ gnome2.GConf ];
    };
    # auto mount/unmount a drive
    gvfs.enable = true;
    udisks2.enable = true;

    # Thumbnail support for images
    tumbler.enable = true;
  };

  # Console defaults
  console = {
    font = "ter-v32n";
    earlySetup = true;
    useXkbConfig = true;
    packages = with pkgs; [ terminus_font ];
  };

  # Xdb defaults
  services.xserver.xkb = {
    layout = "br";
    model = "abnt2";
    options = "caps:ctrl_modifier";
  };

  # Ensure environment
  environment = {
    etc = {
      "nix/inputs/nixpkgs".source = nixpkgs;
      # keet io configurable from OS
      hosts.enable = false;
    };
    variables = {
      EDITOR = "nvim";
    };
  };
}
