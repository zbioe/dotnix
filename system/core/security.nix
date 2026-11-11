{ pkgs, ... }:
{
  # sudo asks for the fingerprint (fprintd, where there's a reader) or the
  # password: nothing running as the user becomes root unnoticed
  security.sudo.wheelNeedsPassword = true;
  # once authenticated, sudo doesn't ask again for 30 minutes in any of the
  # user's terminals (not only the one it was asked in)
  security.sudo.extraConfig = ''
    Defaults timestamp_type=global
    Defaults timestamp_timeout=30
  '';

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    # GTK prompt from gcr (themed like the rest; curses on a tty)
    pinentryPackage = pkgs.pinentry-gnome3;
  };
}
