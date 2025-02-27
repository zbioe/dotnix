{
  config,
  pkgs,
  user,
  ...
}:
{
  nix.settings =
    let
      users = [
        "root"
        "${user}"
      ];
    in
    {
      trusted-users = users;
      allowed-users = users;
      experimental-features = [
        "nix-command"
        "flakes"
        "pipe-operators"
      ];
    };

  security.sudo.wheelNeedsPassword = false;

  hardware.enableAllFirmware = true;
  nixpkgs.config.allowUnfree = true;

  networking.hostName = "am"; # Define your hostname.
  networking.networkmanager.enable = true;

  services.openssh.enable = true;
  networking.firewall.enable = false;

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
    options = "ctrl:swapcaps";
  };

  environment.systemPackages = with pkgs; [
    wget
    btop
    neovim
    vim
    git
    mkpasswd
    home-manager
  ];
}
