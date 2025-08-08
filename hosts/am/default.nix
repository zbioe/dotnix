{
  pkgs,
  lib,
  outputs,
  nvf,
  home-manager,
  ...
}:
{
  imports = [
    ./hardware.nix
    ./ui.nix
    ./packages.nix
  ];

  modules = {
    host = {
      name = "am";
      i18n = "pt_BR.UTF-8";
    };
    time.zone = "America/Sao_Paulo";
    audio.enable = true;
    fish.enable = true;
    boot = {
      enable = true;
      kernelPackages = pkgs.linuxPackages_latest;
    };
    nvidia = {
      enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
    stylix = {
      enable = true;
      theme = "gruvbox-dark-medium";
    };
  };

  environment.systemPackages = [
    nvf
    home-manager
  ];

  # DO NOT CHANGE IT
  system.stateVersion = "24.11";
}
