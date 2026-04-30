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
  };
  home.sessionPath = [
    "${config.home.homeDirectory}/.cache/bun/bin"
  ];
}
