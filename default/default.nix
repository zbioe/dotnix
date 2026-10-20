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

  networking.networkmanager = {
    enable = true;
    wifi.powersave = false;
    # the network's (DHCP) DNS is never used, only the one below
    dns = lib.mkForce "none";
    settings.main.systemd-resolved = false;
  };
  networking.firewall.enable = true;
  # DNS over TLS to Cloudflare (strict: no plain-text fallback, so a captive
  # portal needs DNSOverTLS = "opportunistic" until logged in)
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = [
        "1.1.1.1#cloudflare-dns.com"
        "1.0.0.1#cloudflare-dns.com"
        "2606:4700:4700::1111#cloudflare-dns.com"
        "2606:4700:4700::1001#cloudflare-dns.com"
      ];
      DNSOverTLS = "true";
      Domains = [ "~." ];
      FallbackDNS = [ ];
    };
  };

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
      # `-p 3000:3000` binds to localhost unless an address is given: docker's
      # own iptables rules bypass the firewall, so 0.0.0.0 meant the whole LAN
      ip = "127.0.0.1";
      dns = [
        "1.1.1.1"
        "8.8.8.8"
      ];
      storage-driver = "btrfs";
    };
  };

  # search engine
  services.searx = {
    enable = true;
    package = pkgs.searxng;
    # SEARX_SECRET_KEY=..., root only, outside the (public) repo
    environmentFile = "/persist/secrets/searx.env";
    settings = {
      server = {
        port = 8822;
        bind_address = "127.0.0.1";
        secret_key = "$SEARX_SECRET_KEY";
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
          base_url = "https://wiki.nixos.org/";
          shortcut = "nw";
        }
      ];
    };
  };
  # its secret key is made on the first boot of each host (a fresh install,
  # the live ISO), random and never in the flake
  systemd.services.searx-secret = {
    description = "Create the searx secret key";
    wantedBy = [ "searx-init.service" ];
    before = [ "searx-init.service" ];
    unitConfig.ConditionPathExists = "!/persist/secrets/searx.env";
    serviceConfig.Type = "oneshot";
    path = [
      pkgs.coreutils
      pkgs.openssl
    ];
    script = ''
      install -d -m 700 /persist/secrets
      umask 077
      printf 'SEARX_SECRET_KEY=%s\n' "$(openssl rand -hex 32)" > /persist/secrets/searx.env
    '';
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
