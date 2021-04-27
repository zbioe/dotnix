{ config, pkgs, ... }:

{

  networking = {
    hostName = "pota";
    hostId = "3a9aa5ff";
    networkmanager.enable = true;
  };

}
