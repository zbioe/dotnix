# Commands used by the session's key binds
{ pkgs, term }:
{
  terminal = "uwsm app -- ${term} sh -c 'if [ -f ~/bin/start-tmux.sh ]; then bash ~/bin/start-tmux.sh; else tmux new-session -A -D -s main; fi'";

  toggleMic = pkgs.writeShellScript "toggle-mic" ''
    ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle

    STATUS=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SOURCE@)

    if [[ "$STATUS" == *"[MUTED]"* ]]; then
      echo 1 | sudo tee /sys/class/leds/platform::micmute/brightness
    else
      echo 0 | sudo tee /sys/class/leds/platform::micmute/brightness
    fi
  '';

  # region screenshot into satty (arrows, text, blur), then copy or save
  annotate = pkgs.writeShellScript "annotate-screenshot" ''
    area=$(${pkgs.slurp}/bin/slurp) || exit 0
    mkdir -p ~/Pictures/Screenshots
    ${pkgs.grim}/bin/grim -g "$area" - | ${pkgs.satty}/bin/satty --filename - \
      --copy-command ${pkgs.wl-clipboard}/bin/wl-copy --early-exit \
      --output-filename ~/Pictures/Screenshots/%Y-%m-%d_%H-%M-%S.png
  '';
}
