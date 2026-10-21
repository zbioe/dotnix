{
  config,
  lib,
  pkgs,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.packages.media;
in
{
  options.dotnix.packages.media = dotlib.mkPackages "image, audio and video";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = dotlib.packagesOf cfg (
      with pkgs;
      [
        krita # painting
        gimp # image editor
        inkscape # vector graphics
        potrace # bitmap to vector
        vlc # media player
        ffmpeg # audio and video converter
        yt-dlp # video downloader
        video-downloader # video downloader GUI
        media-downloader # yt-dlp GUI
        simplescreenrecorder # screen recorder
        wf-recorder # screen recorder (wayland)
      ]
    );
  };
}
