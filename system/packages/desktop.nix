{
  config,
  lib,
  pkgs,
  unstable,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.packages.desktop;
in
{
  options.dotnix.packages.desktop = dotlib.mkPackages "desktop utilities";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = dotlib.packagesOf cfg (
      with pkgs;
      [
        libnotify # notify-send
        playerctl # media player control
        brightnessctl # screen brightness
        wl-clipboard # clipboard from the terminal
        wtype # types text from scripts
        slurp # select a screen region
        grim # screenshots
        tesseract # text from images
        imagemagick # image editing from the terminal
        wdisplays # monitor layout
        wlr-randr # monitor settings from the terminal
        hyprpicker # color picker
        nautilus # file manager
        geeqie # image viewer
        pavucontrol # sound control
        alacritty # terminal
        adwaita-icon-theme # fallback icons
        unstable.tor-browser # browser over tor
      ]
    );
  };
}
