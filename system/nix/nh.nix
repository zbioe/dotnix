# `nh os switch` / `nh home switch`: rebuild with a package diff (nvd); its
# clean replaces nix.gc and also drops old home-manager generations
{ config, ... }:
{
  programs.nh = {
    enable = true;
    flake = "/home/${config.dotnix.core.user.name}/dotnix";
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep-since 10d --keep 5";
    };
  };
}
