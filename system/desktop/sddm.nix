{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.desktop;
in
lib.mkIf (cfg.enable && cfg.greeter == "sddm") {
  services.displayManager = {
    sddm = {
      enable = true;
      package = pkgs.kdePackages.sddm;
      theme = "where_is_my_sddm_theme";
      wayland = {
        enable = true;
        compositor = "kwin";
      };
      extraPackages = [ pkgs.kdePackages.qt5compat ];
    };
  };
  security.pam.services.sddm.enableGnomeKeyring = cfg.secrets == "gnome-keyring";
}
