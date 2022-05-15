# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, ... }:
let
  unfree = (import ../../nixpkgs/unfree.nix);
in {

  # Enable touchpad support (enabled default in most desktopManager).
  services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${config.user.name} = {
    extraGroups = [ 
      "audio"
      "bluetooth"
      "wheel"
      "networkmanager"
      "docker"
      "podman"
      "qemu-libvirtd"
      "libvirtd"
      "vboxusers"
    ];
  };

  #nix.trustedUsers = ["@wheel" "zbioe"];
  #nix.package = pkgs.nixFlakes;
  #nix.extraOptions = "experimental-features = nix-command flakes";
  #nix = {
  #  binaryCaches = [
  #    "https://cache.nixos.org"
  #    "https://cache.ngi0.nixos.org"
  #    "https://nix-community.cachix.org"
  #    "https://bornlogic.cachix.org/" 
  #  ];
  #  binaryCachePublicKeys = [
  #    "cache.ngi0.nixos.org-1:KqH5CBLNSyX184S9BKZJo1LxrxJ9ltnY2uAs5c/f1MA="
  #    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  #    "bornlogic.cachix.org-1:WrP3tyzc07oHOzAD0VvsUEvbxHpwn+dAEoY8ECgW7kc="
  #  ];
  #};

  ## virtualization
  #virtualisation.kvmgt.enable = true;
  #virtualisation.libvirtd.enable = true;
  ##virtualisation.virtualbox.host.enable = true;
  ##virtualisation.virtualbox.host.enableExtensionPack = true;

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
  ];


  # nixpkgs changes
  nixpkgs.overlays = [
    (self: super: {
      neovim = super.neovim.override {
        viAlias = true;
        vimAlias = true;
      };
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

  #nixpkgs.config.packageOverrides = pkgs: {
  #  vaapiintel = pkgs.vaapiintel.override { enablehybridcodec = true; };
  #  steam = pkgs.steam.override {
  #    extraPkgs = pkgs: with pkgs; [
  #      libgdiplus
  #    ];
  #  };
  # };

  #'boot.blacklistedKernelModules = ["nouveau"];
  #services.xserver.videoDrivers = [ "nvidia" ];  
#  systemd.services.nvidia-control-devices = {
#	  wantedBy = [ "multi-user.target" ];
#	  serviceConfig.ExecStart = "${pkgs.linuxPackages.nvidia_x11}/bin/nvidia-smi";
#  };
 
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    emacs # editor for all
    cachix # custom cache
    twurl # twitter cli oauth
    webcamoid # web cam tool
    #emacs-with-pkgs # mainly editor
    # telegram # chat
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
    python # python programming lang
    delta # git viewer
    strace # system call tracer
    kubernetes # kubernetes
    vagrant # local virt
    virt-manager # view virtualizations
    slack # chat
    lens # kubernetes interfac
    openssl # openssl tooling
    openvpn # vpn
    protonvpn-cli # protonvpn command line
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
    vulkan-tools # vulkan requirements
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
  };

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) unfree;
  # nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  #   "nvidia-settings"
  #   "nvidia-x11"
  #   "Oracle_VM_VirtualBox_Extension_Pack"
  #   "slack"
  #   "steam"
  #   "steam-original"
  #   "steam-runtime"
  # ];
  nixpkgs.config.permittedInsecurePackages = [
    "xen-4.10.4"
  ];

  # Steam
  #'programs.steam.enable = true;

  # Home-Manager
   home-manager.users.${config.user.name} = { config, pkgs, lib, ... }: {
     nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) unfree;
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
      home.sessionPath = [ "${config.home.homeDirectory}/.doom-emacs/bin" ];
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
          shellAbbrs = {
            "hc" = "herbstclient";
          };
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
        chromium = {
          enable = true;
        };
        #emacs = {
        #  enable = true;
        #  package = emacs-with-pkgs;
        #};
        starship = {
          enable = true;
          enableBashIntegration = true;
          enableFishIntegration = true;
        };
        direnv.enable = true;
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
       lorri.enable = true;
       dropbox.enable = true;
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
  '';

  boot.extraModprobeConfig = ''
    options snd-hda-intel model=alc269-dmic 
    options kvm_intel nested=1
  '';

  # security.pki.certificateFiles = [
  #   /etc/ssl/consul/test/ca.crt
  # ];



  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.05"; # Did you read the comment?

}

