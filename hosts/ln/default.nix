{ ... }: {
  imports = [ ./hardware.nix ./config.nix ];

  user.name = "zbioe";
  time.zone = "America/Sao_Paulo";
  host = {
    name = "ln";
    i18n = "en_US.UTF-8";
  };

  modules = {
    system.stateVersion = "22.05";

    boot = {
      enable = true;
      timeout = 1;
      efi.enable = true;
      efi.device = "nodev";
      efi.mountPoint = "/boot";
    };

    keyboard = {
      layout = "br";
      variant = "abnt2";
      model = "thinkpad";
      options = [ "ctrl:swapcaps" ];
    };

    network.enable = true;
    audio.enable = true;

    wm = {
      enable = true;
      herbstluft.enable = true;
      gdm.enable = true;
    };
  };

}
