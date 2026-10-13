# `flake-updates`: keeps the flake's inputs current, the way the settings
# say (the "Updates" panel, noctalia-plugins/updates, or this command):
#   mode notify   tell which inputs have newer versions
#   mode ready    also build this host's system and home with them, and
#                 offer them: "Update ready" with Apply (default)
#   mode auto     build them and apply: the home now, the system as the
#                 default of the next boot (default/updates.nix), never a
#                 system switch under the running session
# Updates never happen in the flake itself: a copy (uncommitted changes
# included) is moved to the newest inputs and built; only Apply (or auto)
# writes the new flake.lock into the flake. A build that fails changes
# nothing. Inputs on hold stay where they are. A user timer looks every
# hour whether a check is due (daily, weekly or monthly).
#   flake-updates [check]       check (and build) now
#   flake-updates apply         apply what is ready
#   flake-updates status [--json]
#   flake-updates set KEY VALUE enabled on|off · notify on|off ·
#                               mode notify|ready|auto ·
#                               interval daily|weekly|monthly · hold "a b"
#   flake-updates log
{
  config,
  lib,
  pkgs,
  ...
}:
let
  flakeUpdates = pkgs.writeShellApplication {
    name = "flake-updates";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      git
      gnutar
      hostname
      jq
      libnotify
      nix
      systemd
      util-linux # flock
    ];
    text = ''
      flake=''${NH_FLAKE:-$HOME/dotnix}
      host=$(hostname -s)
      state=${config.xdg.stateHome}/flake-updates
      stage=$state/flake
      mkdir -p "$state"

      # settings (written by `set` only, so sourcing them is safe)
      enabled=on notify=on mode=ready interval=weekly hold=""
      # shellcheck disable=SC1091
      [ -f "$state/config" ] && . "$state/config"

      save() {
        printf 'enabled=%s\nnotify=%s\nmode=%s\ninterval=%s\nhold=%q\n' \
          "$enabled" "$notify" "$mode" "$interval" "$hold" > "$state/config.tmp"
        mv "$state/config.tmp" "$state/config"
      }

      say() { echo "$*"; echo "$(date '+%F %T') $*" >> "$state/history.log"; }
      notify_send() {
        [ "$notify" = on ] || return 0
        timeout 30m notify-send -a flake-updates -i system-software-update "$@" || true
      }
      panel() { noctalia msg panel-open dotnix/updates:panel >/dev/null 2>&1 || true; }

      # "name<TAB>old date<TAB>new date<TAB>days" for every input that moved
      changes() {
        jq -r --slurpfile new "$2" '
          def day: strftime("%Y-%m-%d");
          .nodes as $old | $new[0].nodes as $n
          | $old.root.inputs | to_entries[]
          | (.value | if type == "array" then empty else . end) as $node
          | select($old[$node].locked.lastModified != null)
          | select($old[$node].locked.lastModified != $n[$node].locked.lastModified)
          | [ .key,
              ($old[$node].locked.lastModified | day),
              ($n[$node].locked.lastModified | day),
              ((($n[$node].locked.lastModified - $old[$node].locked.lastModified) / 86400) | floor) ]
          | @tsv' "$1"
      }
      pretty() { awk -F'\t' '{ printf "%-18s %s → %s (+%s days)\n", $1, $2, $3, $4 }' "$1"; }
      inputs() { jq -r '.nodes.root.inputs | keys[]' "$flake/flake.lock"; }

      check() {
        exec 9>"$state/lock"
        flock -n 9 || { echo "already checking"; return 0; }
        [ -f "$flake/flake.lock" ] || { echo "no flake.lock in $flake"; return 1; }
        echo checking > "$state/phase"
        trap 'rm -f "$state/phase"' RETURN
        date +%s > "$state/last-check"

        # the flake as it is now (tracked and new files, no .git), newest
        # inputs except the ones on hold
        rm -rf "$stage"
        mkdir -p "$stage"
        git -C "$flake" ls-files -co --exclude-standard -z | tar -C "$flake" --null -T - -cf - | tar -C "$stage" -xf -
        local update=()
        for i in $(inputs); do
          case " $hold " in *" $i "*) ;; *) update+=("$i") ;; esac
        done
        if ! nix flake update --flake "path:$stage" "''${update[@]}" 2>"$state/update.log"; then
          say "could not check (offline?)"
          echo offline > "$state/result"
          return 0
        fi
        changes "$flake/flake.lock" "$stage/flake.lock" > "$state/changes"
        if [ ! -s "$state/changes" ]; then
          say "up to date"
          echo up-to-date > "$state/result"
          rm -f "$state/ready"
          return 0
        fi
        pretty "$state/changes"
        names=$(cut -f1 "$state/changes" | paste -sd, - | sed 's/,/, /g')

        if [ "$mode" = notify ]; then
          echo available > "$state/result"
          if ! cmp -s "$stage/flake.lock" "$state/announced.lock" 2>/dev/null; then
            cp "$stage/flake.lock" "$state/announced.lock"
            say "available: $names"
            [ "''${1:-}" = --background ] && action=$(notify_send -A show="Show" "Flake updates available" "$names") &&
              [ "$action" = show ] && panel
          fi
          return 0
        fi

        # built and offered already
        if cmp -s "$stage/flake.lock" "$state/ready.lock" 2>/dev/null && [ -e "$state/ready" ]; then
          echo ready > "$state/result"
          echo "ready: flake-updates apply"
          return 0
        fi

        echo building > "$state/phase"
        echo "building $host with them..."
        if nix build --out-link "$state/system" "path:$stage#nixosConfigurations.$host.config.system.build.toplevel" \
          > "$state/build.log" 2>&1 &&
          nix build --out-link "$state/home" "path:$stage#homeConfigurations.$host.activationPackage" \
          >> "$state/build.log" 2>&1; then
          # deprecations and the like: fine today, errors in a later release
          grep -E "evaluation warning|^warning:|trace: warning" "$state/build.log" |
            grep -v "Git tree .* is dirty" | sed -E 's/^(evaluation warning|warning|trace: warning): ?//' |
            sort -u > "$state/warnings" || true
          cp "$stage/flake.lock" "$state/ready.lock"
          sha256sum "$flake/flake.nix" > "$state/ready.flake-nix"
          date +%F > "$state/ready"
          echo ready > "$state/result"
          say "ready: $names"
          if [ "$mode" = auto ]; then
            apply --auto
          elif [ "''${1:-}" = --background ]; then
            action=$(notify_send -A apply="Apply" -A show="Details" "Update ready" "Built and tested: $names")
            case "$action" in
              apply) apply ;;
              show) panel ;;
            esac
          fi
        else
          rm -f "$state/ready"
          echo failed > "$state/result"
          say "does not build: $names (log: flake-updates log)"
          if [ "''${1:-}" = --background ] && ! cmp -s "$stage/flake.lock" "$state/failed.lock" 2>/dev/null; then
            cp "$stage/flake.lock" "$state/failed.lock"
            notify_send -u low "Update skipped" "The newest inputs don't build yet; nothing changed"
          fi
        fi
      }

      apply() {
        if [ ! -e "$state/ready" ]; then
          echo "nothing ready (flake-updates check)"
          return 1
        fi
        # its inputs were chosen for the flake.nix of then
        if ! sha256sum -c --status "$state/ready.flake-nix" 2>/dev/null; then
          echo "flake.nix changed since the update was built: checking again"
          rm -f "$state/ready"
          check
          return 0
        fi
        cp "$state/ready.lock" "$flake/flake.lock"
        rm -f "$state/ready"
        if [ "''${1:-}" = --auto ]; then
          # home now, system at the next boot (default/updates.nix)
          "$state/home/activate" > "$state/apply.log" 2>&1 || true
          readlink -f "$state/system" > "$state/pending-system"
          if systemctl start dotnix-update-boot.service; then
            echo pending-boot > "$state/result"
            say "applied: home now, system at the next boot"
            notify_send -u low "Update applied" "Home updated; the system switches at the next boot"
          else
            say "could not set the next boot (journalctl -u dotnix-update-boot)"
          fi
        else
          say "applying (rebuild)"
          echo applying > "$state/result"
          exec rebuild
        fi
      }

      status_json() {
        local last=0 result=none phase=idle
        [ -f "$state/last-check" ] && last=$(cat "$state/last-check")
        [ -f "$state/result" ] && result=$(cat "$state/result")
        # a built update waiting is "ready", whatever the last check said
        if [ -e "$state/ready" ] && [ "$result" != applying ]; then result=ready; fi
        [ -f "$state/phase" ] && phase=$(cat "$state/phase")
        jq -n --arg enabled "$enabled" --arg notify "$notify" --arg mode "$mode" \
          --arg interval "$interval" --arg hold "$hold" --arg result "$result" \
          --arg phase "$phase" --argjson last "$last" \
          --arg inputs "$(inputs | paste -sd' ' -)" \
          --rawfile changes <(cat "$state/changes" 2>/dev/null || true) \
          --rawfile warnings <(cat "$state/warnings" 2>/dev/null || true) '{
            enabled: ($enabled == "on"), notify: ($notify == "on"), mode: $mode,
            interval: $interval, hold: ($hold | split(" ") | map(select(. != ""))),
            inputs: ($inputs | split(" ") | map(select(. != ""))),
            result: $result, phase: $phase, lastCheck: $last,
            warnings: ($warnings | split("\n") | map(select(. != ""))),
            changes: ($changes | split("\n") | map(select(. != "") | split("\t")
              | { name: .[0], from: .[1], to: .[2], days: (.[3] | tonumber) }))
          }'
      }

      # the hourly timer: a check when one is due
      due() {
        [ "$enabled" = on ] || return 1
        local last=0 every
        [ -f "$state/last-check" ] && last=$(cat "$state/last-check")
        case $interval in
          daily) every=86400 ;;
          monthly) every=2592000 ;;
          *) every=604800 ;;
        esac
        [ $(($(date +%s) - last)) -ge "$every" ]
      }

      case "''${1:-check}" in
        check) check ;;
        --timer) if due; then check --background; fi ;;
        apply) apply ;;
        status)
          if [ "''${2:-}" = --json ]; then status_json; else
            echo "enabled $enabled · notify $notify · mode $mode · every $interval · hold: ''${hold:-none}"
            echo "last: $(cat "$state/result" 2>/dev/null || echo never)$([ -f "$state/last-check" ] && date -d "@$(cat "$state/last-check")" ' (%F %R)')"
            [ -s "$state/changes" ] && pretty "$state/changes"
          fi
          ;;
        set)
          key=''${2:?usage: flake-updates set KEY VALUE}
          value=''${3-}
          case "$key=$value" in
            enabled=on | enabled=off) enabled=$value ;;
            notify=on | notify=off) notify=$value ;;
            mode=notify | mode=ready | mode=auto) mode=$value ;;
            interval=daily | interval=weekly | interval=monthly) interval=$value ;;
            hold=*) hold=$value ;;
            *)
              echo "unknown: $key=$value"
              exit 1
              ;;
          esac
          save
          ;;
        log)
          tail -n 40 "$state/history.log" 2>/dev/null
          if [ -s "$state/warnings" ]; then
            echo "--- warnings of the last build (to fix before they become errors)"
            cat "$state/warnings"
          fi
          if [ "$(cat "$state/result" 2>/dev/null)" = failed ]; then
            echo "--- build"
            tail -n 60 "$state/build.log"
          fi
          ;;
        *)
          echo "usage: flake-updates [check | apply | status [--json] | set KEY VALUE | log]"
          exit 1
          ;;
      esac
    '';
  };
in
{
  home.packages = [ flakeUpdates ];

  systemd.user.services.flake-updates = {
    Unit.Description = "Keep the flake's inputs current (see flake-updates status)";
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe flakeUpdates} --timer";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };
  # hourly look; the interval in the settings decides when a check is due
  systemd.user.timers.flake-updates = {
    Unit.Description = "Flake update check, when due";
    Timer = {
      OnStartupSec = "15min";
      OnUnitActiveSec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  xdg.desktopEntries.flake-updates = {
    name = "Updates";
    comment = "Flake updates: settings, check and apply";
    exec = "noctalia msg panel-toggle dotnix/updates:panel";
    icon = "system-software-update";
    terminal = false;
    categories = [ "System" ];
  };
}
