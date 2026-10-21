{
  config,
  lib,
  unstable,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.desktop.terminals;
in
{
  options.dotnix.desktop.terminals = {
    enable = lib.mkEnableOption "the terminals";
    foot.enable = dotlib.mkItem cfg "foot (patched: `theme font` changes open windows)";
    alacritty.enable = dotlib.mkItem cfg "Alacritty";
    ghostty.enable = dotlib.mkItem cfg "Ghostty";
    kitty.enable = dotlib.mkItem cfg "kitty";
    default = dotlib.mkMain [
      "foot"
      "alacritty"
      "ghostty"
      "kitty"
    ] "terminal of Super+Enter";
  };

  config = {
    assertions = [ (dotlib.assertMain "dotnix.desktop.terminals" cfg) ];
    programs = {
      foot = {
        enable = cfg.foot.enable;
        server.enable = true;
        settings = {
          main = {
            term = "xterm-256color";
          };
        };
      };
      alacritty = {
        enable = cfg.alacritty.enable;
        package = unstable.alacritty;
      };
      ghostty = {
        enable = cfg.ghostty.enable;
        package = unstable.ghostty;
        systemd.enable = true;
        installVimSyntax = true;
        installBatSyntax = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
      };
      kitty = {
        enable = cfg.kitty.enable;
        package = unstable.kitty;
        settings = {
          hide_window_decorations = "yes";
          titlebar_style = "none";
          window_border_width = 0;
          draw_minimal_borders = "no";
          placement_strategy = "top-right";
          tab_bar_style = "hidden";
          window_padding_width = 0;
          window_margin_width = 0;
        };
      };
    };
  };
}
