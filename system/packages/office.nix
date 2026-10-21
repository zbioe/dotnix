{
  config,
  lib,
  pkgs,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.packages.office;
in
{
  options.dotnix.packages.office = dotlib.mkPackages "documents";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = dotlib.packagesOf cfg (
      with pkgs;
      [
        onlyoffice-desktopeditors # office suite
        typst # typesetting
        tectonic # LaTeX engine
        tetex # LaTeX distribution
        ghostscript # PostScript and PDF
        poppler-utils # PDF utilities
        mermaid-cli # diagrams from text
        haskellPackages.commonmark-cli # markdown formatter
      ]
    );
  };
}
