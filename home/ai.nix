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
    settings = {
      model = "deepseek/deepseek-v3.2";
      autoupdate = true;
    };
  };
  home.activation.installOhMyOpencodeSlim = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export PATH="${config.home.profileDirectory}/bin:${unstable.bun}/bin:${unstable.nodejs_22}/bin:$PATH"
    if [ ! -d "${config.home.homeDirectory}/.oh-my-opencode-slim" ]; then
      echo "🔧 Installing oh-my-opencode-slim"
      ${unstable.bun}/bin/bunx oh-my-opencode-slim@latest install --no-tui --skills=yes
    else
      echo "✅ oh-my-opencode-slim already installed."
    fi
  '';
}
