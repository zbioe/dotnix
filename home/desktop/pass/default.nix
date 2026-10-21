# Proton Pass from the desktop: `pw` (pw.sh), the launcher's /pw search and
# the PIN panel; the session locks with the screen
{
  config,
  lib,
  pkgs,
  unstable,
  ...
}:
let
  cfg = config.dotnix.desktop.pass;
  # gnome-keyring keeps its local key (the kernel keyring it falls back to is
  # gone at reboot, and not even reachable from every process); Nix updates it
  pass-cli = pkgs.symlinkJoin {
    name = "pass-cli";
    paths = [ unstable.proton-pass-cli ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/pass-cli \
        --set-default PROTON_PASS_LINUX_KEYRING dbus \
        --set-default PROTON_PASS_NO_UPDATE_CHECK 1
    '';
  };
  pw = pkgs.writeShellApplication {
    name = "pw";
    runtimeInputs = [
      pass-cli
    ]
    ++ (with pkgs; [
      coreutils
      gnugrep
      jq
      libnotify
      python3 # answer.py: types the lock code on a terminal
      util-linux # flock
      wl-clipboard
      xdg-utils
    ]);
    text = ''
      CLEAR_AFTER=${toString cfg.clearAfter}
      ANSWER=${./answer.py}
      ${builtins.readFile ./pw.sh}
    '';
  };
in
{
  options.dotnix.desktop.pass = {
    enable = lib.mkEnableOption "Proton Pass on the desktop (`pw`, launcher, PIN)";
    clearAfter = lib.mkOption {
      type = lib.types.ints.positive;
      default = 30;
      description = "Seconds a copied password stays in the clipboard.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pass-cli
      pw
    ];

    # the screen lock locks Pass too (its own lock code: `pass-cli session create-lock`)
    programs.noctalia.settings.hooks.session_locked = "${lib.getExe pw} lock";

    dotnix.desktop.noctalia.plugins.pass = {
      src = ./plugin;
      manifest = {
        name = "Proton Pass";
        icon = "key";
        description = "Proton Pass items in the launcher (/pw) and its lock code.";
        launcher_provider = [
          {
            id = "search";
            entry = "search.luau";
            prefix = "pw";
            glyph = "key";
          }
        ];
        panel = [
          {
            id = "unlock";
            entry = "unlock.luau";
            width = 360;
            height = 200;
            placement = "floating";
            position = "center";
          }
        ];
      };
      files."pass.json" = (pkgs.formats.json { }).generate "pass.json" {
        command = lib.getExe pw;
      };
    };
  };
}
