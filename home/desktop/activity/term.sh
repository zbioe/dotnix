# aw-term CMD STATUS DURATION_MS DIR: one finished shell command as an event in
# aw-watcher-terminal_HOST (fish's fish_postexec calls it in the background)
cmd=$1 status=$2 ms=$3 dir=$4
[ -n "$cmd" ] || exit 0

end=$(date +%s.%N)
start=$(awk -v e="$end" -v ms="$ms" 'BEGIN { printf "%.3f", e - ms / 1000 }')
root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)
session=""
[ -n "${TMUX:-}" ] && session=$(tmux display-message -p '#S' 2>/dev/null || true)

jq -nc \
  --arg ts "$(date -u -d "@$start" +%FT%T.%3NZ)" \
  --argjson dur "$(awk -v ms="$ms" 'BEGIN { printf "%.3f", ms / 1000 }')" \
  --arg cmd "$cmd" \
  --arg bin "$(printf '%s' "$cmd" | awk '{ print $1 }')" \
  --argjson status "$status" \
  --arg dir "$dir" \
  --arg project "$(basename "${root:-}")" \
  --arg session "$session" \
  --arg term "${TERM_PROGRAM:-${TERM:-}}" \
  '[{timestamp: $ts, duration: $dur, data: {
      cmd: $cmd, bin: $bin, status: $status, dir: $dir,
      project: (if $project == "" then null else $project end),
      tmux: (if $session == "" then null else $session end),
      shell: "fish", term: $term
    }}]' |
  curl -sf -m 3 -X POST -H 'Content-Type: application/json' --data-binary @- \
    "$AW_API/buckets/aw-watcher-terminal_$HOSTNAME/events" >/dev/null
