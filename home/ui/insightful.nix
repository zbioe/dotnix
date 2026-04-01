{
  pkgs,
  config,
  unstable,
  ...
}:
let
  insightful-app = pkgs.appimage-run.override {
    extraPkgs =
      pkgs: with pkgs; [
        libsecret
        xorg.libX11
        xorg.libxcb
        xorg.libXcomposite
        xorg.libXcursor
        xorg.libXdamage
        xorg.libXext
        xorg.libXfixes
        xorg.libXi
        xorg.libXrender
        xorg.libXtst
        nss
        nspr
        alsa-lib
        mesa
      ];
  };
  insightful-wrapper = pkgs.writeShellScriptBin "insightful" ''
    APP_PATH="$HOME/apps/insightful.AppImage"

    if [ -f "$APP_PATH" ]; then
      exec ${insightful-app}/bin/appimage-run "$APP_PATH" "$@"
    else
      echo "no insightful on $APP_PATH"
      exit 0
    fi
  '';
  insightful-desktop = pkgs.makeDesktopItem {
    name = "insightful";
    desktopName = "Insightful";
    exec = "${insightful-wrapper}/bin/insightful";
    icon = "utilities-system-monitor";
    comment = "Corp Monitoring";
    categories = [
      "Utility"
      "Office"
    ];
    terminal = false;
  };
in

{
  home.packages = with pkgs; [
    insightful-wrapper
    insightful-desktop
  ];
}
