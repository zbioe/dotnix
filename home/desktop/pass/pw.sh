# `pw`: Proton Pass from the desktop. CLEAR_AFTER (seconds a copied secret
# stays in the clipboard) and ANSWER (answer.py) come from default.nix.

dir=${XDG_RUNTIME_DIR:-/tmp}/pw
index=$dir/index.json
mkdir -p "$dir"
chmod 700 "$dir"

usage() {
  echo "usage: pw [state | index | search TEXT | copy URI [FIELD] | totp URI | open URI"
  echo "          | lock | unlock [--file FILE] | run COMMAND...]"
  echo "FIELD: password (default), username, email, note"
}

notify() { notify-send -a "Proton Pass" -i dialog-password "$@" || true; }

# one pass-cli at a time: two at once fight over its database
cli() { flock "$dir/cli.lock" pass-cli "$@"; }

# logged-out, locked or unlocked (`info` answers even when locked)
state() {
  local out
  if out=$(cli vault list --output json 2>&1); then
    echo unlocked
  elif grep -qi "locked" <<<"$out"; then
    echo locked
  else
    echo logged-out
  fi
}

# every item's title, type, user and pass:// URI (no secrets), kept in RAM; one
# build at a time (two pass-cli at once fight over its database), and a
# build that waited takes the one just made
index() {
  exec 9>"$dir/index.lock"
  flock 9
  case "${1:-}" in
    --force) ;;
    --refresh) [ -n "$(find "$index" -mmin -10 2>/dev/null)" ] && return 0 ;;
    *) [ -e "$index" ] && return 0 ;;
  esac
  echo $$ >"$dir/index.pid"
  local tmp
  tmp=$(mktemp "$dir/index.XXXXXX")
  # shellcheck disable=SC2064 # the names now: tmp is gone by the time it runs
  trap "rm -f '$tmp' '$dir/index.pid'" EXIT
  if cli vault list --output json | jq -r '.vaults[].name' | while read -r vault; do
    # --show-secrets only to tell which have a one-time code: no secret is kept
    cli item list "$vault" --output json --show-secrets |
      jq -c --arg vault "$vault" '.items[] | select(.state != "Trashed")
        | (.content.content | keys[0] | ascii_downcase) as $type
        | (.content.content.Login // {}) as $l
        | {title: .content.title, type: $type, vault: $vault, uri: "pass://\(.share_id)/\(.id)",
           user: ([$l.username, $l.email] | map(select(. != null and . != "")) | first // ""),
           totp: (($l.totp_uri // "") != "")}'
  done | jq -s 'sort_by(.title | ascii_downcase)' >"$tmp"; then
    mv -f "$tmp" "$index"
  else
    rm -f "$tmp"
    return 1
  fi
}

# copies VALUE, marked secret (out of the clipboard history), cleared later
copy_secret() {
  local value=$1 what=$2
  printf '%s' "$value" | wl-copy --sensitive
  notify "$what copied" "cleared from the clipboard in ${CLEAR_AFTER}s"
  (
    sleep "$CLEAR_AFTER"
    [ "$(wl-paste -n 2>/dev/null)" = "$value" ] && wl-copy --clear
  ) >/dev/null 2>&1 &
  disown
}

field() {
  local uri=$1 field=$2 value
  value=$(cli item view "$uri" --output json | jq -r --arg f "$field" '
    .item.content as $c
    | if $f == "note" then $c.note else ($c.content.Login[$f] // empty) end')
  [ -n "$value" ] || { notify "No $field in this item"; exit 1; }
  copy_secret "$value" "${field^}"
}

case "${1:-state}" in
  state) state ;;
  index) index "${2:-}" ;;
  search)
    [ -e "$index" ] || index
    jq -r --arg q "${2,,}" '.[] | select(.title | ascii_downcase | contains($q)) | "\(.uri)\t\(.title)"' "$index"
    ;;
  copy) field "${2:?$(usage)}" "${3:-password}" ;;
  totp)
    code=$(cli item totp "${2:?$(usage)}" --output json | jq -r '.totp // empty')
    [ -n "$code" ] || { notify "No one-time code in this item"; exit 1; }
    copy_secret "$code" "One-time code"
    ;;
  open)
    url=$(cli item view "${2:?$(usage)}" --output json | jq -r '.item.content.content.Login.urls[0] // empty')
    [ -n "$url" ] || { notify "No website in this item"; exit 1; }
    xdg-open "$url" >/dev/null 2>&1 &
    ;;
  # the list (titles only) stays: the launcher shows nothing but "locked" until
  # the code, and then it is there at once
  lock)
    if [ -s "$dir/index.pid" ]; then kill -- -"$(cat "$dir/index.pid")" 2>/dev/null || true; fi
    flock -w 5 "$dir/cli.lock" pass-cli session lock >/dev/null 2>&1 || true
    ;;
  # the lock code from the PIN panel, read from a file in RAM and removed at once
  unlock)
    if [ "${2:-}" = --file ]; then
      pin=$(cat "$3")
      rm -f "$3"
    else
      read -rsp "Lock code: " pin
      echo
    fi
    # pass-cli reads it from a terminal, flushing anything typed before its prompt
    if ! printf '%s\n' "$pin" | flock "$dir/cli.lock" python3 "$ANSWER" "lock code" pass-cli session unlock >/dev/null; then
      notify "Wrong lock code"
      exit 1
    fi
    unset pin
    # the list in the background: callers may wait only a few seconds
    setsid -f "$0" index --refresh >/dev/null 2>&1
    ;;
  run)
    shift
    exec pass-cli run --env-file "$HOME/.env" -- "$@"
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
