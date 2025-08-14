{
  pkgs,
  home-manager,
  nvf,
  ...
}:

{

  environment.systemPackages = with pkgs; [
    # custom neovim
    nvf

    # home-manager
    home-manager

    # nix debuger
    nixd
    nixfmt-rfc-style
  ];
}
