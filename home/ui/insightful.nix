{
  config,
  pkgs,
  lib,
  ...
}:

let
  proxyPython = pkgs.python3;
  containerName = "insightful-app";
  containerImage = "ubuntu:22.04";
  appImagePath = "${config.home.homeDirectory}/apps/insightful.AppImage";
  appDir = "${config.home.homeDirectory}/apps/insightful-root";
  username = config.home.username;

  insightful-desktop = pkgs.makeDesktopItem {
    name = "insightful";
    desktopName = "Insightful";
    exec = "${config.home.homeDirectory}/.local/bin/insightful";
    icon = "${appDir}/Workpuls.png";
    categories = [
      "Utility"
      "Office"
    ];
    comment = "Insightful time tracking";
    terminal = false;
  };

in
{
  home.packages = with pkgs; [
    proxyPython
    swayidle
    insightful-desktop
  ];

  home.file.".local/share/insightful-proxy/insightful-proxy.c" = {
    text = builtins.readFile ./insightful-proxy/insightful-proxy.c;
  };

  home.file.".local/share/insightful-proxy/insightful-daemon.py" = {
    executable = true;
    text = builtins.readFile ./insightful-proxy/insightful-daemon.py;
  };

  home.activation.insightfulContainer = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Bootstrap the Insightful distrobox container and app.
    # Idempotent: each step checks before acting.

    CONTAINER="${containerName}"
    IMAGE="${containerImage}"
    APPIMAGE="${appImagePath}"
    APPDIR="${appDir}"
    USERNAME="${username}"
    DOCKER="${pkgs.docker}/bin/docker"
    DISTROBOX="${pkgs.distrobox}/bin/distrobox"
    CURL="${pkgs.curl}/bin/curl"
    # distrobox needs standard utils (awk, rev, sed, grep, etc.)
    export PATH="${pkgs.docker}/bin:${pkgs.gawk}/bin:${pkgs.util-linux}/bin:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin:${pkgs.coreutils}/bin:${pkgs.findutils}/bin:/run/current-system/sw/bin:''$PATH"

    # 1. Create and initialize the distrobox container if it doesn't exist
    if ! ''$DOCKER ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "''$CONTAINER"; then
      echo "[Insightful] Creating distrobox container ''$CONTAINER..."
      ''$DISTROBOX create --yes --image "''$IMAGE" --name "''$CONTAINER" \
        --additional-packages "gcc libx11-dev libxss-dev libxext-dev libnss3 libatk-bridge2.0-0 libgtk-3-0 libasound2 libxcomposite1 libxdamage1 libxrandr2 libxfixes3 libpango-1.0-0 libcairo2"
      # First enter initializes user mapping, mounts, and installs additional-packages
      echo "[Insightful] Initializing container (first enter)..."
      ''$DISTROBOX enter "''$CONTAINER" -- true
      echo "[Insightful] Container ''$CONTAINER ready."
    fi

    # 2-3. Install build deps and input group (only if container is running)
    if ''$DOCKER ps --format '{{.Names}}' 2>/dev/null | grep -qx "''$CONTAINER"; then
      if ! ''$DOCKER exec "''$CONTAINER" dpkg -l gcc libnss3 2>/dev/null | grep -cq '^ii' | grep -q 2; then
        echo "[Insightful] Installing dependencies in ''$CONTAINER..."
        ''$DOCKER exec --user root "''$CONTAINER" \
          bash -c 'apt-get update -qq && apt-get install -y -qq gcc libx11-dev libxss-dev libxext-dev libnss3 libatk-bridge2.0-0 libgtk-3-0 libasound2 libxcomposite1 libxdamage1 libxrandr2 libxfixes3 libpango-1.0-0 libcairo2' \
          2>/dev/null || true
      fi
      if ! ''$DOCKER exec "''$CONTAINER" bash -c "getent group 174 2>/dev/null | grep -q ''$USERNAME" 2>/dev/null; then
        echo "[Insightful] Configuring input group in ''$CONTAINER..."
        ''$DOCKER exec --user root "''$CONTAINER" bash -c "
          groupadd -g 174 input 2>/dev/null || true
          usermod -aG input ''$USERNAME 2>/dev/null || true
        " 2>/dev/null || true
      fi
    fi

    # 4. Download AppImage if neither the AppImage nor the extracted app exist
    if [ ! -f "''$APPIMAGE" ] && [ ! -x "''$APPDIR/Workpuls" ]; then
      echo "[Insightful] Downloading Workpuls AppImage..."
      mkdir -p "$(dirname "''$APPIMAGE")"
      ''$CURL -L --progress-bar \
        "https://insightful-updates.io/linux/agent/latest/Workpuls.AppImage" \
        -o "''$APPIMAGE"
      chmod +x "''$APPIMAGE"
      echo "[Insightful] AppImage downloaded."
    fi

    # 5. Extract AppImage if not already extracted
    if [ ! -x "''$APPDIR/Workpuls" ] && [ -f "''$APPIMAGE" ]; then
      echo "[Insightful] Extracting AppImage to ''$APPDIR..."
      APPIMAGE_DIR="$(dirname "''$APPIMAGE")"
      cd "''$APPIMAGE_DIR"
      chmod +x "''$APPIMAGE"
      "''$APPIMAGE" --appimage-extract >/dev/null 2>&1 || true
      if [ -d "''$APPIMAGE_DIR/squashfs-root" ]; then
        mv "''$APPIMAGE_DIR/squashfs-root" "''$APPDIR"
        echo "[Insightful] AppImage extracted to ''$APPDIR."
      else
        echo "[Insightful] WARNING: AppImage extraction failed."
      fi
    fi
  '';

  home.file.".local/bin/insightful" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      # Ensure the distrobox container is running
      export PATH="${pkgs.gawk}/bin:${pkgs.util-linux}/bin:/run/current-system/sw/bin:$PATH"
      if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qx '${containerName}'; then
          echo "[Insightful] Starting container ${containerName}..."
          distrobox enter ${containerName} -- true
      fi

      LIB_DIR="$HOME/.local/share/insightful-proxy"
      LIB_NAME="libinsightful-proxy.so"
      SRC="$LIB_DIR/insightful-proxy.c"

      SRC_HASH="$(md5sum "$SRC" 2>/dev/null | cut -d' ' -f1)"
      HASH_FILE="$LIB_DIR/lib/.src_hash"
      PREV_HASH="$(cat "$HASH_FILE" 2>/dev/null || true)"

      build_library() {
          echo "[Insightful] Building LD_PRELOAD library..."
          distrobox enter ${containerName} -- bash -c "
              set -e
              mkdir -p $LIB_DIR/lib
              gcc -shared -fPIC -O2 \
                  -o $LIB_DIR/lib/$LIB_NAME \
                  $SRC \
                  -lX11 -lXss -ldl -lpthread
              echo '[Insightful] Build OK'
              ls -la $LIB_DIR/lib/$LIB_NAME
          "
          echo "$SRC_HASH" > "$HASH_FILE"
      }

      if [ ! -f "$LIB_DIR/lib/$LIB_NAME" ] || [ "$SRC_HASH" != "$PREV_HASH" ]; then
          build_library
      fi

      echo "[Insightful] Starting Workpuls..."

      exec distrobox enter ${containerName} -- bash -c "
          export LD_PRELOAD='$LIB_DIR/lib/$LIB_NAME'
          unset GIO_EXTRA_MODULES
          cd \"\$HOME/apps/insightful-root\"
          exec ./Workpuls --no-sandbox >/dev/null 2>&1
      "
    '';
  };

  systemd.user.services.insightful-proxy-daemon = {
    Unit = {
      Description = "Insightful Proxy - Hyprland window + activity bridge for Workpuls";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${proxyPython}/bin/python %h/.local/share/insightful-proxy/insightful-daemon.py";
      Restart = "always";
      RestartSec = 3;
      Environment = [ "DISPLAY=:0" ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
