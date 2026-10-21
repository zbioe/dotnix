# `theme font`: fonts per role, written for every app (home/theme/fonts).
# Included in `theme` after FONT_DEFAULTS, FONT_CATALOG and FONT_PRESETS
# ("key=value" / "role<TAB>family" / "preset<TAB>key=value" lines).

fstate=$state/font
font_roles="ui serif mono term emoji"
font_sizes="ui mono term editor"

font_get() {
  local v
  v=$(awk -F= -v k="$1" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' "$fstate/state" 2>/dev/null || true)
  if [ -z "$v" ]; then
    v=$(awk -F= -v k="$1" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' <<<"$FONT_DEFAULTS")
  fi
  echo "$v"
}

font_put() {
  mkdir -p "$fstate"
  { grep -v "^$1=" "$fstate/state" 2>/dev/null || true; echo "$1=$2"; } >"$fstate/state.tmp"
  mv -f "$fstate/state.tmp" "$fstate/state"
}

# the catalog's family for ROLE matching NAME (any case), or nothing
font_find() {
  local role=$1
  [ "$role" = term ] && role=mono
  awk -F'\t' -v r="$role" -v n="${2,,}" '$1 == r && tolower($2) == n { print $2; exit }' <<<"$FONT_CATALOG"
}

# write a file only through a rename: watchers never see it half written
font_file() {
  mkdir -p "${1%/*}"
  cat >"$1.tmp.$$"
  mv -f "$1.tmp.$$" "$1"
}

# points to CSS pixels (96 dpi); a size with one decimal (awk: always a dot)
font_px() { awk -v p="$1" 'BEGIN { printf "%d", p * 4 / 3 + 0.5 }'; }
font_dec() { awk -v p="$1" 'BEGIN { printf "%.1f", p }'; }

# the generic families as chosen: font_fontconfig UI SERIF MONO EMOJI
font_fontconfig() {
  # binding "same": an app naming a font keeps it (a "strong" alias beat it,
  # as fontconfig adds monospace to any spacing=100 query)
  cat <<EOF
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <alias binding="same"><family>sans-serif</family><prefer><family>$1</family></prefer></alias>
  <alias binding="same"><family>system-ui</family><prefer><family>$1</family></prefer></alias>
  <alias binding="same"><family>serif</family><prefer><family>$2</family></prefer></alias>
  <alias binding="same"><family>monospace</family><prefer><family>$3</family></prefer></alias>
  <alias binding="same"><family>emoji</family><prefer><family>$4</family></prefer></alias>
  <!-- icons (private use area) and emoji before any other fallback: strong
       outranks the language match that let Latin fonts with their own glyphs
       there win (Cascadia NF, IBM Plex Sans TC, DejaVu); last, so a font asked
       by name still draws everything it has -->
  <match target="pattern">
    <edit name="family" mode="append_last" binding="strong">
      <string>Symbols Nerd Font</string>
      <string>$4</string>
    </edit>
  </match>
</fontconfig>
EOF
}

font_write() {
  local ui serif mono term emoji ui_size mono_size term_size editor_size px scale
  ui=$(font_get ui) serif=$(font_get serif) mono=$(font_get mono) term=$(font_get term) emoji=$(font_get emoji)
  ui_size=$(font_get ui_size) mono_size=$(font_get mono_size) term_size=$(font_get term_size) editor_size=$(font_get editor_size)
  px=$(font_px "$ui_size")

  font_fontconfig "$ui" "$serif" "$mono" "$emoji" | font_file "$fstate/fontconfig.conf"
  printf '[main]\nfont=%s:size=%s\n' "$term" "$term_size" | font_file "$fstate/foot.ini"
  printf 'font_family %s\nfont_size %s\n' "$term" "$term_size" | font_file "$fstate/kitty.conf"
  printf 'font-family = ""\nfont-family = "%s"\nfont-size = %s\n' "$term" "$term_size" | font_file "$fstate/ghostty"
  printf '[font]\nsize = %s\n[font.normal]\nfamily = "%s"\n' "$(font_dec "$term_size")" "$term" | font_file "$fstate/alacritty.toml"
  editor_size=$(font_dec "$editor_size")
  font_file "$fstate/emacs.el" <<EOF
(setq doom-font (font-spec :family "$mono" :size $editor_size)
      doom-variable-pitch-font (font-spec :family "$ui" :size $editor_size)
      doom-serif-font (font-spec :family "$serif" :size $editor_size))
(when (boundp 'doom-emoji-font) (setq doom-emoji-font (font-spec :family "$emoji")))
;; already running: switch now
(when (and after-init-time (fboundp 'doom/reload-font)) (doom/reload-font))
EOF
  # Chromium's fixed size keeps its default ratio to the normal one (13/16)
  printf '{"font":{"ui":"%s","serif":"%s","mono":"%s","size":%s,"fixedSize":%s}}\n' \
    "$ui" "$serif" "$mono" "$px" "$((px * 13 / 16))" | font_file "$state/font.json"
  # noctalia merges every *.toml of its folder, later names winning; the
  # bar and the panels (icons too) scale with the interface size, 12 being 1.0
  scale=$(awk -v s="$ui_size" 'BEGIN { printf "%.3f", s / 12 }')
  printf '[shell]\nfont_family = "%s"\n[accessibility]\nui_scale = %s\n[bar.main]\nscale = %s\n' \
    "$ui" "$scale" "$scale" | font_file "$HOME/.config/noctalia/font.toml"

  dconf write /org/gnome/desktop/interface/font-name "'$ui $ui_size'"
  dconf write /org/gnome/desktop/interface/document-font-name "'$serif $ui_size'"
  dconf write /org/gnome/desktop/interface/monospace-font-name "'$mono $mono_size'"
}

# open terminals: foot (overlays/patches/foot-osc50-font.patch) takes the font from
# OSC 50 written to its pty, also the one under a tmux client; the others
# ignore it and reload their files instead
font_osc() {
  local seq pts
  seq=$(printf '\033]50;%s:size=%s\007' "$(font_get term)" "$(font_get term_size)")
  for pts in /dev/pts/[0-9]*; do
    if [ -O "$pts" ] && [ -w "$pts" ]; then
      printf '%s' "$seq" | timeout 1 tee "$pts" >/dev/null 2>&1 || true
    fi
  done
}

# pieces of the files `theme` writes whole (settings.ini, qtct, Discord)
font_gtk_ini() { echo "gtk-font-name=$(font_get ui) $(font_get ui_size)"; }
font_qt_ini() {
  printf '\n[Fonts]\nfixed="%s,%s"\ngeneral="%s,%s"\n' \
    "$(font_get mono)" "$(font_get mono_size)" "$(font_get ui)" "$(font_get ui_size)"
}
font_discord_css() {
  local ui mono
  ui=$(font_get ui) mono=$(font_get mono)
  printf ':root {\n  --font-primary: "%s", sans-serif !important;\n  --font-display: "%s", sans-serif !important;\n  --font-headline: "%s", sans-serif !important;\n  --font-code: "%s", monospace !important;\n}\n' \
    "$ui" "$ui" "$ui" "$mono"
}

# fonts and icons as they are, "key=value" lines (the icons' ones prefixed)
font_snapshot() {
  local k
  for k in $font_roles; do echo "$k=$(font_get "$k")"; done
  for k in $font_sizes; do echo "${k}_size=$(font_get "${k}_size")"; done
  sed 's/^/icons./' "$istate" 2>/dev/null || true
}

# make fonts and icons what a snapshot on stdin says
font_restore() {
  local s
  s=$(cat)
  mkdir -p "$fstate"
  { grep -v '^icons\.' <<<"$s" || true; } | font_file "$fstate/state"
  { grep '^icons\.' <<<"$s" || true; } | sed 's/^icons\.//' | font_file "$istate"
}

# the user's own presets ("name<TAB>key=value" lines), whole snapshots
font_slot() { awk -F'\t' -v n="$1" '$1 == n { print $2 }' "$fstate/slots" 2>/dev/null || true; }

font_status() {
  local r
  for r in $font_roles; do printf '%-7s %s\n' "$r" "$(font_get "$r")"; done
  printf 'sizes   ui %s · mono %s · term %s · editor %s\n' \
    "$(font_get ui_size)" "$(font_get mono_size)" "$(font_get term_size)" "$(font_get editor_size)"
}

font_list() {
  local r current role
  for r in ${1:-$font_roles}; do
    current=$(font_get "$r")
    role=$r
    [ "$r" = term ] && role=mono
    echo "$r:"
    awk -F'\t' -v r="$role" -v c="$current" '$1 == r { printf "  %s %s\n", ($2 == c ? "*" : " "), $2 }' <<<"$FONT_CATALOG"
  done
}

font_usage() {
  echo "usage: theme font [status | list [ROLE] | ROLE FAMILY | size [ROLE] N|+N|-N | presets | preset NAME"
  echo "                   | save NAME | delete NAME | default [clear] | reset]"
  echo "  ROLE: $font_roles; size ROLE: $font_sizes (none: all)"
}

# `theme font ...`; returns 0 when something changed (apply it), 1 otherwise
font_cmd() {
  local r v new
  case "${1:-status}" in
    status) font_status; return 1 ;;
    list)
      if [ -n "${2:-}" ] && ! grep -qw -- "$2" <<<"$font_roles"; then font_usage >&2; exit 1; fi
      font_list "${2:-}"
      return 1
      ;;
    presets)
      awk -F'\t' '{ print $1 }' <<<"$FONT_PRESETS" | sort -u
      awk -F'\t' '!seen[$1]++ { print $1 " (yours)" }' "$fstate/slots" 2>/dev/null || true
      return 1
      ;;
    preset)
      v=$(font_slot "${2:-}")
      if [ -n "$v" ]; then
        font_restore <<<"$v"
      else
        v=$(awk -F'\t' -v p="${2:-}" '$1 == p { print $2 }' <<<"$FONT_PRESETS")
        [ -n "$v" ] || { echo "theme: no font preset '${2:-}' (theme font presets)" >&2; exit 1; }
        while IFS='=' read -r r new; do font_put "$r" "$new"; done <<<"$v"
      fi
      ;;
    save)
      [[ "${2:-}" =~ ^[[:alnum:]][[:alnum:]\ _.-]{0,23}$ ]] ||
        { echo "theme: a preset name has up to 24 letters, digits, spaces, _ . -" >&2; exit 1; }
      [ -z "$(awk -F'\t' -v p="$2" '$1 == p' <<<"$FONT_PRESETS")" ] ||
        { echo "theme: '$2' is a built-in preset" >&2; exit 1; }
      { awk -F'\t' -v n="$2" '$1 != n' "$fstate/slots" 2>/dev/null || true; font_snapshot | sed "s/^/$2\t/"; } |
        font_file "$fstate/slots"
      echo "saved preset '$2'"
      return 1
      ;;
    delete)
      [ -n "$(font_slot "${2:-}")" ] || { echo "theme: no preset of yours named '${2:-}'" >&2; exit 1; }
      awk -F'\t' -v n="$2" '$1 != n' "$fstate/slots" | font_file "$fstate/slots"
      return 1
      ;;
    # what reset goes back to: this snapshot, or the catalog's without one
    default)
      if [ "${2:-}" = clear ]; then
        rm -f "$fstate/default"
      else
        font_snapshot | font_file "$fstate/default"
        echo "fonts and icons as they are now are the default"
      fi
      return 1
      ;;
    reset)
      if [ -s "$fstate/default" ]; then
        font_restore <"$fstate/default"
      else
        rm -f "$fstate/state" "$istate"
      fi
      ;;
    size)
      shift
      local roles=$font_sizes
      if [ $# -ge 2 ]; then
        grep -qw -- "$1" <<<"$font_sizes" || { font_usage >&2; exit 1; }
        roles=$1
        shift
      fi
      [[ "${1:-}" =~ ^[+-]?[0-9]+(\.[0-9]+)?$ ]] || { font_usage >&2; exit 1; }
      for r in $roles; do
        new=$(awk -v c="$(font_get "${r}_size")" -v a="$1" 'BEGIN {
          v = (a ~ /^[+-]/) ? c + a : a + 0
          if (v < 5 || v > 48) exit 1
          printf "%g", v }') || { echo "theme: font sizes go from 5 to 48" >&2; exit 1; }
        font_put "${r}_size" "$new"
      done
      ;;
    *)
      grep -qw -- "$1" <<<"$font_roles" && [ -n "${2:-}" ] || { font_usage >&2; exit 1; }
      new=$(font_find "$1" "$2")
      [ -n "$new" ] || { echo "theme: '$2' is not a $1 font (theme font list $1)" >&2; exit 1; }
      font_put "$1" "$new"
      ;;
  esac
  return 0
}
