{ config, pkgs, ... }:

{

  environment = {
    systemPackages = with pkgs; [
      gcc
      zig
      lua
      act
      wget
      curl
      qemu
      bind
      delta
      teams
      unzip
      nixfmt
      cachix
      gnumake
      gitFull
      spotify
      luarocks
      wakatime
      git-crypt
      gdk_pixbuf
      pkg-config
      gtk_engines
      virt-manager
      polkit_gnome
      luarocks-nix
      gtk-engine-murrine
      gobject-introspection
      gsettings-desktop-schemas
      (pkgs.writeScriptBin "nixFlakes" ''
        #!/usr/bin/env bash
        exec ${pkgs.nixUnstable}/bin/nix --experimental-features "nix-command flakes" "$@"
      '')
    ];
    pathsToLink = [ "/libexec" ];
  };

}
