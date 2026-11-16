{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.hardware.keyboard;
  inherit (lib) types mkOption mkIf;
  remaps = lib.attrNames config.services.kanata.keyboards;
  # whether the account in front of the screen keeps the remaps
  allowed = pkgs.writeShellApplication {
    name = "dotnix-kanata-allowed";
    runtimeInputs = [ config.systemd.package ];
    text = ''
      session=$(loginctl show-seat seat0 -p ActiveSession --value)
      [ -n "$session" ] || exit 0
      user=$(loginctl show-session "$session" -p Name --value)
      off=(${lib.escapeShellArgs cfg.kanata.offFor})
      for name in "''${off[@]}"; do
        [ "$user" != "$name" ] || exit 1
      done
    '';
  };
  # off and back on as the screen changes hands (logind's seat says when)
  follow = pkgs.writeShellApplication {
    name = "dotnix-kanata-follow";
    runtimeInputs = [
      config.systemd.package
      pkgs.glib
    ];
    text = ''
      shopt -s nullglob
      apply() {
        if ${lib.getExe allowed}; then
          ${lib.concatMapStrings (name: ''
            devices=(${toString config.services.kanata.keyboards.${name}.devices})
            for device in "''${devices[@]}"; do
              [ -e "$device" ] && systemctl start --no-block kanata-${name}.service
            done
          '') remaps}
          :
        else
          systemctl stop ${toString (map (name: "kanata-${name}.service") remaps)}
        fi
      }
      apply
      gdbus monitor --system --dest org.freedesktop.login1 \
        --object-path /org/freedesktop/login1/seat/seat0 |
        while read -r _event; do apply; done
    '';
  };
in
{
  options.dotnix.hardware.keyboard = with types; {
    enable = lib.mkEnableOption "the keyboard setup (console, xkb, kanata)";
    layout = mkOption {
      type = str;
      example = "us";
    };
    model = mkOption {
      type = str;
      default = "";
      example = "thinkpad";
    };
    variant = mkOption {
      type = str;
      default = "";
      example = "intl";
    };
    # caps is esc on tap, ctrl on hold; the external one also types accents with AltGr
    kanata = {
      internal.enable = lib.mkEnableOption "kanata on the laptop's keyboard";
      external.enable = lib.mkEnableOption "kanata on external keyboards";
      offFor = mkOption {
        type = listOf str;
        default = [ ];
        example = [ "amanda" ];
        description = "Accounts that get the plain keyboard (caps lock is caps lock) while theirs is the session on screen.";
      };
    };
  };
  config = mkIf cfg.enable {
    console = {
      font = "ter-v32n";
      earlySetup = true;
      useXkbConfig = true;
      packages = with pkgs; [ terminus_font ];
    };

    services.xserver.xkb = with cfg; {
      inherit layout model variant;
    };

    hardware.uinput.enable = true;
    boot.extraModprobeConfig = ''
      options hid_apple fnmode=2
    '';

    services.udev.extraRules = mkIf cfg.kanata.external.enable ''
      ACTION=="add", KERNEL=="event*", SUBSYSTEM=="input", ATTRS{name}=="RK61RGB 5.0 Keyboard", SYMLINK+="input/rk61_bt", TAG+="systemd", ENV{SYSTEMD_WANTS}+="kanata-external.service"
    '';

    systemd.services = mkIf (cfg.kanata.offFor != [ ] && remaps != [ ]) (
      lib.genAttrs (map (name: "kanata-${name}") remaps) (_: {
        # (+: outside the unit's sandbox, to ask logind)
        serviceConfig.ExecCondition = "+${lib.getExe allowed}";
      })
      // {
        dotnix-kanata-follow = {
          description = "Key remaps off for the accounts without them";
          wantedBy = [ "multi-user.target" ];
          after = [ "systemd-logind.service" ];
          serviceConfig = {
            ExecStart = lib.getExe follow;
            Restart = "always";
          };
        };
      }
    );

    services.kanata = {
      enable = cfg.kanata.internal.enable || cfg.kanata.external.enable;
      keyboards = {
        internal = mkIf cfg.kanata.internal.enable {
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
        external = mkIf cfg.kanata.external.enable {
          devices = [
            # bluetooth
            "/dev/input/rk61_bt"

            # USB
            "/dev/input/by-id/usb-SINO_WEALTH_Bluetooth_Keyboard-event-kbd"
            "/dev/input/by-id/usb-258a_00e1*-event-kbd" # wildcard on the ID

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
              alt_layer (layer-while-held accents_pt)

              ;; --- ACCENT MACROS ---
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

            (deflayer accents_pt
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
