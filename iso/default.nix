# iso.nix
{
  pkgs,
  ...
}:
{
  imports = [ ./findiso.nix ];
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
    "pipe-operators"
  ];

  hardware.enableAllFirmware = true;
  nixpkgs.config.allowUnfree = true;
  boot.zfs.forceImportRoot = false;

  services.openssh.enable = true;
  networking.firewall.enable = false;

  networking.networkmanager = {
    enable = true;
    wifi.powersave = false;
  };

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

  users.users.root = {
    openssh.authorizedKeys.keys = import ../system/core/keys.nix;
  };

  environment.systemPackages = with pkgs; [
    vim
    git
  ];

}
