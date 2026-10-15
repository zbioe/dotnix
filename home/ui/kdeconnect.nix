{ pkgs, ... }:
let
  kdeconnect-browse = pkgs.writeShellScriptBin "kdeconnect-browse" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    DEVICE_INFO=$(${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnect-cli -l 2>/dev/null || true)

    if [ -z "$DEVICE_INFO" ]; then
      notify-send "KDE Connect" "No devices found"
      exit 1
    fi

    DEVICE_ID=$(echo "$DEVICE_INFO" | grep -E "reachable|acessível" | sed -n 's/.*: \([a-f0-9]\+\) .*/\1/p' | head -1)

    if [ -z "$DEVICE_ID" ]; then
      notify-send "KDE Connect" "No reachable device found"
      exit 1
    fi

    ${pkgs.kdePackages.kdeconnect-kde}/bin/kdeconnect-cli -d "$DEVICE_ID" --mount >/dev/null 2>&1 || true

    BASE="/run/user/$(id -u)/$DEVICE_ID"

    for i in {1..15}; do
      [ -d "$BASE" ] && break
      sleep 0.2
    done

    if [ ! -d "$BASE" ]; then
      notify-send "KDE Connect" "Failed to mount device"
      exit 1
    fi

    TARGET=""
    for candidate in \
      "$BASE/storage/emulated/0" \
      "$BASE/sdcard" \
      "$BASE/storage/self/primary" \
      "$BASE"; do
      if [ -d "$candidate" ] && [ -r "$candidate" ]; then
        if ls "$candidate" >/dev/null 2>&1; then
          TARGET="$candidate"
          break
        fi
      fi
    done

    if [ -z "$TARGET" ]; then
      notify-send "KDE Connect" "Could not find a readable storage path"
      exit 1
    fi

    ${pkgs.nautilus}/bin/nautilus "$TARGET"
  '';
in
{
  services.kdeconnect = {
    enable = true;
    indicator = true;
  };

  home.sessionVariables = {
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_STYLE_OVERRIDE = "Fusion";
    QT_QUICK_CONTROLS_STYLE = "org.kde.desktop";

  };

  home.packages =
    with pkgs;
    [
      qt6Packages.qt6ct
      kdePackages.qqc2-desktop-style
      xdotool
    ]
    ++ [ kdeconnect-browse ];

  home.file.".local/share/applications/kdeconnect-browse.desktop".text = ''
    [Desktop Entry]
    Name=KDE Connect Browse
    Exec=${kdeconnect-browse}/bin/kdeconnect-browse %u
    Type=Application
    MimeType=x-scheme-handler/kdeconnect;
    Terminal=false
    Categories=Utility;
  '';

  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/kdeconnect" = [ "kdeconnect-browse.desktop" ];
  };
}
