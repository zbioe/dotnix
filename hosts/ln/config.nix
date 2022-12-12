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
  variables = {
    TERMINAL = "alacritty";
    EDITOR = "emacsclient";
    ALTERNATE_EDITOR = "";
    VISUAL = "emacsclient -c";
    GOPATH = "$HOME/go";
    GOBIN = "$HOME/go/bin";
    GOROOT = "${pkgs.go.outPath}/share/go";
    NODE_PATH = "$HOME/.node-packages/lib/node_modules";
    # PIP_TARGET = "$HOME/.local/";
    GTK_IM_MODULE = "ibus";
    GTK_USE_PORTAL = "1";
  };
in {
  environment.pathsToLink = [ "/share/nix-direnv" ];

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;
  #boot.extraModulePackages = with config.boot.kernelPackages; [
  #  v4l2loopback.out
  #  rtl8812au.out
  #  akvcam.out
  #];
  #  boot.initrd.kernelModules = [ "8812au" ];
  boot.loader.grub.theme = pkgs.nixos-grub2-theme;

  boot.initrd.availableKernelModules = [ "thinkpad_acpi" ];
  hardware.cpu.intel.updateMicrocode = true;
  services.xserver.dpi = 152;
  services.fwupd.enable = true;
  hardware.enableAllFirmware = true;
  powerManagement.powertop.enable = true;
  services.fprintd.enable = true;
  # remove beep
  boot.blacklistedKernelModules = [ "snd_pcsp" ];
  # printing and scan
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.hplip pkgs.sane-backends ];
  hardware.sane.enable = true;
  hardware.sane.extraBackends = [ pkgs.hplipWithPlugin pkgs.sane-backends ];
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${config.user.name} = {
    extraGroups = [
      "scanner"
      "lp"
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
      "video"
      "disk"
      "vboxusers"
      "adbusers"
    ];
  };
  boot.kernelModules = [
    "kvm-intel" # "v4l2loopback" "snd-aloop"  "akvcam"
  ];
  # Set initial kernel module settings
  nix = {
    package = pkgs.nixStable;
    extraOptions = lib.optionalString (config.nix.package == pkgs.nixStable)
      "experimental-features = nix-command flakes";
  };
  # services.qemuGuest.enable = true;
  # docker env
  virtualisation.docker.enable = true; # podman relace docker
  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.qemu.runAsRoot = false;
  # virtualisation.podman.enable = true;
  # virtualisation.podman.dockerSocket.enable = true;
  # virtualisation.podman.defaultNetwork.dnsname.enable = true;

  programs.dconf.enable = true;

  hardware.enableRedistributableFirmware = true;

  networking.extraHosts = ''
    10.0.62.11 c1r1
    10.0.62.12 c1r2
    10.0.62.13 c1r3

    10.0.62.14 c2r1
    10.0.62.15 c2r2
    10.0.62.16 c2r3
  '';

  programs.adb.enable = true;

  # fonts
  fonts.fonts = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    nerdfonts
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

  # file namager Thunar extras
  services.gvfs.enable = true; # Mount, trash, and other functionalities
  # services.tumbler.enable = true; # Thumbnail support for images

  nixpkgs.config.allowBroken = true;

  environment.systemPackages = with pkgs;
  # elm packages
    elmPkgs ++ [
      gnome.simple-scan
      # ebook
      calibre
      # image
      imagemagick
      colorpicker
      inkscape
      # bar
      polybar
      killall
      # encryption
      age
      ssh-to-age
      gnupg
      ssh-to-pgp
      sops
      # video
      ffmpeg-full
      simplescreenrecorder
      # audio
      vlc
      # virtualiation
      libvirt
      # emacsWithConfig # editor for all
      # xtools
      # xcape
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
      wmctrl
      tectonic

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
      unstable.pkg-config
      unstable.stack
      k9s

      # rust
      # rustc
      # cargo
      rust-analyzer
      rustup
      trunk
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

      # top
      btop
      htop

      # rust tools alternative
      bottom # btm: top alternative
      bat # cat talternative
      broot # tree alternative
      choose # grep alternative
      delta # diff alternative
      du-dust # du alternative
      exa # ls alternative
      fd # find alternative
      felix # dir manager
      gitui # ui for git
      grex # find regex patterns
      htmlq # query in html jq like
      jql # jq alternative
      hyperfine # benchmark
      just # make alternative
      rm-improved # rip: rm improved with recovery in /tmp/graveyard-$USER
      xcp # cp with some optimizations
      tokei # code info
      ripgrep # rg: grep replacement

      # pdf
      poppler
      poppler_utils

      # study
      exercism

      # others
      cinnamon.nemo # file manager
      onlyoffice-bin # office
      libtool
      cachix # custom cache
      twurl # twitter cli oauth
      webcamoid # web cam tool
      #emacs-with-pkgs # mainly editor
      # telegram # chat
      asciinema # record term
      texmacs # alternative awesome editor
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
      # vagrant # local virt
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
      file
      #extra-shells
      xonsh
      elvish
      ion
      # win10 install iso
      # woeusb
      # woeusb-ng
      ntfs3g
      gparted

      # zoom meeting client
      zoom-us
      # notes
      logseq

      # image viewer
      geeqie

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
  environment.variables = variables;
  environment.sessionVariables = variables;

  nixpkgs.config.allowUnfree = true;
  # nixpkgs.config.allowUnfreePredicate = pkg:
  # builtins.elem (lib.getName pkg) unfree;
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
        enableAdobeFlash = true;
        # enableGoogleTalkPlugin = true;

      };
      chromium = {
        # enablePepperFlash = true;
        # enablePepperPDF = true;
      };
    };
    home.sessionPath = [
      "${config.home.homeDirectory}/bin"
      "${config.home.homeDirectory}/.emacs.d/bin"
      "${config.home.homeDirectory}/go/bin"
      "${config.home.homeDirectory}/.local/bin"
      "${config.home.homeDirectory}/.local/bin"
      "${config.home.homeDirectory}/.cargo/bin"
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
    gtk = {
      # font.name = "Victor Mono SemiBold 12";
      theme = {
        name = "Materia-Dark";
        package = pkgs.materia-theme;
      };
    };

    # start it in shell first
    # environment.shellInit = ''
    #   xcape -e "Control_L=Escape"
    # '';
    services = {
      xcape = {
        enable = true;
        mapExpression = {
          # CapsLock to ESC
          "#66" = "Escape";
        };
        timeout = 500;
      };
    };

    programs = {
      autojump = {
        enable = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
        enableZshIntegration = true;
      };
      bash = {
        enable = true;
        historySize = -1;
      };
      zsh = {
        enable = true;
        enableAutosuggestions = true;
        enableCompletion = true;
        enableSyntaxHighlighting = true;
        oh-my-zsh.enable = true;
        prezto.enable = true;
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
      nushell = {
        enable = true;
        settings = {
          key_timeout = 10;
          completion_mode = "circular";
          startup = [ "source ~/.cache/starship/init.nu" ];
        };
      };
      fzf = {
        enable = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
        enableZshIntegration = true;
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
        enableZshIntegration = true;
        settings = let inherit (lib.strings) concatStrings;
        in {
          add_newline = true;
          format = concatStrings [
            "$username"
            "$hostname"
            "$directory"
            "$git_branch"
            "$git_commit"
            "$git_metrics"
            "$git_status"
            "$nix_shell"
            "$shell"
            "$memory_usage"
            "$cmd_duration"
            "$line_break"
            "$jobs"
            "$battery"
            "$time"
            "$status"
            "$character"
          ];
          memory_usage = { disabled = false; };
          character = let char = "≻";
          in {
            success_symbol = "[${char}](bold cyan)";
            error_symbol = "[${char}](bold red)";
          };
          shell = {
            disabled = false;
            style = "bold bright-blue";
            format = "[λ](dimmed bold blue)[ $indicator]($style) ";
          };
          nix_shell = {
            disabled = false;
            impure_msg = "[nix](bold yellow)";
            pure_msg = "[nix](bold green)";
            format = "[❄ $state](bold blue) ";
          };
        };
      };
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
        # profiles = {
        #   default = {
        #     userChrome = builtins.readFile ./firefox/userChrome.css;
        #   };
        # };
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
    # options snd-hda-intel model=alc269-dmic
    options kvm_intel nested=1
    # options v4l2loopback exclusive_caps=1 card_label="Virtual Camera"
  '';

  # security.pki.certificateFiles = [
  #   ../../ca/consul.crt
  # ];
  #

}
