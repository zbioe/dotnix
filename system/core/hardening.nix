# Kernel and system hardening from privsec.dev's Desktop Linux Hardening,
# leaving out what breaks this desktop: SMT stays on, user namespaces stay
# (Steam, Flatpak, Chromium and containers), ptrace stays (debuggers)
{
  config,
  lib,
  ...
}:
let
  cfg = config.dotnix.core.hardening;
in
{
  options.dotnix.core.hardening = {
    kernel.enable = lib.mkEnableOption "hardened kernel boot parameters (1-5% slower)";
    sysctl.enable = lib.mkEnableOption "hardened kernel and network sysctls";
    coreDumps.block = lib.mkEnableOption "blocking core dumps (memory of crashed programs on disk)";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.kernel.enable {
      boot.kernelParams = [
        # memory: no merged slabs, zeroed allocations, shuffled pages
        "slab_nomerge"
        "init_on_alloc=1"
        "init_on_free=1"
        "page_alloc.shuffle=1"
        "randomize_kstack_offset=on"
        "vsyscall=none"
        "debugfs=off"
        # devices can't read memory through DMA without the IOMMU
        "iommu=force"
        "iommu.passthrough=0"
        "iommu.strict=1"
        "amd_iommu=force_isolation"
        "intel_iommu=on"
      ];
    })
    (lib.mkIf cfg.sysctl.enable {
      boot.kernel.sysctl = {
        "kernel.kptr_restrict" = 2;
        "kernel.dmesg_restrict" = 1;
        "kernel.unprivileged_bpf_disabled" = 1;
        "net.core.bpf_jit_harden" = 2;
        "kernel.kexec_load_disabled" = 1;
        "dev.tty.ldisc_autoload" = 0;
        "net.ipv4.tcp_syncookies" = 1;
        "net.ipv4.tcp_rfc1337" = 1;
        "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
        "net.ipv4.conf.all.accept_redirects" = 0;
        "net.ipv4.conf.default.accept_redirects" = 0;
        "net.ipv4.conf.all.secure_redirects" = 0;
        "net.ipv4.conf.default.secure_redirects" = 0;
        "net.ipv4.conf.all.send_redirects" = 0;
        "net.ipv4.conf.default.send_redirects" = 0;
        "net.ipv4.conf.all.accept_source_route" = 0;
        "net.ipv4.conf.default.accept_source_route" = 0;
        "net.ipv6.conf.all.accept_redirects" = 0;
        "net.ipv6.conf.default.accept_redirects" = 0;
        "net.ipv6.conf.all.accept_source_route" = 0;
        "net.ipv6.conf.default.accept_source_route" = 0;
      };
    })
    (lib.mkIf cfg.coreDumps.block {
      systemd.coredump.settings.Coredump = {
        Storage = "none";
        ProcessSizeMax = 0;
      };
      boot.kernel.sysctl."fs.suid_dumpable" = 0;
      security.pam.loginLimits = [
        {
          domain = "*";
          item = "core";
          type = "hard";
          value = "0";
        }
      ];
    })
  ];
}
