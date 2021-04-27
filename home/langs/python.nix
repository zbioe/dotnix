{ config, lib, pkgs, ... }:
let
  localBin = "${config.home.homeDirectory}/.local/bin/";
  pythonPkgs = with pkgs.python39Packages; [
    jedi # autocompletion tool for Python
    ipython # interpreter
    conda
    black
    pyflakes
    isort
    nose
    pytest
    poetry
    setuptools
    ipython
    pip
  ];
in {
  home.packages = with pkgs;
    [
      python39
      pipenv # workflow development
    ] ++ pythonPkgs;
  home.sessionPath = [ localBin ];
}
