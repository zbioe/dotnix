# NixOS: what a dotnix host can be; hosts/ turns the parts on
{
  imports = [
    ./core
    ./nix
    ./hardware
    ./storage
    ./network
    ./desktop
    ./services
    ./packages
  ];
}
