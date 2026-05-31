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
}
