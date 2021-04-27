{ config, pkgs, ... }:

{

  fonts.fonts = with pkgs; [
    cherry
    cozette
    dina-font
    noto-fonts
    cascadia-code
    weather-icons
    noto-fonts-cjk
    font-awesome_5
    noto-fonts-emoji
    terminus_font_ttf
    material-design-icons
    emacs-all-the-icons-fonts
    hack-font
    source-code-pro
    (nerdfonts.override { fonts = [ "FiraCode" "DroidSansMono" "Terminus" ]; })
  ];

}
