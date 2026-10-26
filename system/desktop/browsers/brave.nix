# Brave rereads its theme when a policy flips: root's side of Brave following `theme`
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.dotnix.desktop.browsers.brave.enable {
  # Brave's own policies stay off: the theme reload below writes the only one
  programs.chromium.extraOpts = lib.mkForce { };

  # Brave live on `theme` (pkgs/brave-theme): Brave rereads its theme pack
  # from disk when its BrowserThemeColor policy is unset, so on each request
  # (the palette's background, written by `theme` to /run/nix-theme) this
  # sets the policy until Brave has read it (it rereads the folder some
  # seconds after a change) and takes it back.
  environment.etc."brave/policies/managed/nix-theme.json".text = "{}";
  systemd.tmpfiles.rules = [ "d /run/nix-theme 0755 ${config.dotnix.core.user.name} users -" ];
  systemd.paths.brave-theme-reload = {
    wantedBy = [ "paths.target" ];
    pathConfig.PathModified = "/run/nix-theme/brave-reload";
  };
  systemd.services.brave-theme-reload = {
    description = "Reload Brave's theme pack";
    serviceConfig.Type = "oneshot";
    path = with pkgs; [
      inotify-tools
      procps
    ];
    script = ''
      color=$(head -c 7 /run/nix-theme/brave-reload)
      [[ $color =~ ^#[0-9a-fA-F]{6}$ ]] || exit 0
      # (not running: it reads the new pack when it starts)
      pgrep -x brave >/dev/null || exit 0
      policy=/etc/brave/policies/managed/nix-theme-reload.json
      tmp=$(mktemp /etc/brave/.nix-theme-reload.XXXXXX)
      printf '{"BrowserThemeColor": "%s"}\n' "$color" > "$tmp"
      chmod 644 "$tmp"
      exec {events}< <(exec inotifywait -m -e close_nowrite --format %f /etc/brave/policies/managed 2>&1)
      watch=$!
      name=""
      until [ "$name" = "Watches established." ]; do read -r name <&"$events"; done
      mv -f "$tmp" "$policy"
      while read -r -t 30 name <&"$events" && [ "$name" != "''${policy##*/}" ]; do :; done
      kill $watch
      rm -f "$policy"
    '';
  };
}
