{ config, pkgs, ... }:

{

  users = {
    mutableUsers = true;
    defaultUserShell = pkgs.fish;
    users = {
      zbioe = {
        isNormalUser = true;
        extraGroups =
          [ "wheel" "networkmanager" "docker" "vboxusers" "disk" "audio" ];
        initialPassword = "pass";
      };
    };
  };

}
