{
  callPackage,
  writeShellApplication,
  coreutils,
  diffutils,
  dosfstools,
  e2fsprogs,
  grub2_efi,
  nix,
  util-linux,
  gawk,
  gnused,
  gnugrep,
  sbctl,
  systemdUkify,
}:
writeShellApplication {
  name = "usb-stick";
  runtimeInputs = [
    coreutils
    diffutils
    dosfstools
    e2fsprogs
    grub2_efi
    nix
    util-linux
    gawk
    gnused
    gnugrep
    # signing for Secure Boot: systemd-boot and a UKI per NixOS ISO
    sbctl
    systemdUkify
    (callPackage ../dotnix-key { })
  ];
  runtimeEnv.SYSTEMD_BOOT = "${systemdUkify}/lib/systemd/boot/efi/systemd-bootx64.efi";
  text = builtins.readFile ./usb-stick.sh;
}
