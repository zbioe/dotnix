# sbctl that enrolls on firmware leaving its empty PK, KEK and db in place
# (AMI): efivarfs makes those immutable, and sbctl would refuse; only in
# Setup Mode, the one time they're written
{
  symlinkJoin,
  writeShellScriptBin,
  sbctl,
  coreutils,
  e2fsprogs,
}:
symlinkJoin {
  inherit (sbctl) name version meta;
  paths = [
    (writeShellScriptBin "sbctl" ''
      setup=$(${coreutils}/bin/od -An -t u1 /sys/firmware/efi/efivars/SetupMode-8be4df61-93ca-11d2-aa0d-00e098032b8c 2>/dev/null || true)
      if [ "''${1:-}" = enroll-keys ] && [ "''${setup##* }" = 1 ]; then
        for v in /sys/firmware/efi/efivars/{PK,KEK,db}-*; do
          [ -e "$v" ] && ${e2fsprogs}/bin/chattr -i "$v"
        done
      fi
      exec ${sbctl}/bin/sbctl "$@"
    '')
    sbctl
  ];
}
