{
  config,
  lib,
  osConfig,
  unstable,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.dev;
in
{
  imports = [ ./ai-memory.nix ];

  options.dotnix.dev = {
    enable = lib.mkEnableOption "the user's dev tools";
    node.enable = dotlib.mkItem cfg "node, bun and playwright, with global npm packages in ~/.npm-global";
    opencode.enable = dotlib.mkItem cfg "opencode";
  };

  config = lib.mkMerge [
    # rootless Docker: every shell and app talks to your daemon
    (lib.mkIf osConfig.dotnix.services.containers.docker.rootless {
      home.sessionVariables.DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/docker.sock";
      systemd.user.sessionVariables.DOCKER_HOST = "unix://%t/docker.sock";
    })
    (lib.mkIf cfg.node.enable {
      home.packages = with unstable; [
        nodejs_22 # node
        bun # javascript runtime and package manager
        playwright # browser automation
      ];
      home.file.".npmrc".text = ''
        prefix=${config.home.homeDirectory}/.npm-global
      '';
      home.sessionVariables.PATH = "$HOME/.npm-global/bin:$PATH";
      home.sessionPath = [ "${config.home.homeDirectory}/.cache/bun/bin" ];
    })
    (lib.mkIf cfg.opencode.enable {
      programs.opencode = {
        enable = true;
        package = unstable.opencode;
        tui.plugin = [ "oh-my-opencode-slim" ];
      };
    })
  ];
}
