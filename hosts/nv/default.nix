{
  imports = [
    ./hardware.nix
    ../../modules
  ];

  networking.hostName = "nv";

  hardware.nvidia.prime = {
    # Bus ID of the NVIDIA GPU. You can find it using lspci, either under 3D or VGA
    nvidiaBusId = "PCI:1:0:0";

    # Bus ID of the Intel GPU. You can find it using lspci, either under 3D or VGA
    intelBusId = "PCI:0:2:0";
  };

  user.name = "zbioe";

  modules = {
    boot = {
      enable = true;
      timeout = 0;
      efi.enable = true;
    };
    system.stateVersion = "21.05";
  };

}
