{
  pkgs,
  lib,
  outputs,
  ...
}:
{
  imports = [
    # ./hardware.nix
    # ./ui.nix
    ./packages.nix
  ];

  modules = {
    host = {
      name = "ln";
      i18n = "pt_BR.UTF-8";
    };
    time.zone = "America/Sao_Paulo";
    audio.enable = true;
    fish.enable = true;
    boot = {
      enable = true;
      kernelPackages = pkgs.linuxPackages_latest;
    };
    stylix = {
      enable = true;
      theme = "gruvbox-dark-medium";
    };
  };

  # DO NOT CHANGE IT
  system.stateVersion = "24.11";
}
