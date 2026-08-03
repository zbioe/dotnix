{
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    pass
  ];
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-all;
  };
}
