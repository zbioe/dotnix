{ config, pkgs, ... }:

{

  environment = {
    systemPackages = with pkgs; [
      git
      gcc
      zig
      lua
      wget
      curl
      qemu
      bind
      delta
      unzip
      nixfmt
      cachix
      gnumake
      luarocks
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
    ];
    pathsToLink = [ "/libexec" ];
  };

}
