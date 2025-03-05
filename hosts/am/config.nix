{
  config,
  pkgs,
  user,
  ...
}:
{
  hardware.enableAllFirmware = true;
  nixpkgs.config.allowUnfree = true;

  networking.networkmanager.enable = true;

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
