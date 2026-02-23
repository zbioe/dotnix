{ username, pkgs, ... }:
{
  modules = {
    host.i18n = "pt_BR.UTF-8";
    user = {
      name = username;
      shell = pkgs.fish;
      hashedPassword = "$y$j9T$aUrSFZjFUIfKKBQ/C.bXY/$mS1UQvVwaBs6.777A7vnuMl3kGsWXpU0gY2VdtwdWi0";
      uid = 1000;
      authorizedKeys = import ./keys.nix;
      extraGroups = [
        "wheel"
        "users"
        "input"
        "networkmanager"
        "audio"
        "video"
        "disk"
        "nixbld"
        "systemd-journal"
        "dbus"
        "bluetooth"
        "docker"
      ];
    };
    time.zone = "America/Sao_Paulo";
    audio.enable = true;
    bluetooth.enable = true;

    boot = {
      enable = true;
      kernelPackages = pkgs.linuxPackages_zen;
    };
    stylix = {
      enable = true;
      autoEnable = true;
      theme = "gruvbox-dark-medium";
      polarity = "dark";
    };
  };
}
