{
  config,
  lib,
  unstable,
  ...
}:

{
  # NodeJS
  home.packages = with unstable; [
    nodejs_22
    bun
    playwright
  ];
  programs.opencode = {
    enable = true;
    package = unstable.opencode;
    tui.plugin = [ "oh-my-opencode-slim" ];
  };
  home.sessionPath = [
    "${config.home.homeDirectory}/.cache/bun/bin"
  ];
}
