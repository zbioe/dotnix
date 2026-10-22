# `theme`: switches the theme of everything live (home/theme). The variables
# in capitals and the font and icon commands come first, from default.nix.
mkdir -p "$state"
cmd="theme $*"

# one change at a time: a second `theme` waits for the first, so the
# state (and the boot splash synced from it) ends at the last choice
case "${1:-status}" in
  list | status | icon | entries) ;;
  *)
    exec 8>"$state/.lock"
    if [ "${1:-}" = noctalia-mode ]; then
      # busy means it is our own `theme-mode-set` echoing back
      flock -n 8 || exit 0
    else
      flock 8
    fi
    ;;
esac

name=$(cat "$state/name" 2>/dev/null || echo "$THEME_DEFAULT_NAME")
mode=$(cat "$state/mode" 2>/dev/null || echo "$THEME_DEFAULT_MODE")

usage() {
  echo "usage: theme [list | status | set NAME [dark|light] | mode dark|light | toggle | auto [on|off|toggle] | entries | pick LINE | apply | font ... | icons ...]"
}


# today's sunrise and sunset ("HH:MM HH:MM", local time) at the position
# in $state/location ("LAT LON", written by the locator); the fixed
# theme.auto times without a position or near the poles
sun() {
  local lat lon times=""
  if read -r lat lon 2>/dev/null < "$state/location"; then
    times=$(awk -v lat="$lat" -v lon="$lon" -v doy="$(date +%j)" -v tz="$(date +%z)" '
      BEGIN {
        pi = atan2(0, -1); r = pi / 180; g = 2 * pi / 365 * (doy - 1)
        eq = 229.18 * (0.000075 + 0.001868 * cos(g) - 0.032077 * sin(g) \
          - 0.014615 * cos(2 * g) - 0.040849 * sin(2 * g))
        d = 0.006918 - 0.399912 * cos(g) + 0.070257 * sin(g) - 0.006758 * cos(2 * g) \
          + 0.000907 * sin(2 * g) - 0.002697 * cos(3 * g) + 0.00148 * sin(3 * g)
        x = cos(90.833 * r) / (cos(lat * r) * cos(d)) - sin(lat * r) / cos(lat * r) * sin(d) / cos(d)
        if (x > 1 || x < -1) exit
        ha = atan2(sqrt(1 - x * x), x) / r
        off = (substr(tz, 1, 1) == "-" ? -1 : 1) * (substr(tz, 2, 2) * 60 + substr(tz, 4, 2))
        rise = (720 - 4 * (lon + ha) - eq + off + 1440) % 1440
        set = (720 - 4 * (lon - ha) - eq + off + 1440) % 1440
        printf "%02d:%02d %02d:%02d\n", rise / 60, rise % 60, set / 60, set % 60
      }')
  fi
  echo "${times:-$THEME_SUNRISE $THEME_SUNSET}"
}

# atomic symlink swap: inotify sees a rename, never a missing file
swap() {
  ln -sfn "$1" "$2.tmp.$$"
  mv -Tf "$2.tmp.$$" "$2"
}

# settings.ini: what GTK reads without dconf (Electron, Chromium,
# XWayland and unwrapped apps), with this theme instead of a fixed one
gtk_settings() {
  for g in 3 4; do
    f=$HOME/.config/gtk-$g.0/settings.ini
    mkdir -p "${f%/*}"
    {
      grep -v '^gtk-theme-name=\|^gtk-icon-theme-name=\|^gtk-application-prefer-dark-theme=' \
        "$GTK_SETTINGS/gtk-$g.0.ini"
      echo "gtk-theme-name=nix-$name-$mode"
      echo "gtk-icon-theme-name=$(icon_apps_theme "$mode")"
      # GTK4 has no dark variants of a named theme (libadwaita warns)
      if [ "$g" = 3 ]; then
        echo "gtk-application-prefer-dark-theme=$([ "$mode" = dark ] && echo 1 || echo 0)"
      fi
      font_gtk_ini
    } > "$f.tmp.$$"
    mv -f "$f.tmp.$$" "$f"
  done
}

# Qt: qt5ct/qt6ct reload when their config directory changes; a fresh
# copy, not a store link: QSettings caches by size+mtime and every store
# file has the same mtime
qt_conf() {
  for qt in qt5ct qt6ct; do
    mkdir -p "$HOME/.config/$qt"
    {
      sed "s/^icon_theme=.*/icon_theme=$(icon_apps_theme "$mode")/" "$state/current/$qt.conf"
      font_qt_ini
    } > "$HOME/.config/$qt/$qt.conf.tmp.$$"
    mv -f "$HOME/.config/$qt/$qt.conf.tmp.$$" "$HOME/.config/$qt/$qt.conf"
  done
}

# Discord (Vencord watches its themes folder); a real file, not a link
discord_css() {
  if [ -d "$HOME/.config/Vencord/themes" ]; then
    { cat "$state/current/discord.css"; font_discord_css; } > "$HOME/.config/Vencord/themes/.nix-theme.css.$$"
    mv -f "$HOME/.config/Vencord/themes/.nix-theme.css.$$" "$HOME/.config/Vencord/themes/nix-theme.css"
  fi
}

# kitty/ghostty: reload config (open windows already got the palette)
reload_terminals() {
  pkill -USR1 -f '^([^ ]*/)?\.?kitty(-wrapped)?( |$)' || true
  pkill -USR2 -f '^([^ ]*/)?\.?ghostty(-wrapped)?( |$)' || true
}

apply() {
  local v="$index/$name-$mode"
  if [ ! -d "$v" ]; then
    # single-mode themes (zenburn): keep the mode they have
    if [ "$mode" = dark ]; then mode=light; else mode=dark; fi
    v="$index/$name-$mode"
  fi
  if [ ! -d "$v" ]; then
    echo "theme: no theme '$name'" >&2
    exit 1
  fi
  echo "$name" > "$state/name"
  echo "$mode" > "$state/mode"
  # the pair in one file, last: what the boot screens follow
  # (system/desktop/boot-screens.nix), never half of a change
  echo "$name-$mode" > "$state/boot.tmp"
  mv -f "$state/boot.tmp" "$state/boot"
  # who changed it, for when the theme is not the expected one
  logger -t theme "$name-$mode ($cmd, from $(ps -o args= -p "$PPID" 2>/dev/null | cut -c1-100))" || true
  swap "$v" "$state/current"
  font_write
  icon_write

  # GTK4/libadwaita (patched gtk reloads it live)
  mkdir -p "$HOME/.config/gtk-4.0"
  swap "$v/gtk4.css" "$HOME/.config/gtk-4.0/gtk.css"

  gtk_settings

  # GTK3, plain GTK4, icons, and the dark/light preference (portal, browsers)
  dconf write /org/gnome/desktop/interface/color-scheme "'prefer-$mode'"
  dconf write /org/gnome/desktop/interface/gtk-theme "'nix-$name-$mode'"
  dconf write /org/gnome/desktop/interface/icon-theme "'$(icon_apps_theme "$mode")'"

  # running terminals (foot directly, tmux panes via their own pty)
  for pts in /dev/pts/[0-9]*; do
    if [ -O "$pts" ] && [ -w "$pts" ]; then
      timeout 1 cp "$v/terminal.seq" "$pts" 2>/dev/null || true
    fi
  done

  # running fish shells: a universal variable change fires their handler
  fish -c "set -U __nix_theme $name-$mode-$(date +%s%N)" 2>/dev/null || true

  if command -v emacsclient >/dev/null; then
    timeout 5 emacsclient --eval "(load \"$v/emacs.el\" nil t)" >/dev/null 2>&1 || true
  fi

  # running neovims listen on $XDG_RUNTIME_DIR/nvim.*.0
  for sock in "${XDG_RUNTIME_DIR:-/run/user/$UID}"/nvim.*.0; do
    [ -S "$sock" ] || continue
    timeout 2 nvim --server "$sock" --remote-send "<Cmd>luafile $v/nvim.lua<CR>" >/dev/null 2>&1 || true
  done

  qt_conf
  discord_css
  reload_terminals

  # mango session: border colors; noctalia: palette and mode
  mmsg dispatch reload_config >/dev/null 2>&1 || true
  if command -v noctalia >/dev/null && noctalia msg theme-mode-get >/dev/null 2>&1; then
    noctalia msg color-scheme-set custom "nix-$name" >/dev/null 2>&1 || true
    noctalia msg wallpaper-set "$v/wallpaper.png" >/dev/null 2>&1 || true
    [ "$(noctalia msg theme-mode-get 2>/dev/null)" = "$mode" ] ||
      noctalia msg theme-mode-set "$mode" >/dev/null 2>&1 || true
  fi

  # Brave (pkgs/brave-theme): the palette's theme pack into the folder
  # its theme extension is installed from; running, it rereads it when
  # the reload service (system/desktop/browsers/brave.nix) toggles its theme policy
  if [ -d "$v/brave-theme" ]; then
    mkdir -p "$state/brave-theme"
    for f in manifest.json "Cached Theme.pak"; do
      install -m 644 "$v/brave-theme/$f" "$state/brave-theme/.$f.$$"
      mv -f "$state/brave-theme/.$f.$$" "$state/brave-theme/$f"
    done
    if pgrep -u "$(id -u)" -x brave >/dev/null && [ -w /run/nix-theme ]; then
      cat "$v/brave-color" > /run/nix-theme/brave-reload
    fi
  fi
}

case "${1:-status}" in
  list)
    find -L "$index" -mindepth 1 -maxdepth 1 -printf '%f\n' | sed -E 's/-(dark|light)$//' | sort -u
    ;;
  status)
    echo "$name $mode"
    ;;
  icon)
    if [ "$mode" = dark ]; then echo "󰖔"; else echo "󰖨"; fi
    ;;
  set)
    name=${2:?$(usage)}
    mode=${3:-$mode}
    apply
    ;;
  # noctalia's theme_mode_changed hook (home/desktop/noctalia): its own
  # Light/Dark switch; a stale event (noctalia already moved on) is
  # dropped, so it can never undo a newer choice
  noctalia-mode)
    [ "${2:?$(usage)}" = "$mode" ] && exit 0
    [ "$(noctalia msg theme-mode-get 2>/dev/null)" = "$2" ] || exit 0
    echo off > "$state/auto"
    mode=$2
    apply
    ;;
  mode)
    [ "${2:?$(usage)}" = "$mode" ] && exit 0
    echo off > "$state/auto" # a manual choice ends the day/night schedule
    mode=$2
    apply
    ;;
  toggle)
    echo off > "$state/auto"
    if [ "$mode" = dark ]; then mode=light; else mode=dark; fi
    apply
    ;;
  auto)
    case "${2:-toggle}" in
      on | off) auto=$2 ;;
      *) if [ "$(cat "$state/auto" 2>/dev/null)" = on ]; then auto=off; else auto=on; fi ;;
    esac
    echo "$auto" > "$state/auto"
    if [ "$auto" = on ]; then exec "$0" auto-tick; fi
    ;;
  # light between sunrise and sunset, dark otherwise; run at login and
  # at each transition (a transient timer armed here, see theme-auto-next)
  auto-tick)
    [ "$(cat "$state/auto" 2>/dev/null)" = on ] || exit 0
    read -r rise set < <(sun)
    echo "$rise $set" > "$state/sun"
    now=$(date +%H%M)
    if [ "$now" -ge "${rise/:/}" ] && [ "$now" -lt "${set/:/}" ]; then
      want=light next=$set
    else
      want=dark next=$rise
    fi
    systemctl --user stop theme-auto-next.timer 2>/dev/null || true
    systemd-run --user --quiet --unit=theme-auto-next --on-calendar="*-*-* $next:00" || true
    [ "$want" = "$mode" ] && exit 0
    mode=$want
    apply
    ;;
  # noctalia launcher provider (/theme): "title<TAB>description" lines
  entries)
    auto=$(cat "$state/auto" 2>/dev/null || echo off)
    current() { [ "$1" = yes ] && printf ' · current'; }
    printf 'Light\tlight mode%s\n' "$(current "$([ "$auto" != on ] && [ "$mode" = light ] && echo yes)")"
    printf 'Dark\tdark mode%s\n' "$(current "$([ "$auto" != on ] && [ "$mode" = dark ] && echo yes)")"
    read -r rise set < <(sun)
    printf 'Auto\tlight at %s, dark at %s · %s\n' "$rise" "$set" "$([ "$auto" = on ] && echo on || echo off)"
    "$0" list | while read -r t; do
      printf '%s\ttheme%s\n' "$t" "$(current "$([ "$t" = "$name" ] && echo yes)")"
    done
    ;;
  pick)
    choice=${2:?$(usage)}
    choice=${choice%%$'\t'*}
    case "$choice" in
      Light) exec "$0" mode light ;;
      Dark) exec "$0" mode dark ;;
      Auto) exec "$0" auto toggle ;;
      *)
        name=$choice
        apply
        ;;
    esac
    ;;
  apply)
    apply
    ;;
  # the tags' icons (home/theme/icons): only the bar changes
  icons)
    shift
    if icon_cmd "$@"; then
      icon_write
      gtk_settings
      qt_conf
      dconf write /org/gnome/desktop/interface/icon-theme "'$(icon_apps_theme "$mode")'"
      icon_status
    fi
    ;;
  # fonts apply on their own: the colors stay as they are
  font)
    shift
    if font_cmd "$@"; then
      font_write
      icon_write
      gtk_settings
      qt_conf
      discord_css
      reload_terminals
      font_osc
      if command -v emacsclient >/dev/null; then
        timeout 5 emacsclient --eval "(load \"$fstate/emacs.el\" nil t)" >/dev/null 2>&1 || true
      fi
      font_status
    fi
    ;;
  *)
    usage
    exit 1
    ;;
esac
