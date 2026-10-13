# `rebuild`: system then home switch (nh) for this host, in the background.
# A notification says it is running (with a button to follow the output);
# at the end it is replaced by the result: on failure the log comes to the
# front in a window closed with a click, on success only if asked for
# ("Show log"). The log is kept in ~/.local/state/rebuild.
# Started from the session menu (home/ui/noctalia.nix), Super+Shift+U
# (home/ui/mango.nix), the launcher ("System Update") or `rebuild`;
# `rebuild --here` runs it in the current terminal instead.
#
# No terminal to type the sudo password into: nh elevates through a sudo
# that always asks through SUDO_ASKPASS (a password dialog), once at the
# start, cached for the rest of the run (same pty, see script(1) below).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  askpass = pkgs.writeShellScript "rebuild-askpass" ''
    exec ${lib.getExe pkgs.zenity} --password --title="System Update" \
      --text="Password for the system switch"
  '';

  # nh's elevation program: sudo, always through the askpass dialog
  sudoAskpass = pkgs.writeShellScriptBin "sudo" ''
    exec /run/wrappers/bin/sudo -A "$@"
  '';

  rebuild = pkgs.writeShellApplication {
    name = "rebuild";
    runtimeInputs = with pkgs; [
      coreutils
      gnused
      util-linux # flock, script
      libnotify
      foot
      hostname
      systemd
      wl-clipboard
      zenity
    ];
    text = ''
      state=${config.xdg.stateHome}/rebuild
      log=$state/last.log
      unit=dotnix-rebuild
      # how long a notification waits for its button (the daemon may never
      # report it closed)
      wait=15m
      flake=''${NH_FLAKE:-$HOME/dotnix}
      host=$(hostname -s)
      steps="nh os switch -H $host && nh home switch -c $host"

      # without terminal control sequences (colors; the palette `theme apply`
      # sends to every terminal, this one too), lines redrawn with \r or
      # erase-line (only their last state) and script(1)'s start/end lines
      plain() {
        sed -E -e '/^Script .*\[COMMAND/d' \
          -e 's/\x1b\][^\x07\x1b]*(\x07|\x1b\\)//g' \
          -e 's/\r$//' -e 's/^.*(\r|\x1b\[2K)//' \
          -e 's/\x1b\[[0-9;?]*[a-zA-Z]//g' \
          -e 's/[\x00-\x08\x0b-\x1f\x7f]//g' "$log"
      }

      # the output so far, live, in a floating terminal
      progress() {
        exec foot --app-id=dotnix-rebuild --title="System Update" tail -n +1 -f "$log"
      }

      # the log, plain text, scrolled to its end; Close, or Copy log
      show() {
        if ! plain | zenity --text-info --title="$1" --width=1000 --height=650 \
          --font="monospace 10" --auto-scroll --ok-label=Close --cancel-label="Copy log" >/dev/null; then
          plain | wl-copy
        fi
      }

      # the job itself (systemd user unit $unit)
      run() {
        export SUDO_ASKPASS=${askpass} NH_ELEVATION_STRATEGY=${sudoAskpass}/bin/sudo NH_FLAKE=$flake
        local start took ok=0
        start=$(date +%s)
        echo "running" > "$state/status"
        # a pty for nh (its sudo caches the password per terminal); the
        # password first, so it is not asked in the middle of a long build
        if script -qefc "${sudoAskpass}/bin/sudo -v && $steps" "$log" </dev/null >/dev/null; then
          ok=1
        fi
        took=$(( $(date +%s) - start ))
        took="$((took / 60))min $((took % 60))s"
        echo "done" > "$state/status"
        # the result in a unit of its own: this one ends with nh, so a new
        # update can start while the notification or the log is still open
        systemd-run --user --quiet --collect --unit="$unit-result-$(date +%s)" \
          "$0" --result "$ok" "$took"
      }

      # the result: replaces the "Updating system" notification; the log
      # comes up on failure, or on request ("Show log")
      result() {
        local ok=$1 took=$2 replace=() action
        if [ -s "$state/notification" ]; then replace=(-r "$(cat "$state/notification")"); fi
        if [ "$ok" = 1 ]; then
          action=$(timeout "$wait" notify-send -a rebuild "''${replace[@]}" -i system-software-update -A log="Show log" \
            "System updated" "nh os + home switch in $took") || true
          if [ "$action" = log ]; then show "System Update: done ($took)"; fi
        else
          notify-send -a rebuild "''${replace[@]}" -u critical -i dialog-error "System update failed" "after $took · log: $log"
          show "System Update: failed ($took)"
        fi
      }

      # foreground, in this terminal
      here() {
        exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/rebuild.lock"
        if ! flock -n 9 || running; then
          echo "rebuild: already running"
          exit 1
        fi
        if script -qefc "$steps" "$log"; then
          printf '\n\033[1;32m✔ system and home switched\033[0m\n'
        else
          printf '\n\033[1;31m✘ failed\033[0m · log: %s\n' "$log"
          exit 1
        fi
      }

      # a notification with a "Show progress" button (its id kept, so the
      # result can replace it)
      notify_running() {
        timeout "$wait" notify-send -a rebuild -p -i system-software-update -A progress="Show progress" "$1" "$2" |
          {
            read -r id && echo "$id" > "$state/notification"
            read -r action || true
            if [ "$action" = progress ]; then progress; fi
          }
      }

      # background: the job in its own unit (it outlives the session's
      # restarts during the switch), and the notification to follow it
      # an update is running: its unit is up and it has not reached "done"
      # (a unit left over after nh finished is stopped instead)
      running() {
        systemctl --user is-active --quiet "$unit" || return 1
        if [ "$(cat "$state/status" 2>/dev/null)" = running ]; then return 0; fi
        systemctl --user stop "$unit" || true
        return 1
      }

      start() {
        if running; then
          notify_running "System update already running" "nh os + home switch"
          exit 0
        fi
        : > "$log"
        rm -f "$state/notification"
        systemd-run --user --quiet --collect --unit="$unit" \
          --setenv=NH_FLAKE="$flake" "$(command -v rebuild)" --run
        notify_running "Updating system" "nh os + home switch running in the background"
      }

      mkdir -p "$state"
      case "''${1:-}" in
        --run) run ;;
        --result) result "$2" "$3" ;;
        --here) here ;;
        --progress) progress ;;
        --show) show "System Update: last log" ;;
        "") start ;;
        *)
          echo "usage: rebuild [--here | --progress | --show]"
          exit 1
          ;;
      esac
    '';
  };
in
{
  home.packages = [ rebuild ];

  xdg.desktopEntries.rebuild = {
    name = "System Update";
    comment = "nh os switch and nh home switch in the background, with the log";
    exec = "rebuild";
    icon = "system-software-update";
    terminal = false;
    categories = [ "System" ];
  };
}
