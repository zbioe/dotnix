# sbctl that enrolls on firmware leaving its empty PK, KEK and db in place
# (AMI): efivarfs makes those immutable, and sbctl would refuse
{
  symlinkJoin,
  writeShellScriptBin,
  sbctl,
  e2fsprogs,
}:
symlinkJoin {
  inherit (sbctl) name version meta;
  paths = [
    (writeShellScriptBin "sbctl" ''
      if [ "''${1:-}" = enroll-keys ]; then
        for v in /sys/firmware/efi/efivars/{PK,KEK,db}-*; do
          [ -e "$v" ] && ${e2fsprogs}/bin/chattr -i "$v"
        done
      fi
      exec ${sbctl}/bin/sbctl "$@"
    '')
    sbctl
  ];
}
