{ pkgs, nvf, ... }:

{

  environment.systemPackages = with pkgs; [
    # custom neovim
    nvf

    # nix debuger
    nixd
    nixfmt-rfc-style
  ];
}
