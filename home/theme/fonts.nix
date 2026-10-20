# Fonts of the whole setup (fontconfig, GTK, Qt, GRUB), shared by NixOS and home
{ pkgs }:
{
  sansSerif = {
    name = "DejaVu Sans";
    package = pkgs.dejavu_fonts;
  };
  serif = {
    name = "DejaVu Serif";
    package = pkgs.dejavu_fonts;
  };
  monospace = {
    name = "DejaVu Sans Mono";
    package = pkgs.dejavu_fonts;
  };
  emoji = {
    name = "Noto Color Emoji";
    package = pkgs.noto-fonts-color-emoji;
  };
  # points, for apps and GRUB
  size = 12;
}
