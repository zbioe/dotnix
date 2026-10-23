# zmacs (github:zbioe/zmacs): Emacs and every package pinned by twist.nix, run
# as a daemon; its colors and fonts follow `theme` (home/theme)
{
  config,
  lib,
  pkgs,
  zmacs,
  ...
}:
let
  cfg = config.dotnix.editors.emacs;
  secrets = ../../secrets/mail.yaml;
  inherit (pkgs.stdenv.hostPlatform) system;
  zpkgs = zmacs.packages.${system};
  # mu4e's lisp comes from zmacs' nixpkgs: the mu binary has to match it
  zmacsPkgs = zmacs.inputs.nixpkgs.legacyPackages.${system};

  # where zmacs' early-init.el finds what Nix builds natively
  env = {
    ZMACS_NIX_ELPA = builtins.readFile zpkgs.nix-elpa;
    ZMACS_TREESIT_PATH = "${zpkgs.grammars}/lib";
    ZMACS_MU_BINARY = lib.getExe' zmacsPkgs.mu "mu";
  };

  # zmacs' own, plus the fonts `theme font` picked, before the first frame
  earlyInit = pkgs.writeText "early-init.el" ''
    ${builtins.readFile "${zmacs}/early-init.el"}
    (load (expand-file-name "theme/font/emacs.el"
                            (or (getenv "XDG_STATE_HOME") "~/.local/state"))
          t t)
  '';

  # what zmacs calls outside Emacs; the language servers and formatters are in
  # system/packages/dev.nix and nix.nix
  tools = with pkgs; [
    zmacsPkgs.mu # mail indexer for mu4e
    isync # mbsync: IMAP to maildir
    (aspellWithDicts (d: [
      d.en
      d.en-computers
      d.pt_BR
    ])) # spell checking
    pandoc # markdown preview and export
    prettier # js, css, html, json, yaml and markdown formatter
    lua-language-server # lua language server
    rust-analyzer # rust language server
    clang-tools # clangd
    languagetool # grammar (langtool)
    plantuml # uml diagrams
    graphviz # dot, plantuml's layouts
    gdb # C debugger (dape)
    lldb # C, C++ and Rust debugger (dape)
    python3Packages.debugpy # python debugger (dape)
  ];
in
{
  imports = [ ./nvim.nix ];

  options.dotnix.editors.emacs.enable = lib.mkEnableOption "zmacs (daemon and client)";

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        programs.emacs-twist = {
          enable = true;
          # services.emacs runs bin/emacs
          name = "emacs";
          config = zpkgs.emacs;
          createInitFile = true;
          earlyInitFile = earlyInit;
          emacsclient.enable = true;
          serviceIntegration.enable = true;
        };
        services.emacs.client.enable = true;

        home.packages = tools;
        home.sessionVariables = env;
        systemd.user.services.emacs.Service.Environment = lib.mapAttrsToList (k: v: "${k}=${v}") env;
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
