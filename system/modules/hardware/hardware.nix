{ config, pkgs, ... }:

{

  hardware = {
    pulseaudio = { enable = true; };
    opengl = {
      enable = true;
      extraPackages = with pkgs; [
        intel-media-driver
        vaapiIntel
        vaapiVdpau
        libvdpau-va-gl
      ];
    };
    cpu.intel.updateMicrocode = true;
    bluetooth.enable = true;
  };
  sound.enable = true;

}
