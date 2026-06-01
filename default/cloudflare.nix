{
  unstable,
  ...
}:

{
  services.cloudflare-warp.enable = true;
  environment.systemPackages = with unstable; [
    cloudflare-warp
    cloudflared
  ];
  systemd.packages = [ unstable.cloudflare-warp ];
  systemd.user.services.warp-taskbar.wantedBy = [ "graphical.target" ];

  environment.etc."gai.conf".text = ''
    # Precedence rules to prefer IPv4 over IPv6
    precedence ::ffff:0:0/96  100
  '';
}
