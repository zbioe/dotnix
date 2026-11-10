# te: installed by dotnix-install on 2026-11-09
{
  imports = [
    ../common.nix
    # its hardware, from nixos-facter (hardware-configuration.nix only
    # served the install, before facter's report is applied)
    ./hardware.nix
  ];

  networking.hostName = "te";

  # the panel's self refresh (PSR) flashes white on bursts of redraws, like a
  # theme change
  boot.kernelParams = [ "amdgpu.dcdebugmask=0x10" ];
  # the ACPI alarm device takes rtc0 (Linux 7.1+): chrony's RTC tracking
  # runs on its alarm, whose expired status is never cleared and powers the
  # laptop back on right after a shutdown. Without it the CMOS clock is rtc0
  boot.blacklistedKernelModules = [ "acpi_tad" ];

  dotnix = {
    core.user.passwordFile = "/persist/secrets/zbioe.passwd";
    core.boot = {
      loader = "limine";
      secureBoot.enable = true;
      tpm2.enable = true;
      # its 64 GB zeroed on all cores and amdgpu loaded without ftrace's scan
      # (-4 s); built by the kernel workflow, never here
      fastKernel.enable = true;
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
      # the 680M loads only these at boot (measured 2026-11-10)
      graphics.amd.initrdFirmware = [ "yellow_carp_*" ];
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
    services = {
      # the 680M (gfx1035) as ROCm's nearest supported RDNA2
      ai.ollama = {
        rocm = "10.3.0";
        integratedGpu = true;
      };
      # what it builds, for the other hosts (zbioe.cachix.org)
      cache.push.enable = true;
      # the phone, with AVNC's SSH tunnel
      wayvnc = {
        enable = true;
        keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBtFuMrQPdb+ExX6JkMlAkAauGPddbqGWAapIbQliHN/ avnc-phone"
        ];
      };
    };
  };

  # the release it was installed with; do not change
  system.stateVersion = "26.05";
}
