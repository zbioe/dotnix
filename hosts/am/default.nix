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
    ./polkit-rules.nix
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
    stylix = {
      enable = true;
      autoEnable = true;
      theme = "gruvbox-dark-medium";
    };
    evremap =
      let
        remap = [
          {
            input = [
              "KEY_CAPSLOCK"
              "KEY_H"
            ];
            output = [ "KEY_BACKSPACE" ];
          }
          {
            input = [
              "KEY_CAPSLOCK"
              "KEY_M"
            ];
            output = [ "KEY_ENTER" ];
          }
          {
            input = [
              "KEY_CAPSLOCK"
              "KEY_I"
            ];
            output = [ "KEY_TAB" ];
          }
          {
            input = [
              "KEY_CAPSLOCK"
              "KEY_H"
            ];
            output = [ "KEY_BACKSPACE" ];
          }
        ];
        dual_role = [
          {
            input = "KEY_CAPSLOCK";
            hold = [ "KEY_LEFTCTRL" ];
            tap = [ "KEY_ESC" ];
          }
        ];
      in
      {
        enable = true;
        devices = {
          internal = {
            device_name = "AT Translated Set 2 keyboard";
            inherit dual_role;
          };
          external = {
            device_name = "SINO WEALTH Gaming KB ";
            inherit dual_role;
          };
        };
      };
  };

  # DO NOT CHANGE IT
  system.stateVersion = "24.11";
}
