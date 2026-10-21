# `theme icons`: the icon pack of the bar (tags and every glyph), and any
# one's own icon (home/theme/icons). Included in `theme` after ICON_INDEX and
# ICON_DEFAULT.

istate=$state/icons

icon_get() {
  awk -F= -v k="$1" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' "$istate" 2>/dev/null || true
}

icon_put() {
  { grep -v "^$1=" "$istate" 2>/dev/null || true; echo "$1=$2"; } >"$istate.tmp"
  mv -f "$istate.tmp" "$istate"
}

icon_pack() {
  local p
  p=$(icon_get pack)
  if [ -n "$p" ] && jq -e --arg p "$p" '.packs | has($p)' "$ICON_INDEX" >/dev/null; then echo "$p"; else echo "$ICON_DEFAULT"; fi
}

# the user's icons of PACK under PREFIX ("" tags, "bar." the bar) as JSON
icon_overrides() {
  { grep -E "^$1\.$2[^.=]+=" "$istate" 2>/dev/null || true; } | sed "s/^$1\.$2//" |
    jq -R 'index("=") as $i | {(.[:$i]): .[$i + 1:]}' | jq -s 'add // {}'
}

# app icon themes: ICON_APPS has "name<TAB>title<TAB>dark<TAB>light" lines
icon_apps() {
  local a
  a=$(icon_get apps)
  if [ -n "$a" ] && awk -F'\t' -v a="$a" '$1 == a { f = 1 } END { exit !f }' <<<"$ICON_APPS"; then
    echo "$a"
  else
    echo "$ICON_APPS_DEFAULT"
  fi
}

# the icon theme's folder for MODE (dark or light)
icon_apps_theme() {
  awk -F'\t' -v a="$(icon_apps)" -v m="$1" '$1 == a { print (m == "light" ? $4 : $3) }' <<<"$ICON_APPS"
}

# PACK's tags as "tag<TAB>name<TAB>icon" lines, in tag order
icon_tags() {
  jq -r --arg p "$1" --argjson o "$(icon_overrides "$1" "")" '
    .packs[$p] as $k | $k.tags + $o | to_entries | sort_by(.key | tonumber)[]
    | "\(.key)\t\(.value)\t\([$k.glyphs[.value]] | implode)"' "$ICON_INDEX"
}

# the bar's glyphs as "glyph<TAB>name<TAB>codepoint" lines, the ones PACK draws
icon_bar() {
  jq -r --arg p "$1" --argjson o "$(icon_overrides "$1" bar.)" '
    .packs[$p] as $k | ($k.bar + $o) as $m | .bar[] | select($m[.name])
    | "\(.name)\t\($m[.name])\t\($k.glyphs[$m[.name]])"' "$ICON_INDEX"
}

# noctalia merges every *.toml of its folder: the tags' labels and font, and
# the bar's glyphs from the pack's font (patches/noctalia-glyph-override.patch)
icon_write() {
  local p map glyphs
  p=$(icon_pack)
  map=$(icon_tags "$p" | awk -F'\t' '{ printf "%s%s=%s", (NR > 1 ? "," : ""), $1, $3 }')
  glyphs=$(icon_bar "$p" | awk -F'\t' '{ printf "%s%s=U+%X", (NR > 1 ? "," : ""), $1, $3 }')
  jq -r --arg p "$p" --arg map "$map" --arg glyphs "$glyphs" --argjson tint "$([ "$(icon_get tint)" = on ] && echo true || echo false)" '.packs[$p] |
    "[shell]\nglyph_font = \"\(.font)\"\nglyph_map = \"\($glyphs)\"\napp_icon_colorize = \($tint)\n" +
    "[widget.workspaces]\nfont_family = \"\(.family)\"\nfont_weight = \(.weight)\nlabel_map = \"\($map)\""' \
    "$ICON_INDEX" | font_file "$HOME/.config/noctalia/icons.toml"
}

icon_status() {
  local p
  p=$(icon_pack)
  echo "pack    $p ($(jq -r --arg p "$p" '.packs[$p].title' "$ICON_INDEX"))"
  echo "apps    $(icon_apps) ($(icon_apps_theme dark) / $(icon_apps_theme light)), tint $(icon_get tint)"
  icon_tags "$p" | awk -F'\t' '{ printf "tag %-3s %s  %s\n", $1, $3, $2 }'
  icon_bar "$p" | awk -F'\t' '{ printf "bar     %-20s %s\n", $1, $2 }'
}

icon_usage() {
  echo "usage: theme icons [status | packs | pack NAME | tag N ICON | bar GLYPH ICON | find TEXT | reset [N|GLYPH]"
  echo "                    | apps [NAME] | tint on|off]"
}

# `theme icons ...`; returns 0 when something changed (apply it), 1 otherwise
icon_cmd() {
  local p
  p=$(icon_pack)
  case "${1:-status}" in
    status) icon_status; return 1 ;;
    packs)
      jq -r --arg c "$p" '.packs | to_entries[] | "\(if .key == $c then "*" else " " end) \(.key)\t\(.value.title)"' "$ICON_INDEX"
      return 1
      ;;
    pack)
      jq -e --arg p "${2:-}" '.packs | has($p)' "$ICON_INDEX" >/dev/null ||
        { echo "theme: no icon pack '${2:-}' (theme icons packs)" >&2; exit 1; }
      icon_put pack "$2"
      ;;
    tag | bar)
      if [ "$1" = tag ]; then
        [[ "${2:-}" =~ ^([1-9]|10)$ ]] && [ -n "${3:-}" ] || { icon_usage >&2; exit 1; }
      else
        jq -e --arg g "${2:-}" 'any(.bar[]; .name == $g)' "$ICON_INDEX" >/dev/null && [ -n "${3:-}" ] ||
          { echo "theme: GLYPH is one of: $(jq -r '[.bar[].name] | join(" ")' "$ICON_INDEX")" >&2; exit 1; }
      fi
      jq -e --arg p "$p" --arg g "$3" '.packs[$p].glyphs | has($g)' "$ICON_INDEX" >/dev/null ||
        { echo "theme: no icon '$3' in $p (theme icons find TEXT)" >&2; exit 1; }
      if [ "$1" = tag ]; then icon_put "$p.$2" "$3"; else icon_put "$p.bar.$2" "$3"; fi
      ;;
    apps)
      if [ -z "${2:-}" ]; then
        awk -F'\t' -v c="$(icon_apps)" '{ printf "%s %s\t%s\n", ($1 == c ? "*" : " "), $1, $2 }' <<<"$ICON_APPS"
        return 1
      fi
      awk -F'\t' -v a="$2" '$1 == a { f = 1 } END { exit !f }' <<<"$ICON_APPS" ||
        { echo "theme: no app icon theme '$2' (theme icons apps)" >&2; exit 1; }
      icon_put apps "$2"
      ;;
    tint)
      [[ "${2:-}" =~ ^(on|off)$ ]] || { icon_usage >&2; exit 1; }
      icon_put tint "$2"
      ;;
    find)
      [ -n "${2:-}" ] || { icon_usage >&2; exit 1; }
      jq -r --arg p "$p" --arg q "${2,,}" '.packs[$p].glyphs | to_entries[]
        | select(.key | ascii_downcase | contains($q)) | "\([.value] | implode)  \(.key)"' "$ICON_INDEX" | head -40
      return 1
      ;;
    reset)
      local key="$p\."
      if [[ "${2:-}" =~ ^([1-9]|10)$ ]]; then
        key="$p\.$2="
      elif [ -n "${2:-}" ]; then
        key="$p\.bar\.$2="
      fi
      { grep -v "^$key" "$istate" 2>/dev/null || true; } >"$istate.tmp"
      mv -f "$istate.tmp" "$istate"
      ;;
    *) icon_usage >&2; exit 1 ;;
  esac
  return 0
}
