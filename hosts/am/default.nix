{ pkgs, ... }:
{
  imports = [
    ./hardware.nix
    ./ui.nix
  ];

  modules = {
    user = {
      shell = pkgs.fish;
    };
    host = {
      name = "am";
      i18n = "pt_BR.UTF-8";
    };
    time.zone = "America/Sao_Paulo";
    audio.enable = true;
    boot = {
      enable = true;
      kernelPackages = pkgs.linuxPackages_latest;
    };
    nvidia = {
      enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  programs.fish = {
    enable = true;
    shellAbbrs = {
      "n" = "nvim";
    };
    shellInit = ''
      set fish_greeting
      test -f ~/.secrets.fish && source ~/.secrets.fish
    '';
  };

  # DO NOT CHANGE IT
  system.stateVersion = "24.11";
}
