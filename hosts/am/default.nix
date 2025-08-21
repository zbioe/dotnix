_ :
{
  imports = [
    ./hardware.nix
  ];

  modules = {
    host = {
      name = "am";
    };
    nvidia = {
      enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # DO NOT CHANGE IT
  system.stateVersion = "24.11";
}
