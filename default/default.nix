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
    ./webcam.nix
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
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 10d";
    };
    extraOptions = ''
      keep-outputs = true
      keep-derivations = true
      tarball-ttl = 900
    '';
  };

  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;
  networking.firewall.enable = true;
  networking.nameservers = [
    "1.1.1.1"
    "1.0.0.1"
    "2606:4700:4700::1111"
    "2606:4700:4700::1001"
  ];
  services.resolved.enable = false;
  networking.networkmanager.dns = "dnsmasq";
  environment.etc."NetworkManager/dnsmasq.d/devops.conf".text = ''
    address=/.devops.local/172.18.0.2
  '';

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

  # AI services
  services.ollama = {
    enable = true;
    host = "0.0.0.0";
  };
  services.open-webui = {
    enable = true;
    port = 3333;
    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
      WEBUI_AUTH = "False";
    };
  };
  ####

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

  # Console defaults
  console = {
    font = "ter-v32n";
    earlySetup = true;
    useXkbConfig = true;
    packages = with pkgs; [ terminus_font ];
  };

  # Xdb defaults
  services.xserver.xkb = {
    layout = "br";
    model = "thinkpad";
    variant = "thinkpad";
  };
  hardware.uinput.enable = true;
  boot.extraModprobeConfig = ''
    options hid_apple fnmode=2
  '';

  services.kanata = {
    enable = true;
    keyboards = {
      internal = {
        devices = [

          "/dev/input/by-path/platform-i8042-serio-0-event-kbd"
        ];
        extraDefCfg = ''
          process-unmapped-keys yes
          linux-output-device-name "kanata-internal"
        '';
        config = ''
          (defsrc caps)
          (defalias
            cap (tap-hold-press 200 200 esc lctl)
          )
          (deflayer default 
            @cap
          )
        '';
      };
      external = {
        devices = [
          # bluetooth
          "/dev/input/rk61_bt"

          # USB
          "/dev/input/by-id/usb-SINO_WEALTH_Bluetooth_Keyboard-event-kbd"
          "/dev/input/by-id/usb-258a_00e1*-event-kbd" # Curinga pelo ID

          # Wireless
          "/dev/input/by-id/usb-Compx_2.4G_Wireless_Receiver-event-kbd"
        ];
        extraDefCfg = ''
          process-unmapped-keys yes
          linux-output-device-name "kanata-external"
        '';
        config = ''
          (defsrc 
            caps
            q w e r u i o p
            a s j l
            z c b n
            / ralt
          )

          (defalias
            cap (tap-hold-press 200 200 esc lctl)
            alt_layer (layer-while-held acentos_pt)
            
            ;; --- O SEU DICIONÁRIO DE ACENTOS ---
            m_til (macro S-grv spc) ;; ~ (AltGr + q)
            m_ati (macro S-grv a)   ;; ã (AltGr + w)
            m_eac (macro ' e)       ;; é (AltGr + e)
            m_eci (macro S-6 e)     ;; ê (AltGr + r)
            m_uac (macro ' u)       ;; ú (AltGr + u)
            m_iac (macro ' i)       ;; í (AltGr + i)
            m_oac (macro ' o)       ;; ó (AltGr + o)
            m_oti (macro S-grv o)   ;; õ (AltGr + p)
            
            m_aac (macro ' a)       ;; á (AltGr + a)
            m_aci (macro S-6 a)     ;; â (AltGr + s)
            m_utr (macro S-' u)     ;; ü (AltGr + j)
            m_oci (macro S-6 o)     ;; ô (AltGr + l)
            
            m_acr (macro grv a)     ;; à (AltGr + z)
            m_ced (macro ' c)       ;; ç (AltGr + c)
            m_usd (macro S-4)       ;; $ (AltGr + b)
            m_nti (macro S-grv n)   ;; ñ (AltGr + n)
            m_int (macro RA-/)      ;; ¿ (AltGr + /)
          )

          (deflayer default 
            @cap
            q w e r u i o p
            a s j l
            z c b n
            / @alt_layer
          )

          (deflayer acentos_pt 
            _
            @m_til @m_ati @m_eac @m_eci @m_uac @m_iac @m_oac @m_oti
            @m_aac @m_aci @m_utr @m_oci
            @m_acr @m_ced @m_usd @m_nti
            @m_int _
          )
        '';
      };
    };
  };

  # Docker defaults
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      dns = [
        "1.1.1.1"
        "8.8.8.8"
      ];
      storage-driver = "btrfs";
    };
  };

  # Waydroid
  virtualisation.waydroid = {
    enable = true;
    package = pkgs.waydroid-nftables;
  };
  environment.systemPackages = with pkgs; [
    waydroid-helper
  ];
  networking.firewall.trustedInterfaces = [ "waydroid0" ];
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv4.conf.all.forwarding" = 1;
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

        # Motores de Dev Nativos e Estáveis
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

}
