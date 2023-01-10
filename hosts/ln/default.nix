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

    bluetooth = {
      enable = true;
      powerOnBoot = false;
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
      leftwm.enable = true;
      herbstluft.enable = true;
      gdm.enable = true;
    };
  };

}
