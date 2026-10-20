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
    (callPackage ../dotnix-key { })
  ];
  text = builtins.readFile ./usb-stick.sh;
}
