{
  pkgs,
  nvf,
  quickshell,
  home-manager,
  ...
}:

{

  environment.systemPackages = with pkgs; [
    # home manager
    home-manager
    # shell toolkit
    quickshell
    # custom neovim
    nvf

    # nix debuger
    nixd
    nixfmt-rfc-style

    # browser
    librewolf-wayland
    chromium

    # disk utility
    gnome-disk-utility

    # color picker
    hyprpicker

    # dev
    python313
    vim
    git

    # desktop apps
    github-desktop
    telegram-desktop

    # utilities
    wget # send a get request
    btop # monitor of resources
    mkpasswd # create password
  ];
}
