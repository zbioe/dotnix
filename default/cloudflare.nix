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

  fileSystems."/var/lib/cloudflare-warp" = {
    device = "/var/lib/nodatacow/cloudflare-warp";
    fsType = "none";
    options = [ "bind" ];
  };

  systemd.services.cloudflare-warp.serviceConfig = {
    IPAddressDeny = [ "2606:4700::/32" ];
  };
}
