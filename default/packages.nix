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
      ansible-language-server = writeShellScriptBin "ansible-language-server" ''
        exec ${nodejs_24}/bin/npx --yes @ansible/ansible-language-server@26.6.0 "$@"
      '';
    in
    [
      # home manager
      home-manager

      # nix utilities
      unstable.nixd # language server
      nixfmt # formatter
      statix # linter
      cachix # nix cache repository
      fwupd # bios update

      # browser
      # brave # chromium like
      unstable.tor-browser # firefox like using tor network
      alacritty # alternative terminal
      slack # slack chat

      # disk utilities
      gnome-disk-utility # to see partitions visually
      ntfs3g # support to ntfs
      parted # disk partitioning
      e2fsprogs # ext2/3/4 filesystem utilities
      (grub2.override { efiSupport = true; }) # grub utilities

      # display utilities
      wdisplays # arandr like to wayland
      wlr-randr
      simplescreenrecorder # screen recorder

      # color picker
      hyprpicker

      # dev
      unstable.beamPackages.elixir
      python3
      python3Packages.pip
      uv
      lua
      ruby
      gem
      php
      jdk
      julia
      vim
      git
      go
      gopls
      golangci-lint
      ansible-lint
      kind

      # language servers, linters and formatters (doom emacs lsp)
      gotools # goimports
      gofumpt # stricter gofmt
      gomodifytags # struct tags
      gotests # test generation
      gore # go repl
      delve # go debugger
      dockerfile-language-server # docker-langserver
      hadolint # dockerfile linter
      terraform-ls # terraform
      tflint # terraform linter
      ansible-language-server # ansible
      yaml-language-server # yaml, compose, k8s
      bash-language-server # sh/bash
      shellcheck # used by bash-language-server
      shfmt # sh formatter
      vscode-langservers-extracted # json, html, css
      basedpyright # python
      ruff # python linter/formatter
      unstable.elixir-ls # elixir
      erlang-language-platform # erlang (ELP)
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
      helix

      # desktop apps
      github-desktop
      telegram-desktop
      # Vencord: themes (the active dotnix theme, see home/theme)
      (discord.override { withVencord = true; })

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
      lsix # ls image viewer
      chafa # imave viewer
      mkpasswd # create password
      libossp_uuid # generate uuid
      go-2fa # simple 2fa auth
      nomad # nomad cli tool
      nautilus # file manager
      geeqie # image viewer
      pavucontrol # sound control
      busybox # cli utilities
      azure-cli # cli to access azure cloud
      awscli2 # cli to access AWS
      oci-cli # oracle cloud cli
      google-cloud-sdk # google cloud cli
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
      nodejs_24 # copilot requirement and some LSPs
      cargo # Rust support
      luajitPackages.luarocks # lua package manager
      gnutar # tar manipulation
      lazygit # TUI for git commands
      dblab # TUI for SQL dbs like PostgreSQL, MySQL, SQLite3, Oracle and SQL Server
      lazysql # alternative to dblab in Go
      rainfrog # alternative to dblab in Rust
      posting # TUI for exploring API (postman like)
      unstable.discordo # TUI to discord
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
      gh # github cli
      hut # sourcehut cli
      terraformWithPlugins # terraform with used plugins
      ansible # config manager
      openssl # cripto lib
      pass # pass manager
      gnupg # GNU Privacy Guard - gpg

      # icon theme
      adwaita-icon-theme

      # office
      onlyoffice-desktopeditors

      # game
      lutris

      # certbot
      certbot-full

      #wireguard
      wireguard-tools

      # mongo shell
      mongosh

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
      caido-desktop
      burpsuite
      zap

      # desktop apps
      unstable.proton-pass

      # container app
      distrobox

      # sync folder
      mutagen

      # K8s environment
      kubernetes-helm
      cilium-cli
      sshuttle
      poppler-utils

      # challenges
      exercism
      leetcode-cli
    ];
}
