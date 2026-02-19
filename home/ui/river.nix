{
  pkgs,
  config,
  lib,
  ...
}:

let
  tag-setup = pkgs.writeShellScript "river-tag-setup" ''
    for i in $(seq 1 9); do
      tags=$((1 << ($i - 1)))
      riverctl map normal Super $i set-focused-tags $tags
      riverctl map normal Super+Shift $i set-view-tags $tags
    done
    riverctl map normal Super 0 set-focused-tags $(( (1 << 32) - 1 ))
    riverctl map normal Super+Shift 0 set-view-tags $(( (1 << 32) - 1 ))
  '';
in
{
  wayland.windowManager.river = {
    enable = true;
    xwayland.enable = true;

    extraConfig = ''
      # --- UWSM & Autostart ---
      # NÃO rodamos mais "systemctl import-environment" aqui, o UWSM já fez isso antes do River iniciar.

      # Use 'uwsm app --' para rodar processos em segundo plano.
      # Isso cria escopos systemd para cada app, permitindo logs e cleanup limpo.
      riverctl spawn "uwsm app -- ${pkgs.swww}/bin/swww-daemon"
      riverctl spawn "uwsm app -- ${pkgs.yambar}/bin/yambar"
      riverctl spawn "uwsm app -- ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
      riverctl spawn "uwsm app -- ${pkgs.mako}/bin/mako"

      # --- Layout ---
      riverctl default-layout rivertile
      riverctl spawn "uwsm app -- ${pkgs.river}/bin/rivertile -view-padding 0 -outer-padding 0"
      riverctl send-layout-cmd rivertile "main-ratio 0.5"
      riverctl send-layout-cmd rivertile "main-count 1"
      riverctl send-layout-cmd rivertile "main-location left"

      # --- Input ---
      riverctl set-cursor-warp on-output-change
      riverctl set-repeat 50 300
      riverctl input "pointer-*" accel-profile flat
      riverctl input "pointer-*" pointer-accel 0

      # --- Mapeamento (Também pode usar 'uwsm app --' aqui se quiser) ---
      riverctl map normal Super+Shift Q close
      # 'uwsm stop' é a maneira correta de sair da sessão agora
      riverctl map normal Super+Shift X spawn "uwsm stop" 

      riverctl map normal Super Return spawn "uwsm app -- ${pkgs.foot}/bin/foot"
      riverctl map normal Super P spawn "uwsm app -- ${pkgs.tofi}/bin/tofi-drun --drun-launch=true"
      riverctl map normal Super+Shift B spawn "uwsm app -- librewolf"
      riverctl map normal Super+Shift N spawn "uwsm app -- nautilus"

      # Yazi
      riverctl map normal Super Y spawn "uwsm app -- ${pkgs.foot}/bin/foot -e yazi"

      # Foco/Movimento
      riverctl map normal Super J focus-view next
      riverctl map normal Super K focus-view previous
      riverctl map normal Super+Shift J swap next
      riverctl map normal Super+Shift K swap previous
      riverctl map normal Super H send-layout-cmd rivertile "main-ratio -0.05"
      riverctl map normal Super L send-layout-cmd rivertile "main-ratio +0.05"
      riverctl map normal Super F toggle-fullscreen

      # Tags
      sh ${tag-setup}

      # Multimídia
      riverctl map normal None XF86AudioRaiseVolume spawn "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1+"
      riverctl map normal None XF86AudioLowerVolume spawn "wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.1-"
      riverctl map normal None XF86AudioMute spawn "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
      riverctl map normal None XF86MonBrightnessUp spawn "brightnessctl s +5%"
      riverctl map normal None XF86MonBrightnessDown spawn "brightnessctl s 5%-"

      # Printscreen
      riverctl map normal None Print spawn "${pkgs.grimblast}/bin/grimblast copy area"

      # --- FINALIZAÇÃO UWSM ---
      # Importante: Isso avisa ao systemd que o compositor está pronto.
      # Deve ser o último comando.
      exec uwsm finalize
    '';
  };
}
