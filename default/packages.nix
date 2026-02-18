{
  pkgs,
  unstable,
  home-manager,
  ...
}:

{

  environment.systemPackages =
    with pkgs;
    let
      terraformWithPlugins = unstable.terraform.withPlugins (p: [
        p.dmacvicar_libvirt
        p.hashicorp_azurerm
        p.hashicorp_local
        p.vancluever_acme
        p.hashicorp_aws
        p.nbering_ansible
      ]);
    in
    [
      # home manager
      home-manager

      # nix utilities
      nixd # debuger
      nixfmt-rfc-style # formatter
      cachix # nix cache repository
      fwupd # bios update

      # browser
      librewolf # firefox like
      brave # chromium like
      tor-browser # firefox like using tor network
      alacritty # alternative terminal

      # disk utilities
      gnome-disk-utility # to see partitions visually
      ntfs3g # support to ntfs

      # display utilities
      wdisplays # arandr like to wayland

      # color picker
      hyprpicker

      # dev
      unstable.elixir
      python313
      python313Packages.pip
      lua
      ruby
      gem
      php
      jdk
      julia
      vim
      git
      go
      argc
      trashy
      css-checker
      scss-lint
      svelte-check
      vue
      typst
      ghostscript
      tectonic
      tetex
      mermaid-cli

      # alternative editors
      zed-editor
      helix
      unstable.code-cursor

      # desktop apps
      github-desktop
      telegram-desktop
      discord

      # utilities
      wget # send a get request
      hurl # HTTP requests defined in a simple plain text format.
      jq # json query
      btop # monitor of resources
      bottom # btop alternative
      nvtopPackages.intel # GPUs processing monitoring intel
      nvtopPackages.nvidia # GPUs processing monitoring nvidia
      process-compose # TUI for running apps and processes
      nethogs # TUI for nettop
      broot # TUI file manager
      lstr # tree alternative
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
      kubelogin # tool to kubectl
      ansible # ansible cli
      lazydocker # tui to run rocker
      docker-compose # to test docker infra local
      oxker # lazydocker alternative
      eza # ls alternative
      fd # find ls alternative
      fzf # fuzzy finder
      ripgrep # live grep
      unzip # extract zip files
      gzip # zip manipulation
      gnumake # gnu make
      nodejs_20 # copilot requirement and some LSPs
      cargo # Rust support
      luajitPackages.luarocks # lua package manager
      gnutar # tar manipulation
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
      dig # dns lookup
      haskellPackages.commonmark-cli # markdown formatter
      ispell # spell checker

      terraformWithPlugins # terraform with used plugins
      ansible # config manager
      openssl # cripto lib

      # icon theme
      adwaita-icon-theme

      # game
      lutris

      # certbot
      certbot-full

      #wireguard
      wireguard-tools

      # mongo shell
      mongosh

      # IA agents
      gemini-cli
      claude-code

      # LSP
      nil # nix

      # image editor
      krita
      gimp
      inkscape
      potrace

      # screen recorder
      wf-recorder

      # music
      yt-dlp
      ffmpeg
      video-downloader
      media-downloader

      # audio
      vlc

      # bug bounty
      caido
      burpsuite
      zap

      # desktop apps
      unstable.proton-pass
    ];
}
