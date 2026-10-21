{ pkgs, ... }:
{
  i18n.defaultLocale = "pt_BR.UTF-8";
  time.timeZone = "America/Sao_Paulo";

  environment.sessionVariables = {
    LC_CTYPE = "pt_BR.UTF-8";
    XLOCALEDIR = "${pkgs.libx11}/share/X11/locale";
    XCOMPOSEFILE = "${pkgs.libx11}/share/X11/locale/pt_BR.UTF-8/Compose";
  };
}
