{
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
  security.pam.services.login.enableGnomeKeyring = false;

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
        devices = [ "/dev/input/by-path/platform-i8042-serio-0-event-kbd" ];
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
        devices = [ "/dev/input/by-id/usb-SINO_WEALTH_Bluetooth_Keyboard-event-kbd" ];
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

}
