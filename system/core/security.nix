{ pkgs, ... }:
{
  security.sudo.wheelNeedsPassword = false;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    # GTK prompt from gcr (themed like the rest; curses on a tty)
    pinentryPackage = pkgs.pinentry-gnome3;
  };
}
