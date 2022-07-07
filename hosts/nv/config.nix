{ config, pkgs, lib, ... }:
let
  unfree = (import ../../nixpkgs/unfree.nix);
  elmPkgs = with pkgs.elmPackages; [
    elm
    elm-analyse
    elm-doc-preview
    elm-format
    elm-live
    elm-test
    elm-upgrade
    elm-xref
    elm-language-server
    elm-verify-examples
    elmi-to-json
  ];
in {
  environment.pathsToLink = [ "/share/nix-direnv" ];

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${config.user.name} = {
    extraGroups = [
      "input"
      "kvm"
      "dbus"
      "polkituser"
      "nixbld"
      "rtkit"
      "users"
      "floppy"
      "messagebus"
      "audio"
      "bluetooth"
      "wheel"
      "networkmanager"
      "docker"
      "podman"
      "qemu-libvirtd"
      "libvirtd"
      "vboxusers"
      "adbusers"
    ];
  };

  nix = {
    package = pkgs.nixFlakes;
    extraOptions = lib.optionalString (config.nix.package == pkgs.nixFlakes)
      "experimental-features = nix-command flakes";
  };

  # docker env
  virtualisation.docker.enable = false;
  virtualisation.podman.enable = true;
  virtualisation.podman.dockerSocket.enable = true;
  virtualisation.podman.defaultNetwork.dnsname.enable = true;

  programs.dconf.enable = true;

  programs.adb.enable = true;

  services.qemuGuest.enable = true;

  # fonts
  fonts.fonts = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    symbola
  ];
  fonts.fontconfig.enable = true;

  # nixpkgs changes
  nixpkgs.overlays = [
    (self: super: {
      neovim = super.neovim.override {
        viAlias = true;
        vimAlias = true;
      };
    })
    (self: super: {
      nix-direnv = super.nix-direnv.override { enableFlakes = true; };
    })
    (self: super: {
      emacsWithConfig =
        ((super.emacsPackagesFor super.emacsNativeComp).emacsWithPackages
          (epkgs:
            (with epkgs.melpaPackages; [ vterm pdf-tools org-pdftools ])));
    })

    (self: super: {
      pythonWithConfig = super.python39.withPackages (ppkgs:
        (with ppkgs; [
          ipython
          python-lsp-server
          black
          pyflakes
          isort
          nose
          pytest
          setuptools
          protonvpn-nm-lib
          pip
        ]));
    })

    #(self: super: {
    #  emacs = (super.emacs.override {
    #    nativeComp = true;
    #  }).overrideAttrs (old : {
    #    pname = "emacs";
    #    version = "head";
    #    src = super.fetchFromGitHub {
    #      owner = "emacs-mirror";
    #      repo = "emacs";
    #      rev = "99ba8c03c8fac65c2497265c54e1bea49f7c6dd3";
    #      sha256 = "00vxb83571r39r0dbzkr9agjfmqs929lhq9rwf8akvqghc412apf";
    #    };
    #    patches = [];
    #    configureFlags = old.configureFlags ++ ["--with-json"];
    #    preConfigure = "./autogen.sh";
    #    buildInputs = with super.pkgs; old.buildInputs ++ [ autoconf texinfo ];
    #  });
    #})
  ];

  nixpkgs.config.allowBroken = true;

  environment.systemPackages = with pkgs;
  # elm packages
    elmPkgs ++ [
      # emacsWithConfig # editor for all
      # emacs tools
      shfmt
      nixfmt
      nixpkgs-fmt
      terraform
      sqlite
      xclip
      graphviz
      gnuplot
      fd
      shellcheck
      # dics
      (aspellWithDicts (ds: with ds; [ en en-computers en-science pt_BR ]))
      # python
      pythonWithConfig
      pipenv
      # golang
      gomodifytags
      gotests
      gore
      gotools
      gopls # go lsp server
      godef # go def
      # solidity
      solc
      # haskell
      unstable.haskell-language-server
      unstable.haskellPackages.zlib
      unstable.pkgconfig
      unstable.stack

      # rust
      # rustc
      # cargo
      rust-analyzer
      rustup
      # markdown
      multimarkdown
      # web
      html-tidy
      nodePackages.stylelint
      python39Packages.jsbeautifier
      # node
      nodejs-16_x
      node2nix

      # sec
      bitwarden
      bitwarden-cli
      protonmail-bridge # protonmail bridge client
      protonvpn-cli # protonvpn command line
      dbus

      # pdf
      poppler
      poppler_utils

      # study
      exercism

      # others

      libtool
      cachix # custom cache
      twurl # twitter cli oauth
      webcamoid # web cam tool
      #emacs-with-pkgs # mainly editor
      # telegram # chat
      asciinema # record term
      neovim # alternative editor
      kubernetes-helm # Helm
      go-2fa # 2fa auth wallet
      unzip # extraction utility
      wget # requests from cli
      alacritty # terminal emulator
      nitrogen # set wallpaper
      google-cloud-sdk # gcloud
      arandr # xrandr gui config
      dmenu # application execution
      dzen2 # X notification utility
      tmux # terminal multiplexer
      xsel # copy to X
      jq # shell JSON parser
      git # version control tool
      cmake # make file
      go # go programming lang
      delta # git viewer
      strace # system call tracer
      kubernetes # kubernetes
      vagrant # local virt
      virt-manager # view virtualizations
      slack # chat
      lens # kubernetes interfac
      openssl # openssl tooling
      openvpn # vpn
      azure-cli # azure communication by command line
      cachix # cachix
      # linkerd_stable # service mesh
      pavucontrol # volume control
      pass # password manager
      flameshot # nice screenshoter
      scrot # print screen tool
      tridactyl-native # vim Firefox
      # eksctl # Amazon K8s Manager
      gnumake # make files
      awscli # Amazon cli
      docker-compose # docker compose containers
      arion # tool for build and run app that consist in multiple docker-containers
      docker-client # docker client
      light # light control
      brightnessctl # light control
      steam-run-native # steam start game
      gnome.adwaita-icon-theme # gnome themes
      lutris # game runner
      dunst # notification daemon
      libnotify # desktop send notifications
      vulkan-tools # vulkan requirements
      direnv
      nix-direnv
      nix-direnv-flakes
      chromedriver
      #dxvk
      #nvidia-offload
      # (steam.override { nativeOnly = true; }).run
      krb5Full # libgssapi_krb5.so.2
      #(steam.override { extraPkgs = pkgs: [ mono gtk3 gtk3-x11 libgdiplus zlib ];
      # nativeOnly = true; }).run
      #(steam.override { withPrimus = true; extraPkgs = pkgs: [ bumblebee glxinfo ];
      # nativeOnly = true; }).run
      #(steam.override { withJava = true; })
      (pkgs.writeShellScriptBin "nixFlakes" ''
        exec ${pkgs.nixUnstable}/bin/nix --experimental-features "nix-command flakes" "$@"
      '')
    ];

  # Environment Variables
  environment.variables = {
    TERMINAL = "alacritty";
    EDITOR = "nvim";
    VISUAL = "nvim";
    GOPATH = "$HOME/go";
    GOBIN = "$HOME/go/bin";
    GOROOT = pkgs.go.outPath;
    NODE_PATH = "$HOME/.node-packages/lib/node_modules";
  };

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) unfree;
  # nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #   "nvidia-settings"
  #   "nvidia-x11"
  #   "Oracle_VM_VirtualBox_Extension_Pack"
  #   "slack"
  #   "steam"
  #   "steam-original"
  #   "steam-runtime"
  # ];
  nixpkgs.config.permittedInsecurePackages = [ "xen-4.10.4" ];

  # Steam
  #'programs.steam.enable = true;

  # Home-Manager
  home-manager.users.${config.user.name} = { config, pkgs, lib, ... }: {
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) unfree;
    nixpkgs.config = {
      pulseaudio = true;
      firefox = {
        enableTridactylNative = true;
        # enableGoogleTalkPlugin = true;
        # enableAdobeFlash = true;
      };
      chromium = {
        # enablePepperFlash = true;
        # enablePepperPDF = true;
      };
    };
    home.sessionPath = [
      "${config.home.homeDirectory}/.emacs.d/bin"
      "${config.home.homeDirectory}/go/bin"
      "${config.home.homeDirectory}/.local/bin"
      "${config.home.homeDirectory}/.npm-packages/bin"
    ];
    home.packages = with pkgs; [
      spotify
      discord
      audio-recorder
      element-desktop

      krita
      # Emacs
      ripgrep
      coreutils
      clang
      texlive.combined.scheme-full
      zotero
    ];
    programs = {
      autojump = {
        enable = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
      };
      fish = {
        enable = true;
        shellAbbrs = { "hc" = "herbstclient"; };
        shellInit = ''
          set fish_greeting
          set extraConfig ~/.config/fish/extraConfig.fish
          [ -f $extraConfig ] && source $extraConfig
        '';
      };
      fzf = {
        enable = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
      };
      chromium = { enable = true; };
      emacs = {
        enable = true;
        # package = emacs-with-pkgs;
        extraPackages = epkgs: with epkgs; [ pdf-tools org-pdftools vterm ];
      };
      starship = {
        enable = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
      };
      # direnv.enable = true;
      neovim = {
        enable = true;
        # package = pkgs.neovim.overrideAttrs (old: {patches = (old.patches or []) ++ [ /home/zbioe/.config/nvim/undo.patch ];});
        plugins = with pkgs.vimPlugins; [
          # Syntax / Language Support
          vim-nix
          vim-go
          vim-fish
          vim-toml
          rust-vim
          vim-pandoc
          vim-pandoc-syntax

          # UI
          gruvbox
          vim-gitgutter
          vim-devicons
          vim-airline

          # Editor Features
          vim-abolish
          vim-surround
          vim-repeat
          vim-commentary
          nerdtree
          vim-indent-object
          vim-easy-align
          vim-eunuch
          vim-sneak
          supertab
          ale

          # Buffer / Pane / File Management
          fzf-vim

          # Panes / Larger features
          tagbar
          vim-fugitive
        ];
        extraConfig = builtins.readFile ./extraConfig.vim;
      };
      firefox = {
        enable = true;
        # extensions = with pkgs.nur.repos.rycee.firefox-addons; [
        #   ublock-origin
        #   browserpass
        #   tridactyl
        #   sidebery
        # ];
        #package = pkgs.firefox.override {
        #  cfg = { enableTridactylNative = true; };
        ##};
        #profiles = {
        #  ${config.user.name} = {
        #    isDefault = true;
        #    settings = {
        #      "browser.startup.homepage" = "https://google.com";
        #      "general.smoothScroll" = true;
        #    };
        #  };
        #};
      };
      browserpass = {
        enable = true;
        browsers = [ "firefox" ];
      };
    };
    services = {
      #emacs.enable = true;
      #emacs.package = emacs-with-pkgs;
      #emacs.client.enable = true;
      #emacs.client.arguments = [ "--no-wait" ];
      # dropbox.enable = true;
    };
    xsession.enable = true;
    #systemd.user.services.emacs = {

    #  Install = {
    #    WantedBy = [ "graphical-session.target" ];
    #  };

    #  Service = {
    #    ExecStop = "${emacs-with-pkgs}/bin/emacsclient --eval (kill-emacs)";
    #  };
    #};
  };

  environment.interactiveShellInit = ''
    alias hc='herbstclient'
    alias ec='emacsclient'
    alias pvc='protonvpn-cli'
    alias pmb='protonmail-bridge'
  '';

  boot.extraModprobeConfig = ''
    options snd-hda-intel model=alc269-dmic 
    options kvm_intel nested=1
  '';

  # security.pki.certificateFiles = [
  #   ../../ca/consul.crt
  # ];

}
