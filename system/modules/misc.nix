{ config, pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  services.nixops-dns = {
    enable = true;
    domain = "o";
    user = "zbioe";
  };

  services.teamviewer.enable = true;

  virtualisation = {
    libvirtd.enable = true;
    docker.enable = true;
    lxd = {
      enable = true;
      zfsSupport = true;
    };

    lxc = {
      enable = true;
      lxcfs.enable = true;
    };
    virtualbox.host = {
      enable = true;
      enableExtensionPack = true;
    };
  };

  security = {
    polkit.enable = true;
    doas.enable = true;
    sudo = {
      enable = true;
      wheelNeedsPassword = false;
    };
  };

  i18n.defaultLocale = "en_US.UTF-8";
  console = { useXkbConfig = true; };

  time.timeZone = "America/Sao_Paulo";

  services.dbus.packages = with pkgs; [ gnome2.GConf ];

  programs.dconf.enable = true;

  services = {
    openssh = {
      enable = true;
      allowSFTP = true;
    };
  };

}
