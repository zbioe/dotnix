_ :
{
  imports = [
    ./hardware.nix
  ];

  modules = {
    host = {
      name = "ln";
    };
  };

  # DO NOT CHANGE IT
  system.stateVersion = "25.05";
}
