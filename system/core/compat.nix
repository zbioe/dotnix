# Binaries built for other distros
{
  config,
  lib,
  pkgs,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.core.compat;
in
{
  options.dotnix.core.compat = {
    enable = lib.mkEnableOption "running binaries built for other distros";
    nixLd.enable = dotlib.mkItem cfg "nix-ld (dynamically linked binaries)";
    appimage.enable = dotlib.mkItem cfg "AppImages";
  };

  config = {
    programs.appimage = lib.mkIf cfg.appimage.enable {
      enable = true;
      binfmt = true;
    };

    programs.nix-ld = lib.mkIf cfg.nixLd.enable {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc
        fuse3
        icu
        nss
        openssl
        curl
        libglvnd
        libx11
        libxrandr
        libxext
        krb5
        mesa
        alsa-lib
        libGL
        libpng
        expat
        zlib
      ];
    };
  };
}
