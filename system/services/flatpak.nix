{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:
let
  cfg = config.dotnix.services.flatpak;
  overrides = pkgs.linkFarm "flatpak-overrides" (
    lib.mapAttrsToList (name: text: {
      inherit name;
      path = pkgs.writeText "flatpak-override-${name}" text;
    }) ({ inherit global; } // cfg.allow)
  );
  # privsec.dev: no X11, sound, D-Bus, network, devices or home for any app,
  # unless allowed one by one below
  global = ''
    [Context]
    sockets=!x11;!fallback-x11;!pulseaudio;!session-bus;!system-bus;
    shared=!network;!ipc;
    devices=!input;!shm;!all;
    filesystems=!host;

    [Session Bus Policy]
    org.freedesktop.Flatpak=none
    org.freedesktop.systemd1=none
    ca.desrt.dconf=none
    org.gnome.Shell.Extensions=none
  '';
in
{
  options.dotnix.services.flatpak = {
    enable = lib.mkEnableOption "Flatpak";
    restrict.enable = lib.mkEnableOption "denying Flatpak apps everything by default";
    allow = lib.mkOption {
      type = lib.types.attrsOf lib.types.lines;
      default = { };
      example = {
        "com.example.App" = ''
          [Context]
          shared=network;
        '';
      };
      description = "Per-app overrides (keyfile) on top of the restrictions.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        services.flatpak = {
          enable = true;
          package = unstable.flatpak;
        };
        fileSystems."/var/lib/flatpak" = {
          device = "/var/lib/nodatacow/flatpak";
          fsType = "none";
          options = [ "bind" ];
        };
      }
      (lib.mkIf cfg.restrict.enable {
        systemd.tmpfiles.rules = [
          "d /var/lib/flatpak/overrides 0755 root root -"
        ]
        ++ map (name: "L+ /var/lib/flatpak/overrides/${name} - - - - ${overrides}/${name}") (
          [ "global" ] ++ lib.attrNames cfg.allow
        );
      })
    ]
  );
}
