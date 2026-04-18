{
  config,
  lib,
  unstable,
  ...
}:

{
  environment.systemPackages = with unstable; [

    # AI tools
    harbor-cli

    # AI agents
    gemini-cli

    # AI editors
    zed-editor
    code-cursor
    claude-code
    opencode
    antigravity
  ];

  # services
  services.ollama = {
    enable = true;
    host = "0.0.0.0";
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
