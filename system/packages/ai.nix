{
  config,
  lib,
  pkgs,
  unstable,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.packages.ai;
in
{
  options.dotnix.packages.ai = dotlib.mkPackages "AI tools";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = dotlib.packagesOf cfg (
      with pkgs;
      [
        unstable.harbor-cli # local AI stacks
        unstable.claude-code # coding agent
        unstable.zed-editor # editor with AI
        unstable.code-cursor # editor with AI
        unstable.antigravity-ide # editor with AI
        unstable.realesrgan-ncnn-vulkan # image upscaling
      ]
    );
  };
}
