# mango, run through uwsm so systemd user units see XDG_CURRENT_DESKTOP=mango
{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf config.dotnix.desktop.mango.enable {
  programs.mango = {
    enable = true;
    addLoginEntry = false;
  };
  programs.uwsm.enable = true;
  # X11 apps through Xwayland
  programs.xwayland.enable = true;

  # uwsm's own entry plus -g -1: it would wait for graphical.target, which
  # waits for docker and network-online (seconds of an empty screen)
  services.displayManager.sessionPackages = [
    (pkgs.writeTextFile {
      name = "mango-uwsm";
      text = ''
        [Desktop Entry]
        Name=Mango (UWSM)
        Comment=Mango compositor managed by UWSM
        Exec=${lib.getExe config.programs.uwsm.package} start -g -1 -F -- /run/current-system/sw/bin/mango
        Type=Application
      '';
      destination = "/share/wayland-sessions/mango-uwsm.desktop";
      derivationArgs.passthru.providedSessions = [ "mango-uwsm" ];
    })
  ];
}
