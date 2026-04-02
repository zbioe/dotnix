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
    xset
  ];
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
      from evdev import InputDevice, ecodes
      from pathlib import Path

      dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)

      os.environ["DISPLAY"] = ":0"

      last_activity = time.time()
      last_x11_pulse = 0 # <-- Controle para não sobrecarregar o X11


      def update_activity():
          global last_activity, last_x11_pulse
          current_time = time.time()
          last_activity = current_time

          # PULSO X11 CONTROLADO: Acorda o XWayland no máximo 1 vez por segundo
          if current_time - last_x11_pulse >= 1.0:
              subprocess.Popen(["xset", "s", "reset"], stderr=subprocess.DEVNULL)
              last_x11_pulse = current_time

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

      def mouse_event_poller():
          mouse_dev = None
          for path in Path("/dev/input").glob("event*"):
              try:
                  dev = InputDevice(str(path))
                  if dev.name == "INSTANT USB GAMING MOUSE ":
                      mouse_dev = dev
                      break
              except:
                  pass

          if not mouse_dev:
              return

          while True:
              try:
                  for event in mouse_dev.read_loop():
                      if event.type in (ecodes.EV_KEY, ecodes.EV_REL, ecodes.EV_ABS):
                          update_activity()
              except Exception as e:
                  print(f"[ERROR] Erro no mouse: {e}")
                  time.sleep(0.1)
              time.sleep(0.05)

      def keyboard_poller():
          devices = []
          for name in ["kanata-external", "kanata-internal"]:
              for path in Path("/dev/input").glob("event*"):
                  try:
                      dev = InputDevice(str(path))
                      if name in dev.name.lower():
                          devices.append(dev)
                          break
                  except:
                      pass

          if not devices:
              return

          while True:
              for dev in devices:
                  try:
                      for event in dev.read_loop():
                          if event.type == ecodes.EV_KEY and event.value == 1:
                              update_activity()
                  except:
                      pass
              time.sleep(0.05)

      def title_updater():
          from Xlib import display, X

          # Cria a "Janela Fantasma" invisível usando Xlib nativo
          try:
              d = display.Display()
              root = d.screen().root
              # Janela de 1x1 pixel, escondida, sem interface
              dummy_win = root.create_window(0, 0, 1, 1, 0, d.screen().root_depth, X.InputOutput, X.CopyFromParent)
              dummy_id = str(dummy_win.id)
              print(f"Janela Fantasma criada com sucesso. ID: {dummy_id}")
          except Exception as e:
              print(f"Erro ao criar janela fantasma: {e}")
              return

          last_title = ""
          while True:
              try:
                  # Pega a verdade absoluta do Hyprland
                  active_json = subprocess.check_output(["hyprctl", "activewindow", "-j"], text=True).strip()
                  if active_json and active_json != "null" and active_json != "{}":
                      data = json.loads(active_json)
                      title = data.get("title", "Desktop")[:255]
                      wm_class = data.get("class", "Desktop")[:255]

                      if title != last_title:
                          # 1. Carimba o título e a classe na nossa Janela Fantasma (que o app não sabe que é nossa)
                          subprocess.call(["xdotool", "set_window", "--name", title, dummy_id], stderr=subprocess.DEVNULL)
                          subprocess.call(["xprop", "-id", dummy_id, "-f", "WM_CLASS", "8s", "-set", "WM_CLASS", wm_class], stderr=subprocess.DEVNULL)

                          # 2. Força o servidor X11 a dizer "A janela fantasma é a que está em foco!"
                          subprocess.call(["xprop", "-root", "-f", "_NET_ACTIVE_WINDOW", "32a", "-set", "_NET_ACTIVE_WINDOW", dummy_id], stderr=subprocess.DEVNULL)

                          # 3. Mantém a Root Window atualizada para o seu 'watch xprop' no terminal continuar funcionando
                          subprocess.call(["xprop", "-root", "-f", "WM_NAME", "8s", "-set", "WM_NAME", title], stderr=subprocess.DEVNULL)

                          last_title = title
              except Exception:
                  pass

              # Mantém a janela fantasma viva e sincronizada no servidor X
              d.sync()
              time.sleep(1)

      if __name__ == "__main__":
          update_activity()
          threading.Thread(target=mouse_event_poller, daemon=True).start()
          threading.Thread(target=keyboard_poller, daemon=True).start()
          threading.Thread(target=title_updater, daemon=True).start()
          IdleMonitor()
          ScreenSaver()
          loop = GLib.MainLoop()
          loop.run()
    '';
  };

  systemd.user.services.hypr-insightful-proxy = {
    Unit = {
      Description = "Proxy D-Bus + evdev exato para mouse e kanata";
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
        "PATH=${pkgs.hyprland}/bin:${pkgs.xorg.xprop}/bin:${pkgs.xorg.xset}/bin:${pkgs.xdotool}/bin"
        "DISPLAY=:0"
      ];
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
