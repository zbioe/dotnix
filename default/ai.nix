{
  config,
  lib,
  unstable,
  trae-deb,
  ...
}:

{
  environment.systemPackages = with unstable; [

    # AI tools
    harbor-cli

    # AI agents
    claude-code

    # AI editors
    zed-editor
    code-cursor
    aider-chat
    antigravity-ide

    # upscaling
    realesrgan-ncnn-vulkan
  ];

  # services
  services.ollama = {
    enable = true;
    host = "127.0.0.1"; # no auth: never reachable from the network
  };
  services.open-webui = {
    enable = true;
    port = 3333;
    environment = {
      OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
      WEBUI_AUTH = "False";
    };
  };
}
