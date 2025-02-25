# iso.nix
{ config, pkgs, ... }:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  hardware.enableAllFirmware = true;
  nixpkgs.config.allowUnfree = true;

  services.openssh.enable = true;
  networking.firewall.enable = false;

  networking.wireless.enable = false;
  networking.networkmanager.enable = true;

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

  users.users.zbioe = {
    isNormalUser = true;
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    hashedPassword = "$y$j9T$aUrSFZjFUIfKKBQ/C.bXY/$mS1UQvVwaBs6.777A7vnuMl3kGsWXpU0gY2VdtwdWi0";
  };

  environment.systemPackages = with pkgs; [
    vim
    git
  ];

}
