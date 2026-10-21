{
  config,
  lib,
  pkgs,
  unstable,
  dotlib,
  ...
}:
let
  cfg = config.dotnix.packages.dev;
  ansible-language-server = pkgs.writeShellScriptBin "ansible-language-server" ''
    exec ${pkgs.nodejs_24}/bin/npx --yes @ansible/ansible-language-server@26.6.0 "$@"
  '';
in
{
  options.dotnix.packages.dev = dotlib.mkPackages "languages, language servers and dev tools";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = dotlib.packagesOf cfg (
      with pkgs;
      [
        # languages
        unstable.beamPackages.elixir # elixir
        python3 # python
        python3Packages.pip # python packages
        uv # python projects
        go # go
        nodejs_24 # node, for copilot and some LSPs
        cargo # rust
        lua # lua
        luajitPackages.luarocks # lua packages
        ruby # ruby
        gem # ruby packages
        php # php
        jdk # java
        julia # julia
        gcc # C compiler
        gnumake # make

        # language servers, linters and formatters (doom emacs lsp)
        gopls # go
        golangci-lint # go linter
        gotools # goimports
        gofumpt # stricter gofmt
        gomodifytags # struct tags
        gotests # test generation
        gore # go repl
        delve # go debugger
        unstable.elixir-ls # elixir
        erlang-language-platform # erlang (ELP)
        basedpyright # python
        ruff # python linter and formatter
        bash-language-server # sh/bash
        shellcheck # sh linter
        shfmt # sh formatter
        yaml-language-server # yaml, compose, k8s
        vscode-langservers-extracted # json, html, css
        dockerfile-language-server # dockerfiles
        hadolint # dockerfile linter
        terraform-ls # terraform
        tflint # terraform linter
        ansible-language-server # ansible
        ansible-lint # ansible linter
        css-checker # css duplicates
        scss-lint # scss linter
        svelte-check # svelte
        vue # vue
        argc # bash CLIs from comments

        # tools
        git # version control
        gh # github cli
        hut # sourcehut cli
        github-desktop # git GUI
        lazygit # git TUI
        lazydocker # docker TUI
        oxker # docker TUI
        docker-compose # docker compose
        process-compose # processes from a yaml file
        hurl # HTTP requests from plain text
        posting # API client TUI
        dblab # SQL TUI
        lazysql # SQL TUI
        rainfrog # SQL TUI
        vi-mongo # mongo TUI
        mongosh # mongo shell
        mutagen # folder sync
        mkcert # local HTTPS certificates
        exercism # coding exercises
        leetcode-cli # coding challenges
      ]
    );
  };
}
