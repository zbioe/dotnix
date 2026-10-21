{ lib, ... }:
{
  imports = [
    ./ssh.nix
    ./vpn.nix
    ./wifi.nix
  ];

  networking.networkmanager = {
    enable = true;
    wifi.powersave = false;
    # the network's (DHCP) DNS is never used, only the one below
    dns = lib.mkForce "none";
    settings.main.systemd-resolved = false;
  };
  networking.firewall.enable = true;

  # DNS over TLS to Cloudflare (strict: no plain-text fallback, so a captive
  # portal needs DNSOverTLS = "opportunistic" until logged in)
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = [
        "1.1.1.1#cloudflare-dns.com"
        "1.0.0.1#cloudflare-dns.com"
        "2606:4700:4700::1111#cloudflare-dns.com"
        "2606:4700:4700::1001#cloudflare-dns.com"
      ];
      DNSOverTLS = "true";
      Domains = [ "~." ];
      FallbackDNS = [ ];
    };
  };

  # /etc/hosts is the host's own (persisted), edited by hand
  environment.etc.hosts.enable = false;
}
