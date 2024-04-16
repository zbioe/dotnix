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
    STARDICT_DATA_DIR = "$HOME/dics";
    LIBVIRT_DEFAULT_URI = "qemu:///system";
  };
in {
  environment.pathsToLink = [ "/share/nix-direnv" ];

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;
  boot.kernelPackages = pkgs.linuxPackages_6_1;
  # boot.extraModulePackages = with config.boot.kernelPackages;
  #   [

  #   ];
  #  boot.initrd.kernelModules = [ "8812au" ];
  # boot.loader.grub.theme = pkgs.nixos-grub2-theme;
  # boot.loader.grub.splashImage = ./wallpaper.png;
  # remove watchdog
  # https://wiki.archlinux.org/title/Improving_performance#Watchdogs
  # https://dt.iki.fi/linux-disable-watchdog

  # remove beep (lenovo can remove it in bios)
  # boot.blacklistedKernelModules = [ "snd_pcsp" ];

  hardware.cpu.intel.updateMicrocode = true;
  services.xserver.dpi = 152;
  services.fwupd.enable = true;
  hardware.enableAllFirmware = true;
  powerManagement.powertop.enable = true;
  services.fprintd.enable = true;

  # printing and scan
  services.printing.enable = true;
  services.printing.drivers =
    [ pkgs.hplip pkgs.sane-backends pkgs.epson-escpr ];
  services.avahi.enable = true;
  services.avahi.nssmdns4 = true;

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
  virtualisation.libvirtd.extraConfig = ''
    uri_default = "qemu:///system"
  '';
  systemd.services.libvirt-guests = {
    environment = { URI = "qemu:///system"; };
  };
  # virtualisation.podman.enable = true;
  # virtualisation.podman.dockerSocket.enable = true;
  # virtualisation.podman.defaultNetwork.dnsname.enable = true;

  programs.dconf.enable = true;

  hardware.enableRedistributableFirmware = true;

  networking.extraHosts = ''

    10.0.62.11 c1r1 r1.mongodb.dev.bornlogic.com
    10.0.62.12 c1r2 r2.mongodb.dev.bornlogic.com
    10.0.62.13 c1r3 r3.mongodb.dev.bornlogic.com

    10.0.62.14 c2r1
    10.0.62.15 c2r2
    10.0.62.16 c2r3
  '';

  programs.adb.enable = true;

  services.locate = {
    enable = true;
    # interval = "hourly";
    package = pkgs.plocate;
    localuser = null;
  };

  # fonts

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
      pythonWithConfig = super.python311.withPackages (ppkgs:
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

  programs.slock.enable = true;

  nixpkgs.config.allowBroken = true;
  environment.systemPackages = with pkgs;
  # elm packages
    elmPkgs ++ [
      # gtk
      gtk3
      # WM
      eww
      i3lock
      # password generator
      pwgen
      # rofi
      rofi
      rofi-rbw
      # scan
      gnome.simple-scan
      # ebook
      zathura
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
      youtube-dl
      yt-dlp
      tartube-yt-dlp
      tartube

      # audio
      vlc

      # virtualiation
      libvirt
      # torrent
      rqbit
      qbittorrent
      # emacsWithConfig # editor for all
      # xtools
      # xcape
      # emacs tools
      shfmt
      nixfmt-rfc-style
      nixpkgs-fmt
      # terraform # removed for use it in devShell.nix
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
      (hunspellWithDicts (with pkgs.hunspellDicts; [ en_US-large ]))
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
      unstable.stack
      k9s

      # dart
      dart
      flutter

      pkg-config
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
      nodejs
      node2nix

      # sec
      bitwarden
      bitwarden-cli
      protonmail-bridge # protonmail bridge client
      protonvpn-cli # protonvpn command line
      protonvpn-gui # protonvpn gui interface
      dbus

      # top
      btop
      htop

      # elixir
      elixir_1_14

      # rust tools alternative
      bottom # btm: top alternative
      bat # cat talternative
      broot # tree alternative
      choose # grep alternative
      delta # diff alternative
      du-dust # du alternative
      eza # ls alternative
      fd # find alternative
      felix # dir manager
      gitui # ui for git
      grex # find regex patterns
      htmlq # query in html jq like
      jql # jq alternative
      hyperfine # benchmark
      # just # make alternative
      rm-improved # rip: rm improved with recovery in /tmp/graveyard-$USER
      xcp # cp with some optimizations
      tokei # code info
      ripgrep # rg: grep replacement

      # pdf
      poppler
      poppler_utils

      # study
      exercism

      # desktop tools
      tdesktop

      # others
      cinnamon.nemo # file manager
      onlyoffice-bin # office
      libtool
      cachix # custom cache
      twurl # twitter cli oauth
      webcamoid # web cam tool
      #emacs-with-pkgs # mainly editor
      # telegram # chat
      languagetool # grammar checker
      sdcv # dictionary
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
      gh # github cli
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
      openssl.dev # libssl
      openvpn # vpn
      azure-cli # azure communication by command line
      cachix # cachix
      # linkerd_stable # service mesh
      pavucontrol # volume control
      (pass.withExtensions (ext:
        with ext; [
          pass-otp
          pass-import
          pass-update
          pass-genphrase
          pass-audit
          pass-checkup
        ]))
      pass
      flameshot # nice screenshoter
      scrot # print screen tool
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
      # direnv
      # nix-direnv
      # nix-direnv-flakes
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

      # image manipulation
      gimp
      # meeting
      teams

      # games
      flatpak
      playonlinux

      # audacity
      audacity

      # sec
      gobuster

      # stream
      stremio
      # hardware
      dmidecode
      geteltorito
      # mount files android by bluetooth or usb
      jmtpfs
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

      # google manager
      gam

      # multipass - vm manager
      multipass
    ];

  # Environment Variables
  environment.variables = variables;
  environment.sessionVariables = variables;

  services.flatpak.enable = true;

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
  programs.steam.enable = true;

  # Bluetooth
  hardware.pulseaudio = {
    extraConfig = ''
      load-module module-switch-on-connect
    '';
  };
  hardware.bluetooth = {
    # disable SIM Access Profile
    disabledPlugins = [ "sap" ];
    # enable microphone
    # hsphfpd.enable = true;
    settings = {
      General = {
        Enable = "Sink,Media,Socket";
        Experimental = true;
      };
    };
  };
  xdg.mime.defaultApplications = {
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
    "x-scheme-handler/mailto" = "thunderbird.desktop";
    "text/html" = "firefox.desktop";
    "application/x-extension-htm" = "firefox.desktop";
    "application/x-extension-html" = "firefox.desktop";
    "application/x-extension-shtml" = "firefox.desktop";
    "application/xhtml+xml" = "firefox.desktop";
    "application/x-extension-xhtml" = "firefox.desktop";
    "application/x-extension-xht" = "firefox.desktop";
  };

  # Home-Manager
  home-manager.users.${config.user.name} = let
    cfg_super = config;
    pkgs_super = pkgs;
    firefox_extensions = with pkgs.nur.repos.rycee.firefox-addons; [
      vimium
      bitwarden
      ublock-origin
      privacy-badger
    ];
  in { config, pkgs, lib, ... }: {
    nixpkgs.config.allowUnfreePredicate = pkg:
      builtins.elem (lib.getName pkg) unfree;
    nixpkgs.config = {
      pulseaudio = true;
      firefox = {
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
    programs.firefox = {
      enable = true;
      profiles = {
        "${cfg_super.user.name}" = {
          id = 0;
          isDefault = true;
          extensions = firefox_extensions;
          settings = {
            # auto enable extensions
            "extensions.autoDisableScopes" = 0;
            "extensions.enabledScopes" = 15;
          };
          userChrome = builtins.readFile ./firefox/userChrome.css;
          bookmarks = import ./firefox/bookmarks.nix;
          search = {
            default = "Google";
            engines = import ./firefox/searchEngines.nix { inherit pkgs; };
            force = true;
          };
        };
        "safe" = {
          id = 1;
          isDefault = false;
          settings = {
            # auto enable extensions
            "extensions.autoDisableScopes" = 0;
            "extensions.enabledScopes" = 15;
          } // import ./firefox/settings.nix;
          userChrome = builtins.readFile ./firefox/userChrome.css;
          bookmarks = import ./firefox/bookmarks.nix;
          search = {
            default = "Google";
            engines = import ./firefox/searchEngines.nix { inherit pkgs; };
            force = true;
          };
        };
        clean = {
          isDefault = false;
          id = 2;
        };
      };
    };
    xdg.configFile."tridactyl/tridactylrc".source = ./firefox/tridactylrc;

    # Bluetooth
    systemd.user.services.mpris-proxy = {
      Unit.Description = "Mpris proxy";
      Unit.After = [ "network.target" "sound.target" ];
      Service.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
      Install.WantedBy = [ "default.target" ];
    };
    home.file.".icons/default".source =
      "${pkgs.vanilla-dmz}/share/icons/Vanilla-DMZ";
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
      enable = true;
      font.name = "Vegur 12";
      theme = {
        name = "gruvbox-dark";
        package = pkgs.gruvbox-dark-gtk;
      };
      iconTheme = {
        name = "oomox-gruvbox-dark";
        package = pkgs.gruvbox-dark-icons-gtk;
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
        timeout = 800;
      };
    };

    programs = {
      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
      autojump = {
        enable = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
        enableZshIntegration = true;
        # enableNushellIntegration = true;
      };
      bash = {
        enable = true;
        historySize = -1;
      };
      zsh = {
        enable = true;
        autosuggestion.enable = true;
        enableCompletion = true;
        syntaxHighlighting.enable = true;
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
        extraConfig = "source ~/.cache/starship/init.nu";
      };
      fzf = {
        enable = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
        enableZshIntegration = true;
        # enableNushellIntegration = true;
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
        enableNushellIntegration = true;
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
      browserpass = {
        enable = true;
        browsers = [ "firefox" ];
      };
      rofi = {
        enable = true;
        package = pkgs.rofi;
        extraConfig = {
          modi =
            "drun,emoji,ssh,keys,filebrowser,file-browser-extended,combi,run,window,windowcd";
          kb-primary-paste = "Control+V,Shift+Insert";
          kb-secondary-paste = "Control+v,Insert";
          show-icons = true;
          icon-theme = "Gruvbox-Material-Dark";
          display-ssh = " ssh:";
          display-run = " run:";
          display-drun = " drun:";
          display-window = " window:";
          display-combi = " combi:";
          display-filebrowser = " filebrowser:";
        };
        plugins = [
          pkgs.rofi-emoji
          pkgs.rofi-pulse-select
          pkgs.rofi-vpn
          pkgs.rofi-file-browser
          pkgs.rofi-rbw
        ];
        font = "Noto Sans Mono 14";
        # theme = "gruvbox-dark";
        # https://github.com/hiimsergey/rofi-gruvbox-material
        theme = ./rofi-theme.rasi;
        terminal = "alacritty";
        # pass = { enable = true; };
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
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk
    noto-fonts-emoji
    nerdfonts
    symbola
    vegur
    # silent boot
    meslo-lgs-nf
  ];
  fonts.fontconfig.enable = true;

  # Silent Boot
  console = {
    font = "ter-v32n";
    earlySetup = false;
    useXkbConfig = true;
    packages = with pkgs; [ terminus_font ];
  };
  # TTY
  services.kmscon = {
    enable = true;
    hwRender = true;
    extraConfig = ''
      font-name=MesloLGS NF
      font-size=14
    '';
  };
  boot = {
    # Plymouth
    consoleLogLevel = 0;
    initrd.verbose = false;
    initrd.availableKernelModules = [ "thinkpad_acpi" ];
    plymouth = {
      enable = true;
      # theme = "breeze";
    };
    # initrd.kernelModules = [ "shutdown" ];
    kernelParams = [
      "nowatchdog"
      "quiet"
      "splash"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_level=3"
      "udev.log_priority=3"
      "boot.shell_on_fail"
    ];
    blacklistedKernelModules = [ "iTCO_wdt" ];
    # Boot Loader
    loader = {
      grub = {
        darkmatter-theme = {
          enable = true;
          style = "nixos";
          icon = "color";
          resolution = "1080p";
        };
      };
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/boot";
      systemd-boot.enable = true;
      timeout = 0;
    };
  };

  # auto login
  services.displayManager.autoLogin = {
    enable = true;
    user = "${config.user.name}";
  };

  # teamviewer
  services.teamviewer.enable = true;

}
