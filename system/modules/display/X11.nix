{ config, pkgs, lib, ... }:

let
  # gdm theme
  simplicity = pkgs.stdenv.mkDerivation rec {
    name = "simplicity";
    src = pkgs.fetchFromGitHub {
      owner = "zbioe";
      repo = "simplicity-sddm-theme";
      rev = "9c1e7d72e27a4eda0e09fb18a2b542bece472dbd";
      sha256 = "171ab5i593izfz05ji6k358ncd0n6irqxv16a7w2d38xgv247gbn";
    };
    # dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/sddm/themes/
      echo $out
      cp -r simplicity $out/share/sddm/themes
      ls -la $out/share/sddm/themes
    '';
  };
in {
  environment.systemPackages = [ simplicity ];
  nixpkgs.overlays =
    let source = builtins.fromJSON (builtins.readFile ./source.json);
    in [
      (self: super: {
        awesome = super.awesome.overrideAttrs (old: {
          src = super.fetchFromGitHub rec {
            name = "source-${owner}-${repo}-${rev}";
            inherit (source) owner repo rev sha256;
          };
        });
      })
    ];

  environment.pathsToLink = [ "/share/sddm" "/share/sddm/themes" ];
  # Enable the X11 windowing system.
  services.xserver = {
    enable = true;
    layout = "br";
    dpi = 96;
    xkbOptions = "ctrl:swapcaps,compose:ralt";
    libinput.enable = true;
    displayManager = {
      sddm.enable = true;
      sddm.theme = "simplicity";
      autoLogin.enable = true;
      autoLogin.user = "zbioe";
      defaultSession = "none+awesome";
    };
    desktopManager.wallpaper = {
      mode = "fill";
      combineScreens = true;
    };
    windowManager.awesome.enable = true;
  };
  services.pipewire.enable = true;
  services.flatpak.enable = true;
  security.rtkit.enable = true;
  xdg.portal = {
    enable = true;
    gtkUsePortal = false;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
  };

}
