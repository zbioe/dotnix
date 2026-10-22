# every font `theme font` can pick (home/theme/fonts), so any choice applies live
{
  config,
  lib,
  pkgs,
  noctalia,
  ...
}:
let
  fonts = import ../../home/theme/fonts/catalog.nix { inherit pkgs; };
  icons = import ../../home/theme/icons/catalog.nix { inherit pkgs noctalia; };
in
{
  options.dotnix.desktop.fonts.enable = lib.mkEnableOption "the font catalog";

  config = lib.mkIf config.dotnix.desktop.fonts.enable {
    fonts.fontconfig = {
      enable = true;
      useEmbeddedBitmaps = true;
      # the user's choice comes from `theme font`; these are root's and the greeter's
      defaultFonts = {
        sansSerif = [ fonts.default.ui ];
        serif = [ fonts.default.serif ];
        monospace = [ fonts.default.mono ];
        emoji = [ fonts.default.emoji ];
      };
    };
    fonts.packages =
      fonts.packages
      ++ icons.packages
      ++ (with pkgs; [
        meslo-lgs-nf
        montserrat
        symbola # fallback for symbols no other font has (Emacs)
      ]);
  };
}
