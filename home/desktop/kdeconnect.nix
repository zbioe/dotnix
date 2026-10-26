{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
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

    # returns once mounted
    sftp=(org.kde.kdeconnect "/modules/kdeconnect/devices/$DEVICE_ID/sftp" org.kde.kdeconnect.device.sftp)
    if [ "$(${pkgs.systemd}/bin/busctl --user call "''${sftp[@]}" mountAndWait)" != "b true" ]; then
      notify-send "KDE Connect" "Failed to mount device"
      exit 1
    fi
    BASE=$(${pkgs.systemd}/bin/busctl --user call "''${sftp[@]}" mountPoint | sed -n 's/^s "\(.*\)"$/\1/p')

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
  options.dotnix.desktop.kdeconnect.enable = lib.mkEnableOption "KDE Connect helpers" // {
    default = osConfig.dotnix.services.kdeconnect.enable;
  };

  config = lib.mkIf config.dotnix.desktop.kdeconnect.enable {
    services.kdeconnect = {
      enable = true;
      indicator = true;
    };
    # home-manager's PATH (the home profile alone) has no xdg-open: Browse
    # (kdeconnect://) failed with "Unable to detect a web browser"
    systemd.user.services.kdeconnect.Service.Environment = lib.mkForce [
      "PATH=${config.home.profileDirectory}/bin:/run/wrappers/bin:/run/current-system/sw/bin"
    ];

    # the Bluetooth backend publishes an SPP record; headsets that probe SPP
    # (aiwa AW-ANC45F) hit its MITM requirement and the whole link drops
    home.activation.kdeconnectNoBluetooth = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${config.xdg.configHome}/kdeconnect
      run ${pkgs.crudini}/bin/crudini --ini-options=nospace --set \
        ${config.xdg.configHome}/kdeconnect/config General disabled_providers AsyncLinkProvider
    '';

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
  };
}
