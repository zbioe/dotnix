{ pkgs, ... }:
{
  imports = [
    ./hardware.nix
    ./boot.nix
    ./config.nix
    ./ui.nix
    ./nvidia.nix
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
