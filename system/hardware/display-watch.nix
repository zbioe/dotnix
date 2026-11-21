# Diagnosis of a flickering or breaking amdgpu screen, which leaves no log
# of its own: once a second the display engine's state (its DTN log, from
# debugfs) is read, and when a pipe reports an underflow (the panel ran out
# of pixels to show) that state is saved with the time, the account on
# screen, the power source and profile, and the clocks. Debugfs stays on
# while this is enabled: a diagnosis, to turn off once found.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.hardware.graphics.amd.displayWatch;
  dir = "/var/log/display-watch";

  watch = pkgs.writeShellApplication {
    name = "display-watch";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      gnugrep
      systemd
    ];
    text = ''
      dtn=""
      for f in /sys/kernel/debug/dri/*/amdgpu_dm_dtn_log; do
        [ -r "$f" ] && dtn=$f && break
      done
      [ -n "$dtn" ] || { echo "no amdgpu_dm_dtn_log in debugfs" >&2; exit 1; }
      dev=/sys/class/drm/card1/device
      mkdir -p ${dir}

      state() {
        local s user type
        s=$(loginctl show-seat seat0 -p ActiveSession --value 2>/dev/null || true)
        if [ -n "$s" ]; then
          user=$(loginctl show-session "$s" -p Name --value 2>/dev/null || true)
          type=$(loginctl show-session "$s" -p Desktop --value 2>/dev/null || true)
          echo "session: $user ($type)"
        fi
        echo "ac: $(cat /sys/class/power_supply/AC/online 2>/dev/null)"
        echo "platform_profile: $(cat /sys/firmware/acpi/platform_profile 2>/dev/null)"
        echo "panel_power_savings: $(cat /sys/class/drm/card1-eDP-1/amdgpu/panel_power_savings 2>/dev/null)"
        local c
        for c in fclk mclk socclk sclk; do
          echo "$c: $(grep '\*' "$dev/pp_dpm_$c" 2>/dev/null | tr -s ' ')"
        done
      }

      snapshot() {
        local f
        f=${dir}/$(date +%F_%H-%M-%S)-$1.log
        { echo "== $1 at $(date -Is)"; state; echo "== dtn"; cat "$dtn"; } > "$f"
        echo "$f"
      }

      # the underflow columns of the pipes' tables (HUBP: the memory side,
      # OTG: the panel's timing), their highest value; empty when neither
      # table has one
      underflow() {
        awk '
          /^(HUBP|OTG):/ { col = 0; for (i = 1; i <= NF; i++) if ($i == "underflow") col = i; intable = col > 0; next }
          intable && /^[[:space:]]*$/ { intable = 0 }
          # (rows start "[ 0]:", made one field like the header "HUBP:")
          intable && /^\[/ { gsub(/\[ +/, "["); v = $col; sub(/h$/, "", v); if (v + 0 > max) max = v + 0; seen = 1 }
          END { if (seen) print max + 0 }
        ' "$dtn"
      }

      first=$(snapshot start)
      if [ -z "$(underflow)" ]; then
        echo "no underflow column in the DTN log: see $first" >&2
      fi
      echo "watching $dtn, state at start in $first"

      last=0
      while sleep 1; do
        u=$(underflow)
        [ -n "$u" ] || continue
        if [ "$u" != "$last" ] && [ "$u" != 0 ]; then
          f=$(snapshot underflow)
          echo "UNDERFLOW (status $u): $(state | tr '\n' ' ') -> $f"
        fi
        last=$u
      done
    '';
  };
in
{
  options.dotnix.hardware.graphics.amd.displayWatch.enable = lib.mkEnableOption ''
    a watch on the display engine (amdgpu's DTN log, through debugfs): each
    underflow saved to ${dir} with the machine's state'';

  config = lib.mkIf cfg.enable {
    systemd.services.display-watch = {
      description = "Watch the display engine for underflows";
      wantedBy = [ "multi-user.target" ];
      after = [ "sys-kernel-debug.mount" ];
      # (skipped, not failed, until a boot has debugfs)
      unitConfig.ConditionPathExistsGlob = "/sys/kernel/debug/dri/*/amdgpu_dm_dtn_log";
      serviceConfig = {
        ExecStart = lib.getExe watch;
        Restart = "on-failure";
        RestartSec = 10;
      };
    };
  };
}
