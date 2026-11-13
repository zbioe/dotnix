# GDM, the login screen: the fingerprint and the password at once (each in
# a PAM stack of its own), themed like the user's session without
# rebuilding gnome-shell. Its shell runs a session mode of ours (parent
# gdm) whose stylesheet isn't in the compiled resource, so gnome-shell
# finds it in the data dirs: a link to /var/lib/dotnix-gdm, where a
# sandboxed service copies the user's current theme (its gdm.css and
# wallpaper, home/theme) and font whenever `theme` switches them. The
# login screen shows them the next time it comes up.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dotnix.desktop;
  user = config.dotnix.core.user.name;
  home = config.users.users.${user}.home;
  dir = "/var/lib/dotnix-gdm";
  themeState = "${home}/.local/state/theme";

  mode = pkgs.runCommand "dotnix-gdm-mode" { } ''
    mkdir -p $out/share/gnome-shell/modes $out/share/gnome-shell/theme
    echo '{ "parentMode": "gdm", "stylesheetName": "dotnix-gdm.css" }' \
      > $out/share/gnome-shell/modes/dotnix-gdm.json
    # gnome-shell tries the -dark/-light variant first, then the name
    for v in "" -dark -light; do
      ln -s ${dir}/gnome-shell.css $out/share/gnome-shell/theme/dotnix-gdm$v.css
    done
  '';

  # the theme's files are store paths (trusted); only the font name comes
  # from the user as text, so it must look like a font name
  sync = pkgs.writeShellApplication {
    name = "dotnix-gdm-sync";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
    ];
    text = ''
      theme=$(readlink -f ${themeState}/current) || exit 0
      case "$theme" in /nix/store/*) ;; *) echo "not a store path: $theme" >&2; exit 1 ;; esac
      [ -f "$theme/gdm.css" ] && [ -f "$theme/wallpaper.png" ] || exit 0
      font=$(jq -r '.font.ui // empty' ${themeState}/font.json 2>/dev/null || true)
      [[ "$font" =~ ^[A-Za-z0-9\ ._-]{1,64}$ ]] || font=""
      tmp=$(mktemp -d ${dir}/.sync.XXXXXX)
      {
        cat "$theme/gdm.css"
        [ -n "$font" ] && printf '\nstage { font-family: "%s"; }\n' "$font"
      } > "$tmp/gnome-shell.css"
      cp "$theme/wallpaper.png" "$tmp/wallpaper.png"
      chmod 0644 "$tmp"/*
      mv -f "$tmp/gnome-shell.css" ${dir}/gnome-shell.css
      mv -f "$tmp/wallpaper.png" ${dir}/wallpaper.png
      rmdir "$tmp"
    '';
  };
in
lib.mkIf (cfg.enable && cfg.greeter == "gdm") {
  services.displayManager.gdm = {
    enable = true;
    wayland = true;
    # the greeter only looks in these (and gnome-shell's own) data dirs
    extraPackages = [ mode ];
  };
  security.pam.services.gdm-password.enableGnomeKeyring = cfg.secrets == "gnome-keyring";

  # the greeter's shell (org.gnome.Shell@gdm, run by GDM's dynamic greeter
  # user) in our mode
  systemd.user.services."org.gnome.Shell@gdm".serviceConfig.ExecStart = [
    ""
    "${pkgs.gnome-shell}/bin/gnome-shell --mode=dotnix-gdm"
  ];

  programs.dconf.profiles.gdm.databases = [
    {
      settings = {
        # the laptop's layout first, the external keyboard's a switch away
        # (Super+Space): one layout for every keyboard there
        "org/gnome/desktop/input-sources".sources = [
          (lib.gvariant.mkTuple [
            "xkb"
            "br+thinkpad"
          ])
          (lib.gvariant.mkTuple [
            "xkb"
            "us+intl"
          ])
        ];
      };
    }
  ];

  systemd.tmpfiles.rules = [ "d ${dir} 0755 root root -" ];

  # at boot and whenever `theme` switches (its state folder changes)
  systemd.services.dotnix-gdm-sync = {
    description = "The login screen in the user's theme";
    wantedBy = [ "multi-user.target" ];
    before = [ "display-manager.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe sync;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = [ dir ];
      PrivateNetwork = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
      CapabilityBoundingSet = "";
      RestrictAddressFamilies = "none";
      SystemCallFilter = "@system-service";
    };
  };
  systemd.paths.dotnix-gdm-sync = {
    wantedBy = [ "multi-user.target" ];
    pathConfig = {
      PathChanged = [
        "${themeState}/current"
        "${themeState}/font.json"
      ];
      TriggerLimitIntervalSec = "5s";
    };
  };
}
