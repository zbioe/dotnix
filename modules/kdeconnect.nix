{
  pkgs,
  ...
}:
{
  programs.kdeconnect.enable = true;

  environment.systemPackages = with pkgs; [
    kdePackages.kdeconnect-kde
  ];
}
