{ pkgs, ... }:
{
  # sudo asks for the fingerprint (fprintd, where there's a reader) or the
  # password: nothing running as the user becomes root unnoticed
  security.sudo.wheelNeedsPassword = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    # GTK prompt from gcr (themed like the rest; curses on a tty)
    pinentryPackage = pkgs.pinentry-gnome3;
  };
}
