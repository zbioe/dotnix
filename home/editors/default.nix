# Doom Emacs: Doom itself from the flake (inputs.doomemacs), its config live
# from ~/dotnix/home/editors/doom, packages synced into ~/.local/share/doom
{
  config,
  lib,
  pkgs,
  doomemacs,
  ...
}:
let
  cfg = config.dotnix.editors.emacs;
  flake = "${config.home.homeDirectory}/dotnix";
  local = "${config.xdg.dataHome}/doom";
  secrets = ../../secrets/mail.yaml;

  emacs-wl =
    (pkgs.emacs-pgtk.override {
      withNativeCompilation = true;
      withTreeSitter = true;
      withXwidgets = true;
    }).overrideAttrs
      (old: {
        meta = (old.meta or { }) // {
          broken = false;
        };
        postPatch = (old.postPatch or "") + ''
          sed -i 's/WEBKIT_BROKEN=2.41.92/WEBKIT_BROKEN=9.99.99/g' configure.ac configure || true
        '';
      });

  # packages with native parts come from Nix, Doom takes them as built in
  emacs = (pkgs.emacsPackagesFor emacs-wl).emacsWithPackages (epkgs: [
    epkgs.vterm
    epkgs.pdf-tools
    epkgs.mu4e
    epkgs.treesit-grammars.with-all-grammars
  ]);

  doom = pkgs.writeShellScriptBin "doom" ''
    export DOOMLOCALDIR=${local}
    exec ${doomemacs}/bin/doom "$@"
  '';

  # what Doom's modules call outside Emacs; the language servers are in
  # system/packages/dev.nix and nix.nix
  tools = with pkgs; [
    mu # mail indexer for mu4e
    isync # mbsync: IMAP to maildir
    (aspellWithDicts (d: [
      d.en
      d.en-computers
      d.pt_BR
    ])) # spell checking
    languagetool # grammar checking
    wordnet # offline dictionary
    ripgrep # project search
    fd # file finder
    editorconfig-core-c # editorconfig
    gnuplot # org plots
    graphviz # dot graphs
    plantuml # uml diagrams
    mermaid-cli # mermaid diagrams
    pandoc # org export
    texliveMedium # latex and org pdf export
    texlab # latex language server
    imagemagick # image previews
    gdb # C debugger
    lldb # C, C++ and Rust debugger
    python3Packages.debugpy # python debugger
    rust-analyzer # rust language server
    lua-language-server # lua language server
    typescript-language-server # js and ts language server
    prettier # js, css, html and markdown formatter
    marksman # markdown language server
    sqlite # org-roam database
    grip # markdown preview
    cmake # vterm's module (Nix builds it, doctor still looks)
    dockfmt # dockerfile formatter
    libxml2 # xmllint, xml formatter
    rebar3 # erlang builds and formatter
    maim # org-download screenshots
    html-tidy # html formatter
    stylelint # css linter
    js-beautify # js, css and html formatter
    python3Packages.black # python formatter
    python3Packages.pyflakes # python imports
    python3Packages.isort # python import sorting
    python3Packages.pytest # python tests
    pipenv # python environments
    rustc # rust compiler
    # nose is dead; its successor under the name Doom calls
    (writeShellScriptBin "nosetests" ''exec ${python3Packages.nose2}/bin/nose2 "$@"'')
  ];
in
{
  imports = [ ./nvim.nix ];

  options.dotnix.editors.emacs.enable = lib.mkEnableOption "Doom Emacs (daemon and client)";

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        programs.emacs = {
          enable = true;
          package = emacs;
        };
        services.emacs = {
          enable = true;
          package = emacs;
          client.enable = true;
        };

        home.packages = [ doom ] ++ tools;
        home.sessionVariables.DOOMLOCALDIR = local;
        systemd.user.sessionVariables.DOOMLOCALDIR = local;

        xdg.dataFile."doom/etc/plantuml.jar".source = "${pkgs.plantuml}/lib/plantuml.jar";
        xdg.configFile = {
          "rebar3/rebar.config".text = "{plugins, [rebar3_format]}.";
          "emacs".source = doomemacs;
          "doom".source = config.lib.file.mkOutOfStoreSymlink "${flake}/home/editors/doom";
        };

        # `doom sync` when Doom, Emacs or the module list change
        systemd.user.services.doom-sync = {
          Unit = {
            Description = "Doom Emacs packages";
            X-Restart-Triggers = [
              "${doomemacs}"
              "${emacs}"
              (builtins.hashFile "sha256" ./doom/init.el)
              (builtins.hashFile "sha256" ./doom/packages.el)
            ];
          };
          Service = {
            # in the background: a sync takes minutes and the switch shouldn't wait
            Type = "exec";
            RemainAfterExit = true;
            Environment = [
              "DOOMLOCALDIR=${local}"
              "PATH=${
                lib.makeBinPath (
                  [
                    emacs
                    pkgs.git
                    pkgs.coreutils
                    pkgs.findutils
                    pkgs.gnugrep
                    pkgs.gnused
                    pkgs.gnutar
                    pkgs.gzip
                    pkgs.bash
                  ]
                  ++ tools
                )
              }"
            ];
            # -e: keep the env file out, Emacs gets the session's environment
            ExecStart = pkgs.writeShellScript "doom-sync" ''
              ${doomemacs}/bin/doom --force sync -e &&
              ${pkgs.systemd}/bin/systemctl --user try-restart emacs.service
            '';
          };
          Install.WantedBy = [ "default.target" ];
        };
      }

      # Proton through its Bridge: mbsync and smtpmail read the password
      # from sops, never from a file in the repo
      (lib.mkIf (builtins.pathExists secrets) {
        sops.secrets.proton-bridge.sopsFile = secrets;
        sops.templates.authinfo = {
          path = "${config.home.homeDirectory}/.authinfo";
          content = ''
            machine 127.0.0.1 port 1025 login zbioe@pm.me password ${config.sops.placeholder.proton-bridge}
            machine 127.0.0.1 port 1143 login zbioe@protonmail.com password ${config.sops.placeholder.proton-bridge}
          '';
        };

        home.file.".mbsyncrc".text = ''
          IMAPAccount proton
          Host 127.0.0.1
          Port 1143
          User zbioe@protonmail.com
          PassCmd "cat ${config.sops.secrets.proton-bridge.path}"
          TLSType None

          IMAPStore proton-remote
          Account proton

          MaildirStore proton-local
          Path ~/Mail/Proton/
          Inbox ~/Mail/Proton/Inbox
          SubFolders Verbatim

          Channel proton
          Far :proton-remote:
          Near :proton-local:
          Patterns *
          Create Both
          Expunge Both
          SyncState *
        '';
      })
    ]
  );
}
