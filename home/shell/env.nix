# ~/.env (secrets, tokens) exported in every shell
{
  programs.bash.profileExtra = ''
    if [ -f "$HOME/.env" ]; then
      set -a
      source "$HOME/.env"
      set +a
    fi
  '';

  programs.bash.bashrcExtra = ''
    if [ -f "$HOME/.env" ]; then
      set -a
      source "$HOME/.env"
      set +a
    fi
  '';

  programs.fish.interactiveShellInit = ''
    if test -f "$HOME/.env"
      while read -l line
        # skip comments (#) and empty lines
        if not string match -q -r '^\s*#|^\s*$' "$line"
          # split at the first '='
          set -l kv (string split -m 1 "=" "$line")
          # export, without the quotes the .env value may have
          set -gx $kv[1] (string trim -c '"\''' $kv[2])
        end
      end < "$HOME/.env"
    end
  '';
}
