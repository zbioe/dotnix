{...}: {
  imports = [
    ./hardware.nix
    ./config.nix
  ];

  user.name = "zbioe";
  time.zone = "America/Sao_Paulo";
  host = {
    name = "nv";
    i18n = "pt_BR.UTF-8";
  };

  modules = {
    system.stateVersion = "21.05";

    boot = {
      enable = true;
      timeout = 0;
      efi.enable = true;
    };

    keyboard = {
      layout = "br";
      options = ["ctrl:nocaps"];
    };

    wm = {
      enable = true;
      herbstluft.enable = true;
      gdm.enable = true;
    };
  };

}
