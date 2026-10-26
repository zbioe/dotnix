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
        yt-dlp # video downloader
        video-downloader # video downloader GUI
        media-downloader # yt-dlp GUI

        # video editing
        kdePackages.kdenlive # video editor
        shotcut # video editor
        losslesscut-bin # lossless cut and trim
        handbrake # video transcoder
        blender # 3d and video sequencer

        # audio editing
        ardour # digital audio workstation
        zrythm # digital audio workstation
        lmms # beats, loops and synthesizers
        audacity # audio editor
        musescore # music notation

        # encoding and inspection
        ffmpeg-full # audio and video converter, every codec
        mediainfo # media metadata
        mkvtoolnix # matroska muxing
        sox # audio processing
        rubberband # time and pitch

        # raw photography
        darktable # raw workflow
        rawtherapee # raw converter

        # capture
        obs-studio # streaming and recording
        gpu-screen-recorder # low-overhead screen recorder
        simplescreenrecorder # screen recorder
        wf-recorder # screen recorder (wayland)
      ]
    );
  };
}
