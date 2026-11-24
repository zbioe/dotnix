# te: installed by dotnix-install on 2026-11-09
{ unstable, ... }:
{
  imports = [
    ../common.nix
    # its hardware, from nixos-facter (hardware-configuration.nix only
    # served the install, before facter's report is applied)
    ./hardware.nix
  ];

  networking.hostName = "te";

  # the panel's self refresh (PSR) flashes white on bursts of redraws, like a
  # theme change. Scanout from the carve-out (VRAM) only: amdgpu put GNOME's
  # screen buffers in system memory when the carve-out filled up, and the
  # panel showed them white or as noise (HUBP addr_hi 0, measured
  # 2026-11-21; AMD's white screen with >= 64 GB, back on 7.3). Its BIOS
  # carve-out (UMA frame buffer) is 8 GB since
  boot.kernelParams = [
    "amdgpu.dcdebugmask=0x10"
    "amdgpu.sg_display=0"
  ];
  # the ACPI alarm device takes rtc0 (Linux 7.1+): chrony's RTC tracking
  # runs on its alarm, whose expired status is never cleared and powers the
  # laptop back on right after a shutdown. Without it the CMOS clock is rtc0
  boot.blacklistedKernelModules = [ "acpi_tad" ];

  dotnix = {
    # its reader: sudo takes the finger or the password, whichever comes first
    core.sudo.fingerprintOrPassword.enable = true;
    core.user.passwordFile = "/persist/secrets/zbioe.passwd";
    # Amanda's account (`mkpasswd | sudo tee /persist/secrets/amanda.passwd`
    # once), in GNOME laid out like the Zorin OS she used, with its browser
    # as it comes: no Dark Reader, no theme bridge
    core.user.others.amanda = {
      description = "Amanda";
      passwordFile = "/persist/secrets/amanda.passwd";
      packages = [ unstable.brave ];
    };
    desktop.gnome = {
      enable = true;
      windowsLike = [ "amanda" ];
    };
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
        # her caps lock is a caps lock
        kanata.offFor = [ "amanda" ];
      };
      # OpenCL on the Radeon 680M (ROCm)
      graphics.amd.compute.enable = true;
      # the 680M loads only these at boot (measured 2026-11-10)
      graphics.amd.initrdFirmware = [ "yellow_carp_*" ];
      # its panel flickered faintly on some pages (2x32 GB DDR5 SODIMM)
      graphics.amd.srLatencyFix.enable = true;
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
      kolide.enable = true;
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
