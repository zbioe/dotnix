{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.modules.keyboard;
  inherit (lib) types mkOption mkIf;
in
{
  options.modules.keyboard = with types; {
    enable = mkOption {
      type = bool;
      default = true;
      description = ''
        Enable keyboard config.
      '';
    };
    layout = mkOption {
      type = str;
      default = "br";
      example = "us";
      description = ''
        Keyborad Layout
      '';
    };
    model = mkOption {
      type = str;
      default = "br";
      example = "us";
      description = ''
        Keyborad Layout
      '';
    };
    variant = mkOption {
      type = str;
      default = "br";
      example = "us";
      description = ''
        Keyborad Layout
      '';
    };
  };
  config = mkIf cfg.enable {
    # Console defaults
    console = {
      font = "ter-v32n";
      earlySetup = true;
      useXkbConfig = true;
      packages = with pkgs; [ terminus_font ];
    };

    # Xdb defaults
    services.xserver.xkb = with cfg; {
      inherit layout model variant;
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
  };
}
