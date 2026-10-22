# ai-memory: one long-term memory for every coding agent (a git-backed wiki
# of markdown, served on localhost). `agents` get its MCP server, hooks and
# skills; another agent is one more name in the list.
{
  config,
  lib,
  ai-memory,
  dotlib,
  ...
}:
let
  dev = config.dotnix.dev;
  cfg = dev.aiMemory;
  data = "${config.xdg.dataHome}/ai-memory";
  bin = "${ai-memory}/bin/ai-memory";
in
{
  options.dotnix.dev.aiMemory = {
    enable = dotlib.mkItem dev "ai-memory, shared memory for the coding agents";
    agents = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "claude-code"
        "opencode"
      ];
      description = "Agents wired to it (`ai-memory setup --help` lists them).";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ ai-memory ];
    home.sessionVariables.AI_MEMORY_DATA_DIR = data;

    systemd.user.services.ai-memory = {
      Unit.Description = "ai-memory, memory for the coding agents";
      Service = {
        ExecStartPre = "/bin/sh -c '[ -e ${data}/config.toml ] || ${bin} --data-dir ${data} init'";
        ExecStart = "${bin} --data-dir ${data} serve --transport http --bind 127.0.0.1:49374 --enable-web";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "default.target" ];
    };

    # MCP, hooks and skills for each agent; running it again changes nothing
    systemd.user.services.ai-memory-agents = {
      Unit = {
        Description = "Wire the coding agents to ai-memory";
        After = [ "ai-memory.service" ];
        Requires = [ "ai-memory.service" ];
        X-Restart-Triggers = [ (builtins.toJSON cfg.agents) ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${bin} --data-dir ${data} setup --yes --no-service ${
          lib.concatMapStringsSep " " (a: "--agent ${a}") cfg.agents
        }";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
