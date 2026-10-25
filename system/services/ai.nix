{
  config,
  lib,
  pkgs,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.services.ai;
  impermanence = config.dotnix.storage.impermanence.enable;
  # DynamicUser state lives in /var/lib/private (systemd wants it 0700)
  private = dir: {
    directory = "/var/lib/private/${dir}";
    mode = "0700";
  };
in
{
  options.dotnix.services.ai = {
    enable = lib.mkEnableOption "local AI";
    ollama = {
      enable = dotlib.mkItem cfg "Ollama";
      rocm = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "11.0.0";
        description = "Run on an AMD GPU, overriding its gfx version.";
      };
    };
    openWebui.enable = dotlib.mkItem cfg "Open WebUI on localhost:3333";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.ollama.enable {
      services.ollama = {
        enable = true;
        host = "127.0.0.1"; # no auth: never reachable from the network
      };
    })
    (lib.mkIf (cfg.ollama.enable && cfg.ollama.rocm != null) {
      services.ollama = {
        package = pkgs.ollama-rocm;
        rocmOverrideGfx = cfg.ollama.rocm;
      };
    })
    (lib.mkIf cfg.openWebui.enable {
      services.open-webui = {
        enable = true;
        port = 3333;
        environment = {
          OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
          WEBUI_AUTH = "False";
        };
      };
    })
    # the models, gigabytes each: kept, outside the snapshots and the backup
    (lib.mkIf (cfg.ollama.enable && impermanence) {
      environment.persistence."/var/lib/nodatacow".directories = [ (private "ollama") ];
    })
    # the chats, settings and documents: kept and in the backup
    (lib.mkIf (cfg.openWebui.enable && impermanence) {
      environment.persistence."/persist".directories = [ (private "open-webui") ];
    })
    (lib.mkIf ((cfg.ollama.enable || cfg.openWebui.enable) && impermanence) {
      systemd.tmpfiles.rules = [ "z /var/lib/private 0700 root root -" ];
    })
  ];
}
