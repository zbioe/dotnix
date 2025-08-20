{
  pkgs,
  lib,
  outputs,
  ...
}:
{
  imports = [
    ./hardware.nix
  ];

  modules = {
    host = {
      name = "ln";
      i18n = "pt_BR.UTF-8";
    };
    time.zone = "America/Sao_Paulo";
    audio.enable = true;
    bluetooth.enable = true;
    boot = {
      enable = true;
      kernelPackages = pkgs.linuxPackages_latest;
    };
    stylix = {
      enable = true;
      autoEnable = true;
      theme = "gruvbox-dark-medium";
    };
    evremap =
      let
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
  system.stateVersion = "25.05";
}
