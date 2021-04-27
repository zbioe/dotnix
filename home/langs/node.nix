{ config, lib, pkgs, ... }:

let npmPath = "${config.home.homeDirectory}/.npm_global";
in {
  home.packages = with pkgs; [ nodejs ];
  home.sessionPath = [ npmPath ];
}
