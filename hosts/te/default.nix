# te: installed by dotnix-install on 2026-11-09
{
  imports = [
    ../common.nix
    # its hardware, from nixos-facter (hardware-configuration.nix only
    # served the install, before facter's report is applied)
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
    hardware = {
      # ABNT2 ThinkPad: the console too, so the disk's password at boot
      keyboard = {
        layout = "br";
        model = "thinkpad";
        variant = "thinkpad";
      };
      # OpenCL on the Radeon 680M (ROCm)
      graphics.amd.compute.enable = true;
    };
    storage = {
      # its partitions by label; the device (and swap size) only matter to
      # dotnix-install, which formats it
      disk = {
        enable = true;
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
