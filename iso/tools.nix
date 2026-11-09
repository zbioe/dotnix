# On both ISOs: dotnix-install (a disk and a host for this machine),
# dotnix-mount (recovery) and the tools a recovery needs.
{
  lib,
  pkgs,
  username,
  ...
}:
let
  inherit
    (import ./scripts.nix {
      inherit lib pkgs username;
      src = "/etc/dotnix";
    })
    keys
    install
    mount
    ;
in
{
  environment.systemPackages = with pkgs; [
    install
    mount
    keys
    git
    gptfdisk
    cryptsetup
    (callPackage ../pkgs/dotnix-key { })
    btrfs-progs
    restic
    rclone
  ];
}
