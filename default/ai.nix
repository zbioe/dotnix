{
  config,
  lib,
  unstable,
  trae-deb,
  ...
}:

let
  trae-bin = unstable.stdenv.mkDerivation {
    name = "trae-ide";
    version = "latest";
    src = trae-deb;
    nativeBuildInputs = [ unstable.dpkg ];
    unpackPhase = ''
      mkdir -p $out
      # Extrai o .deb direto para a raiz do pacote no Nix Store
      dpkg -x $src $out
    '';
    installPhase = "true";
  };
  trae-fhs = unstable.buildFHSUserEnv {
    name = "trae-ide";
    targetPkgs =
      pkgs:
      (with pkgs; [
        wayland
        libglvnd
        vulkan-loader
        mesa
        udev
        xdg-utils
        dbus
        libnotify
        libsecret
        curl
        openssl
        nss
        nspr
        fontconfig
        freetype
        cairo
        pango
        gtk3
        glib
        gdk-pixbuf
        libxkbcommon
        alsa-lib
        expat
        libuuid
        xorg.libX11
        xorg.libXcomposite
        xorg.libXdamage
        xorg.libXext
        xorg.libXfixes
        xorg.libXi
        xorg.libXrandr
        xorg.libXrender
        xorg.libxcb
        xorg.libxkbfile
        xorg.libxshmfence
      ]);
    runScript = "bash -c 'exec ${trae-bin}/opt/Trae/trae --enable-features=UseOzonePlatform,WaylandWindowDecorations --ozone-platform-hint=auto --enable-wayland-ime --ignore-gpu-blocklist --enable-zero-copy'";
  };
in
{
  environment.systemPackages = with unstable; [

    # AI tools
    harbor-cli

    # AI agents
    gemini-cli

    # AI editors
    zed-editor
    code-cursor
    claude-code
    opencode
    antigravity
    trae-fhs
  ];

  # services
  services.ollama = {
    enable = true;
    host = "0.0.0.0";
  };
  services.open-webui = {
    enable = true;
    port = 3333;
    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
      WEBUI_AUTH = "False";
    };
  };
}
