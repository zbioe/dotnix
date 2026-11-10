# te: installed by dotnix-install on 2026-11-09
{
  imports = [
    ../common.nix
    ./hardware-configuration.nix
    ./hardware.nix
  ];

  networking.hostName = "te";

  dotnix = {
    core.user.passwordFile = "/persist/secrets/zbioe.passwd";
    core.boot = {
      loader = "limine";
      secureBoot.enable = true;
      tpm2.enable = true;
    };
    # its home, the first time (then `nh home switch`)
    core.homeActivation.enable = true;
    hardware.keyboard.layout = "br";
    storage = {
      disk = {
        enable = true;
        device = "/dev/disk/by-id/nvme-KINGSTON_SNV3S1000G_50026B7283A752F6";
        swapSize = "62G";
      };
      impermanence.enable = true;
      # a key on the stick (`sudo dotnix-key create /dev/sdX` once); without
      # it, the TPM and PIN, then the passphrase. It shows up in ~3 s
      usbKey = {
        enable = true;
        timeout = 5;
      };
      snapshots.enable = true;
      # Proton Drive: `backup setup` once
      backup = {
        enable = true;
        cacheDir = "/var/lib/nodatacow/backup";
      };
    };
  };

  # the release it was installed with; do not change
  system.stateVersion = "26.05";
}
