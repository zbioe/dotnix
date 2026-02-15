{ pkgs, ... }:
{
  imports = [
    ./hardware.nix
  ];

  modules = {
    host = {
      name = "te";
    };
  };

  # force deep sleep
  boot.kernelParams = [ "mem_sleep_default=deep" ];

  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      CPU_DRIVER_OPMODE_ON_AC = "active";
      CPU_DRIVER_OPMODE_ON_BAT = "active";

      DEVICES_TO_DISABLE_ON_STARTUP = "bluetooth";
    };
  };

  services.xserver.videoDrivers = [ "amdgpu" ];

  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      amdvlk
      rocmPackages.clr.icd # OpenCL para tarefas pesadas
    ];
  };

  # DO NOT CHANGE IT
  system.stateVersion = "25.11";
}
