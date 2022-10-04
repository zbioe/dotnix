{ ... }: {
  imports = [ ./hardware.nix ./config.nix ];

  user.name = "zbioe";
  time.zone = "America/Sao_Paulo";
  host = {
    name = "nv";
    i18n = "pt_BR.UTF-8";
  };

  modules = {
    system.stateVersion = "22.05";

    boot = {
      enable = true;
      timeout = 0;
      efi.enable = true;
    };

    keyboard = {
      layout = "us";
      variant = "intl";
      options = [ "ctrl:nocaps" ];
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
