{
  lib,
  pkgs,
  nixpkgs,
  unstable,
  home-module,
  ...
}:
{
  imports = [
    ./ui.nix
    ./tmux.nix
    ./config.nix
    ./packages.nix
    ./librewolf.nix
    ./brave.nix
    ./updates.nix
    ./webcam.nix
    # ./web3.nix
    ./libvirt.nix
    ./waydroid.nix
    ./flatpak.nix
    ./ai.nix
    ./crypto.nix
    ./cloudflare.nix
    ./mail.nix
    ./pass.nix
  ];

  hardware.enableAllFirmware = true;
  nixpkgs.config = {
    allowUnfree = true;
  };

  nix = {
    nixPath = [
      "nixpkgs=${pkgs.path}"
      "unstable=${unstable.path}"
      "home-manager=${home-module}"
    ];
    registry = {
      nixpkgs.flake = nixpkgs;
    };
    settings = {
      # Manual optimise storage: nix-store --optimise
      # https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-auto-optimise-store
      auto-optimise-store = true;
      builders-use-substitutes = true;
    };
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
      tarball-ttl = 900
    '';
  };

  # `nh os switch` / `nh home switch`: rebuild with a package diff (nvd);
  # its clean replaces nix.gc and also drops old home-manager generations
  programs.nh = {
    enable = true;
    flake = "/home/zbioe/dotnix";
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep-since 10d --keep 5";
    };
  };
  # /boot is 1G and each initrd carries every plymouth theme (~75M)
  boot.loader.grub.configurationLimit = 5;

  # compressed swap in RAM first (the disk swap stays as overflow), and
  # kill the biggest offender before the desktop freezes
  zramSwap.enable = true;
  services.earlyoom = {
    enable = true;
    enableNotifications = true;
  };

  networking.resolvconf.extraOptions = [
    "rotate"
    "timeout:1"
    "attempts:2"
  ];
  networking.networkmanager = {
    enable = true;
    wifi.powersave = false;
    dns = "none";
  };
  networking.firewall.enable = true;
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
    "2606:4700:4700::1111"
    "2606:4700:4700::1001"
  ];

  services.fstrim.enable = true;

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  programs.command-not-found.enable = true;

  programs.dconf.enable = true;

  services = {
    udev = {
      enable = true;
      packages = with pkgs; [ gnome-settings-daemon ];
      extraRules = ''
        # RK61 Bluetooth
        ACTION=="add", KERNEL=="event*", SUBSYSTEM=="input", ATTRS{name}=="RK61RGB 5.0 Keyboard", SYMLINK+="input/rk61_bt", TAG+="systemd", ENV{SYSTEMD_WANTS}+="kanata-external.service"
      '';
    };

    #
    dbus = {
      enable = true;
      packages = with pkgs; [ gnome2.GConf ];
    };
    # auto mount/unmount a drive
    gvfs.enable = true;
    udisks2.enable = true;

    # Thumbnail support for images
    tumbler.enable = true;

  };
  security = {
    pki.certificateFiles = [
      ../certs/dev-root-ca.pem
    ];
  };

  # Docker defaults
  virtualisation.docker = {
    enable = true;
    package = unstable.docker;
    daemon.settings = {
      dns = [
        "1.1.1.1"
        "8.8.8.8"
      ];
      storage-driver = "btrfs";
    };
  };

  # search engine
  #
  services.whoogle-search = {
    enable = true;
    port = 8821;
    extraEnv = {
      WHOOGLE_CONFIG_THEME = "dark";
      WHOOGLE_CONFIG_LANGUAGE = "pt-br";
      WHOOGLE_CONFIG_SEARCH_LANGUAGE = "pt-br";
      WHOOGLE_CONFIG_COUNTRY = "BR";
    };
  };
  services.searx = {
    enable = true;
    package = pkgs.searxng;
    settings = {
      server = {
        port = 8822;
        bind_address = "127.0.0.1";
        secret_key = "ihae3ael8iequeiZaipahyahzeewohdo";
      };

      search = {
        safe_search = 0;
        autocomplete = "duckduckgo";
        default_lang = "pt-BR";
      };

      ui = {
        theme = "simple";
        default_locale = "pt-BR";
      };

      engines = pkgs.lib.mkForce [
        # O Startpage is the google
        {
          name = "startpage";
          engine = "startpage";
          shortcut = "s";
          weight = 3;
        }
        {
          name = "duckduckgo";
          engine = "duckduckgo";
          shortcut = "d";
          weight = 2;
        }
        {
          name = "brave";
          engine = "brave";
          shortcut = "b";
          weight = 1;
        }
        {
          name = "bing";
          engine = "bing";
          shortcut = "bi";
          weight = 1;
        }

        # built-in, stable dev engines
        {
          name = "github";
          engine = "github";
          shortcut = "gh";
        }
        {
          name = "stackoverflow";
          engine = "stackexchange";
          shortcut = "st";
        }
        {
          name = "nixos wiki";
          engine = "mediawiki";
          base_url = "https://nixos.wiki/";
          shortcut = "nw";
        }
      ];
    };
  };
  systemd.tmpfiles.rules = [
    # grant permission to main user read the system logs
    "a+ /var/log/boot.log - - - - u:1000:r"
    "a+ /var/log/auth.log - - - - u:1000:r"
    "a+ /var/log/syslog   - - - - u:1000:r"
    "w /sys/class/leds/platform::micmute/brightness - - - - 0"
  ];

  # Ensure environment
  environment = {
    etc = {
      "nix/inputs/nixpkgs".source = nixpkgs;
      # keet io configurable from OS
      hosts.enable = false;
    };
    variables = {
      EDITOR = "nvim";
    };
  };

  # fix brave policy block
  programs.chromium.extraOpts = lib.mkForce { };

  programs.localsend.enable = true;

}
