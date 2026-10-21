# `vpn`: Proton VPN through its CLI, and any VPN or WireGuard file
# NetworkManager knows. FAVORITES (the first ones) comes from default.nix.

state=${XDG_STATE_HOME:-$HOME/.local/state}/vpn
favorites=$state/favorites
mkdir -p "$state"
[ -e "$favorites" ] || printf '%s\n' "${FAVORITES[@]}" >"$favorites"

usage() {
  echo "usage: vpn [status [--json] | up [TARGET] | down | toggle | list"
  echo "           | fav [add TARGET | remove TARGET | reset] | add FILE.conf | remove NAME | app]"
  echo "TARGET: fastest, a country (BR), a server (BR#10), securecore, p2p, tor,"
  echo "        city:NAME, or a NetworkManager connection"
}

proton() { command -v protonvpn >/dev/null; }

# a Proton target, or nothing when TARGET is a NetworkManager connection
proton_args() {
  case "$1" in
    fastest) printf '%s\n' connect ;;
    securecore) printf '%s\n' connect --securecore ;;
    p2p) printf '%s\n' connect --p2p ;;
    tor) printf '%s\n' connect --tor ;;
    city:*) printf '%s\n' connect --city "${1#city:}" ;;
    [A-Za-z][A-Za-z]) printf '%s\n' connect --country "${1^^}" ;;
    [A-Za-z][A-Za-z]#[0-9]*) printf '%s\n' connect "${1^^}" ;;
  esac
}

# VPN connections as UUID<TAB>TYPE<TAB>ACTIVE(yes/no)<TAB>NAME
connections() {
  nmcli -t -f UUID,TYPE,ACTIVE connection show | while IFS=: read -r uuid type active; do
    case "$type" in vpn | wireguard) ;; *) continue ;; esac
    printf '%s\t%s\t%s\t%s\n' "$uuid" "$type" "$active" "$(nmcli -g connection.id connection show "$uuid")"
  done
}

json() {
  connections | jq -R -s \
    --arg last "$(cat "$state/last" 2>/dev/null || true)" \
    --argjson proton "$(proton && echo true || echo false)" \
    --rawfile favorites "$favorites" '
    [split("\n")[] | select(. != "") | split("\t") | {uuid: .[0], type: .[1], active: (.[2] == "yes"), name: .[3]}]
    | {
        active: map(select(.active)),
        saved: map(select(.name | test("^(ProtonVPN|pvpn-)") | not)),
        favorites: ($favorites | split("\n") | map(select(. != ""))),
        last: $last,
        proton: $proton
      }'
}

up() {
  local target=${1:-$(cat "$state/last" 2>/dev/null || echo fastest)}
  local args
  mapfile -t args < <(proton_args "$target")
  if [ ${#args[@]} -gt 0 ]; then
    proton || { echo "vpn: the Proton VPN CLI isn't installed" >&2; exit 1; }
    down
    protonvpn "${args[@]}"
  else
    nmcli connection up "$target" >/dev/null
  fi
  echo "$target" >"$state/last"
}

down() {
  connections | awk -F'\t' '$3 == "yes" { print $1 "\t" $4 }' | while IFS=$'\t' read -r uuid name; do
    if [[ $name == ProtonVPN* ]] && proton; then
      protonvpn disconnect >/dev/null
    else
      nmcli connection down "$uuid" >/dev/null
    fi
  done
}

case "${1:-status}" in
  status)
    if [ "${2:-}" = --json ]; then
      json
    else
      connections | awk -F'\t' '$3 == "yes" { print "up\t" $4; f = 1 } END { if (!f) print "down" }'
    fi
    ;;
  up) up "${2:-}" ;;
  down) down ;;
  toggle)
    if connections | awk -F'\t' '$3 == "yes" { f = 1 } END { exit !f }'; then down; else up; fi
    ;;
  list) connections | awk -F'\t' '{ printf "%s %s\t%s\n", ($3 == "yes" ? "*" : " "), $4, $2 }' ;;
  fav)
    case "${2:-}" in
      add)
        [ -n "${3:-}" ] || { usage >&2; exit 1; }
        grep -qxF "$3" "$favorites" || echo "$3" >>"$favorites"
        ;;
      remove)
        { grep -vxF "${3:-}" "$favorites" || true; } >"$favorites.tmp"
        mv -f "$favorites.tmp" "$favorites"
        ;;
      reset) printf '%s\n' "${FAVORITES[@]}" >"$favorites" ;;
      *) cat "$favorites" ;;
    esac
    ;;
  add)
    [ -f "${2:-}" ] || { usage >&2; exit 1; }
    uuid=$(nmcli connection import type wireguard file "$2" | grep -oE '[0-9a-f-]{36}')
    nmcli connection modify "$uuid" connection.autoconnect no
    echo "vpn: added $(nmcli -g connection.id connection show "$uuid")"
    ;;
  remove)
    [ -n "${2:-}" ] || { usage >&2; exit 1; }
    nmcli connection delete "$2" >/dev/null
    ;;
  # the app is a single instance: running it again shows its window
  app) setsid -f protonvpn-app >/dev/null 2>&1 ;;
  *)
    usage >&2
    exit 1
    ;;
esac
