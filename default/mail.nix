{
  pkgs,
  unstable,
  ...
}:

{
  environment.systemPackages = with unstable; [
    mu
    isync
    emacsPackages.mu4e
  ];
  services.protonmail-bridge = {
    enable = true;
    package = unstable.protonmail-bridge;
    path = with pkgs; [
      pass
      gnupg
    ];
  };
  systemd.user.services.protonmail-bridge = {
    wants = [ "gpg-agent.service" ];
    after = [
      "gpg-agent.service"
      "graphical-session.target"
    ];
  };
}
