{
  pkgs,
  # nvf,
  home-manager,
  ...
}:

{

  environment.systemPackages =
    with pkgs;
    let
      terraformWithPlugins = terraform.withPlugins (p: [
        p.libvirt
        p.azurerm
        p.local
        p.acme
        p.aws
        p.ansible
      ]);
    in
    [
      # home manager
      home-manager

      # custom neovim
      # nvf

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
      bottom # btop alternative
      nvtopPackages.intel # GPUs processing monitoring intel
      nvtopPackages.nvidia # GPUs processing monitoring nvidia
      process-compose # TUI for running apps and processes
      junkie # nettop
      nethogs # TUI for nettop
      broot # TUI file manager
      mkpasswd # create password
      libossp_uuid # generate uuid
      cloudflared # tunnel to access
      go-2fa # simple 2fa auth
      nomad # nomad cli tool
      nautilus # file manager
      geeqie # image viewer
      pavucontrol # sound control
      busybox # cli utilities
      azure-cli # cli to access azure cloud
      kubectl # cli to access kubernetes
      ansible # ansible cli
      lazydocker # tui to run rocker
      oxker # lazydocker alternative
      eza # ls alternative
      fd # find ls alternative
      fzf # fuzzy finder
      ripgrep # live grep
      lazygit # TUI for git commands
      dblab # TUI for SQL dbs like PostgreSQL, MySQL, SQLite3, Oracle and SQL Server
      lazysql # alternative to dblab in Go
      rainfrog # alternative to dblab in Rust
      posting # TUI for exploring API (postman like)
      discordo # TUI to discord
      caligula # TUI for dd
      gdu # TUI for Disk analisys
      sc-im # TUI alternative to Excel
      nchat # TUI for whatsapp and telegram
      neovim # vim improved
      gcc # gnu compiler
      vi-mongo # mongo tui

      terraformWithPlugins # terraform with used plugins

      # icon theme
      adwaita-icon-theme

      # game
      lutris
    ];
}
