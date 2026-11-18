# A laptop: TLP tunes it on AC and on battery, and its power profiles
# (performance, balanced, power saver) are the ones the bar's control center
# switches (tlp-pd: the power-profiles-daemon interface). The battery itself,
# its warnings and its charge limit come from UPower (hardware/default.nix)
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.hardware.laptop;

  # the charge limit's values, kept (/var/lib/upower persists); udev hands
  # them to UPower (CHARGE_LIMIT, over its hwdb's 75,80), whose switch turns
  # them on and off in the bar and in GNOME
  limitFile = "/var/lib/upower/dotnix-charge-limit";

  # root's side: checks the numbers, keeps them, and applies them now if the
  # limit is on; UPower restarts to take them for its switch
  setLimit = pkgs.writeShellApplication {
    name = "dotnix-charge-limit-set";
    runtimeInputs = [
      pkgs.coreutils
      config.systemd.package
    ];
    text = ''
      start=''${1:-} end=''${2:-}
      if ! [[ $start =~ ^[0-9]{1,3}$ && $end =~ ^[0-9]{1,3}$ ]] || ((start >= end || end > 100 || end < 50)); then
        echo "start must be below end, and end between 50 and 100" >&2
        exit 2
      fi
      printf 'CHARGE_LIMIT=%s,%s\n' "$start" "$end" > ${limitFile}.tmp
      mv -f ${limitFile}.tmp ${limitFile}
      enabled=$(busctl get-property org.freedesktop.UPower /org/freedesktop/UPower/devices/battery_BAT0 \
        org.freedesktop.UPower.Device ChargeThresholdEnabled 2>/dev/null || true)
      if [ "$enabled" = "b true" ]; then
        for bat in /sys/class/power_supply/BAT*; do
          [ -w "$bat/charge_control_end_threshold" ] || continue
          # the start always below the end, while both change
          if ((start < $(cat "$bat/charge_control_end_threshold"))); then
            echo "$start" > "$bat/charge_control_start_threshold"
            echo "$end" > "$bat/charge_control_end_threshold"
          else
            echo "$end" > "$bat/charge_control_end_threshold"
            echo "$start" > "$bat/charge_control_start_threshold"
          fi
        done
      fi
      udevadm trigger --action=change --subsystem-match=power_supply
      udevadm settle
      systemctl restart upower.service
    '';
  };

  # the user's side: two sliders, then the change as root (allowed below)
  limitApp = pkgs.writeShellApplication {
    name = "dotnix-charge-limit";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.zenity
    ];
    text = ''
      start=75 end=80
      if [ -r ${limitFile} ]; then
        IFS=, read -r start end < <(cut -d= -f2 ${limitFile})
      fi
      start=$(zenity --scale --title="Limite de carga da bateria" \
        --text="Voltar a carregar quando estiver abaixo de (%)" \
        --min-value=20 --max-value=95 --step=5 --value="$start") || exit 0
      end=$(zenity --scale --title="Limite de carga da bateria" \
        --text="Parar de carregar em (%)" \
        --min-value=50 --max-value=100 --step=5 --value="$end") || exit 0
      if ((start >= end)); then
        zenity --error --title="Limite de carga da bateria" \
          --text="O início ($start%) precisa ser menor que o fim ($end%)."
        exit 1
      fi
      if ! err=$(pkexec ${lib.getExe setLimit} "$start" "$end" 2>&1); then
        zenity --error --title="Limite de carga da bateria" --text="Não foi possível mudar: $err"
        exit 1
      fi
      zenity --info --title="Limite de carga da bateria" \
        --text="Carrega quando cair abaixo de $start% e para em $end%.\nLigue ou desligue o limite no painel da bateria."
    '';
  };
in
{
  options.dotnix.hardware.laptop.enable =
    lib.mkEnableOption "laptop power management (TLP, power profiles)";

  config = lib.mkIf cfg.enable {
    services.tlp = {
      enable = true;
      pd.enable = true;
      settings = {
        # full speed on AC, saving on battery
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
        CPU_BOOST_ON_AC = 1;
        CPU_BOOST_ON_BAT = 0;
        PLATFORM_PROFILE_ON_AC = "performance";
        PLATFORM_PROFILE_ON_BAT = "low-power";
        # no adaptive backlight (ABM): on te's panel it flickers non-stop, on
        # battery (TLP's default 1) and in power saver (3); the rest of the
        # saving stays
        AMDGPU_ABM_LEVEL_ON_AC = 0;
        AMDGPU_ABM_LEVEL_ON_BAT = 0;
        AMDGPU_ABM_LEVEL_ON_SAV = 0;
      };
    };
    # (nixos-hardware's laptop profiles may turn it on; tlp-pd takes its place)
    services.power-profiles-daemon.enable = false;

    services.udev.extraRules = ''
      SUBSYSTEM=="power_supply", KERNEL=="BAT*", IMPORT{file}="${limitFile}"
    '';
    # whoever is at the screen changes it without a password: only these
    # two numbers, checked by the helper
    security.polkit.extraConfig = ''
      polkit.addRule(function (action, subject) {
        if (action.id == "org.freedesktop.policykit.exec" &&
            action.lookup("program") == "${lib.getExe setLimit}" &&
            subject.local && subject.active) {
          return polkit.Result.YES;
        }
      });
    '';
    environment.systemPackages = [
      limitApp
      (pkgs.makeDesktopItem {
        name = "dotnix-charge-limit";
        desktopName = "Limite de carga da bateria";
        comment = "Onde a bateria volta a carregar e onde para";
        exec = lib.getExe limitApp;
        icon = "battery-good-charging";
        categories = [
          "Settings"
          "HardwareSettings"
        ];
      })
    ];
  };
}
