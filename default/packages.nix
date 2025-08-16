{
  pkgs,
  nvf,
  home-manager,
  ...
}:

{

  environment.systemPackages = with pkgs; [
    # home manager
    home-manager

    # custom neovim
    nvf

    # nix utilities
    nixd # debuger
    nixfmt-rfc-style # formatter

    # browser
    librewolf-wayland # firefox like
    brave # chromium like
    tor-browser # firefox like using tor network

    # disk utilities
    gnome-disk-utility # to see partitions visually
    ntfs3g # support to ntfs

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
    libossp_uuid # generate uuid

    # file manager
    nautilus

    # icon theme
    adwaita-icon-theme
    gnomeExtensions.appindicator
  ];
}
