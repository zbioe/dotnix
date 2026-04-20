{
  config,
  pkgs,
  lib,
  ...
}:

let
  containerName = "trae-box";
  containerImage = "ubuntu:24.04";
  username = config.home.username;

  # Create the application shortcut natively in NixOS
  trae-desktop = pkgs.makeDesktopItem {
    name = "trae";
    desktopName = "Trae IDE";
    # %U allows opening directories and files via terminal or file manager
    exec = "${config.home.homeDirectory}/.local/bin/trae %U";
    icon = "trae";
    categories = [
      "Development"
      "IDE"
      "Utility"
    ];
    comment = "Trae - AI-powered IDE";
    terminal = false;
  };

in
{
  home.packages = with pkgs; [
    trae-desktop
  ];

  home.activation.traeContainer = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Bootstrap the Trae IDE distrobox container using the stable 22.04 image.
    # Idempotent: checks state before executing.

    CONTAINER="${containerName}"
    IMAGE="ubuntu:22.04"
    USERNAME="${username}"
    DOCKER="docker"
    DISTROBOX="distrobox"

    # Inject essential host binaries into the local PATH for the activation script
    export PATH="${pkgs.docker}/bin:${pkgs.gawk}/bin:${pkgs.util-linux}/bin:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin:${pkgs.coreutils}/bin:${pkgs.findutils}/bin:/run/current-system/sw/bin:''$PATH"

    # 1. Create and initialize the container if it doesn't exist
    if ! ''$DOCKER ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "''$CONTAINER"; then
      echo "[Trae] Creating distrobox container ''$CONTAINER..."

      # Clean creation without DNS hacks
      ''$DISTROBOX create --yes --image "''$IMAGE" --name "''$CONTAINER" \
        --additional-packages "wget curl ca-certificates libnss3 libatk-bridge2.0-0 libgtk-3-0 libasound2 libx11-xcb1 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libdrm2"

      echo "[Trae] Initializing container (first run)..."
      ''$DISTROBOX enter "''$CONTAINER" -- true
      echo "[Trae] Container ''$CONTAINER ready."
    fi

    # 2. Check if Trae exists; if not, install via local .deb
    if ''$DOCKER ps --format '{{.Names}}' 2>/dev/null | grep -qx "''$CONTAINER"; then
      if ! ''$DISTROBOX enter "''$CONTAINER" -- which trae >/dev/null 2>&1; then
        echo "[Trae] Trae is not installed in the container."

        # Pointing to the .deb file in your host apps directory
        DEB_PATH="$HOME/apps/trae.deb"

        if [ -f "''$DEB_PATH" ]; then
          echo "[Trae] Installing ''$DEB_PATH inside the container..."

          # Copy the .deb to /tmp inside the container to bypass the _apt user permission drop on host directories
          ''$DISTROBOX enter "''$CONTAINER" -- cp "''$DEB_PATH" /tmp/trae.deb

          # Use absolute path for apt-get to prevent NixOS $PATH leakage into the container's sudo environment
          ''$DISTROBOX enter "''$CONTAINER" -- sudo /usr/bin/apt-get update -qq
          ''$DISTROBOX enter "''$CONTAINER" -- sudo /usr/bin/apt-get install -y /tmp/trae.deb

          # Clean up the temporary file
          ''$DISTROBOX enter "''$CONTAINER" -- rm /tmp/trae.deb

          echo "[Trae] Installation complete."

          # 3. Extract the icon from the container to the host for desktop integration
          ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"
          mkdir -p "''$ICON_DIR"

          ''$DISTROBOX enter "''$CONTAINER" -- cat /usr/share/icons/hicolor/512x512/apps/trae.png > "''$ICON_DIR/trae.png" 2>/dev/null || \
          ''$DISTROBOX enter "''$CONTAINER" -- cat /usr/share/pixmaps/trae.png > "''$ICON_DIR/trae.png" 2>/dev/null || true

        else
          echo "[Trae] WARNING: ''$DEB_PATH not found!"
        fi
      fi
    fi
  '';

  # The native wrapper script
  home.file.".local/bin/trae" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      # Define absolute paths
      DOCKER="${pkgs.docker}/bin/docker"
      DISTROBOX="${pkgs.distrobox}/bin/distrobox"

      # Ensure container is running
      if ! $DOCKER ps --format '{{.Names}}' 2>/dev/null | grep -qx '${containerName}'; then
          echo "[Trae] Starting container ${containerName}..."
          $DISTROBOX enter ${containerName} -- true
      fi

      # Execute Trae
      exec $DISTROBOX enter ${containerName} -- /usr/bin/trae \
        --enable-features=UseOzonePlatform \
        --ozone-platform=wayland \
        "$@"
    '';
  };
}
