{ config, pkgs, ... }:

let
  # 1. O script que injeta o comando direto no Distrobox
  insightful-wrapper = pkgs.writeShellScriptBin "insightful" ''
    distrobox enter ubuntu-work -- bash -c "
      export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
      unset GIO_EXTRA_MODULES
      cd $HOME/apps/insightful-root && ./Workpuls --no-sandbox
    "
  '';

  # 2. O atalho para o seu Rofi / Menu de Aplicativos
  insightful-desktop = pkgs.makeDesktopItem {
    name = "insightful";
    desktopName = "Insightful (Work)";
    exec = "${insightful-wrapper}/bin/insightful";
    icon = "${config.home.homeDirectory}/apps/insightful-root/Workpuls.png";
    categories = [
      "Utility"
      "Office"
    ];
    terminal = false;
  };

  proxyPython = pkgs.python3.withPackages (
    ps: with ps; [
      dbus-python # ← fornece dbus.mainloop.glib
      pygobject3 # ← fornece gi.repository.GLib
      evdev # ← monitor de input real
      xlib
    ]
  );

in
{
  home.packages = with pkgs; [
    proxyPython
    socat
    xorg.xprop
    xorg.xsetroot
    swayidle # monitor de ociosidade universal do wayland
    xdotool
    glib
    insightful-wrapper
    insightful-desktop
  ];

  # Script do proxy (gerenciado pelo Home-Manager)
  home.file.".local/bin/hypr-insightful-proxy.py" = {
    executable = true;
    text = ''
      #!/usr/bin/env python3
      import dbus
      import dbus.service
      import dbus.mainloop.glib
      from gi.repository import GLib
      import json
      import subprocess
      import time
      import threading
      import os

      dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

      os.environ["DISPLAY"] = ":0"
      print(f"[DEBUG] DISPLAY = {os.environ.get('DISPLAY')}")

      last_activity = time.time()

      def update_activity():
          global last_activity
          last_activity = time.time()

      def get_idle_time_ms():
          return int((time.time() - last_activity) * 1000)

      class IdleMonitor(dbus.service.Object):
          def __init__(self):
              bus_name = dbus.service.BusName("org.gnome.Mutter.IdleMonitor", bus=dbus.SessionBus())
              dbus.service.Object.__init__(self, bus_name, "/org/gnome/Mutter/IdleMonitor/Core")

          @dbus.service.method("org.gnome.Mutter.IdleMonitor", in_signature="", out_signature="t")
          def GetIdletime(self): return dbus.UInt64(get_idle_time_ms())

      class ScreenSaver(dbus.service.Object):
          def __init__(self):
              bus_name = dbus.service.BusName("org.freedesktop.ScreenSaver", bus=dbus.SessionBus())
              dbus.service.Object.__init__(self, bus_name, "/ScreenSaver")

          @dbus.service.method("org.freedesktop.ScreenSaver", in_signature="", out_signature="b")
          def GetActive(self): return dbus.Boolean(False)

          @dbus.service.method("org.freedesktop.ScreenSaver", in_signature="", out_signature="u")
          def GetActiveTime(self): return dbus.UInt32(get_idle_time_ms() // 1000)

      def hypr_listener():
          global last_activity
          runtime_dir = os.environ.get("XDG_RUNTIME_DIR")
          instance = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
          socket_path = f"{runtime_dir}/hypr/{instance}/.socket2.sock"
          try:
              s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
              s.connect(socket_path)
              while True:
                  if s.recv(4096):
                      update_activity()
          except Exception as e:
              print(f"[hypr-insightful-proxy] Erro socket: {e}")

      def title_updater():
          while True:
              try:
                  active_json = subprocess.check_output(["hyprctl", "activewindow", "-j"], text=True).strip()
                  if active_json and active_json != "null":
                      data = json.loads(active_json)
                      title = data.get("title", "Desktop")[:255]
                      for prop in ["WM_NAME", "_NET_WM_NAME", "_NET_WM_VISIBLE_NAME"]:
                          subprocess.call(["xprop", "-root", "-set", prop, title], stderr=subprocess.DEVNULL)
              except:
                  pass
              time.sleep(0.15)

      if __name__ == "__main__":
          print("[hypr-insightful-proxy] 🚀 V13 – Minimal e estável (Root + D-Bus)")
          update_activity()
          threading.Thread(target=hypr_listener, daemon=True).start()
          threading.Thread(target=title_updater, daemon=True).start()
          IdleMonitor()
          ScreenSaver()
          loop = GLib.MainLoop()
          loop.run()
    '';
  };

  # Serviço systemd user
  systemd.user.services.hypr-insightful-proxy = {
    Unit = {
      Description = "Proxy D-Bus + update direto na janela do Insightful (V8)";
      PartOf = [ "graphical-session.target" ];
      After = [
        "graphical-session.target"
        "dbus.service"
      ];
    };
    Service = {
      ExecStart = "${proxyPython}/bin/python %h/.local/bin/hypr-insightful-proxy.py";
      Restart = "always";
      RestartSec = 3;
      Environment = [
        "PATH=${pkgs.hyprland}/bin:${pkgs.socat}/bin:${pkgs.xorg.xprop}/bin:${pkgs.xorg.xsetroot}/bin:${pkgs.xdotool}/bin"
        "DISPLAY=:0"
      ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
