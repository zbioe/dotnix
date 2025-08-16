{ pkgs, nixpkgs, ... }:
{
  imports = [
    ./user.nix
    ./ui.nix
    ./packages.nix
  ];

  hardware.enableAllFirmware = true;
  nixpkgs.config.allowUnfree = true;

  nix = {
    nixPath = [ "nixpkgs=${pkgs.path}" ];
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

  console = {
    font = "ter-v32n";
    earlySetup = true;
    useXkbConfig = true;
    packages = with pkgs; [ terminus_font ];
  };

  services.xserver.xkb = {
    layout = "br";
    model = "abnt2";
    options = "caps:ctrl_modifier";
  };

  environment = {
    etc = {
      "nix/inputs/nixpkgs".source = nixpkgs;
    };
    variables = {
      EDITOR = "nvim";
    };
  };
}
