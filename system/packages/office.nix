{
  config,
  lib,
  pkgs,
  dotlib,
  unstable,
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
        (mermaid-cli.override { inherit (unstable) chromium; }) # diagrams from text, on the browser's chromium
        haskellPackages.commonmark-cli # markdown formatter
      ]
    );
  };
}
