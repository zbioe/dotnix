# usb-stick: files (FAT32, readable anywhere), Linux ISOs booted from files by GRUB, and the dotnix-key.
# With this machine's Secure Boot keys (sbctl) the stick boots systemd-boot,
# signed, with a signed UKI of each NixOS ISO: those boot with Secure Boot on.
# GRUB (the other ISOs) is an entry of it, for Secure Boot off.

FILES_SIZE_MIB=4096
ESP_SIZE_MIB=512
MIB=$((1024 * 1024))

usage() {
  cat <<'EOF'
usage:
  usb-stick create [--pin | --no-key] [--yes] [--serial] DEVICE [ISO...]
                                    without ISOs: only FILES and the key
  usb-stick add DEVICE ISO...       copy ISOs (a same-named one is replaced)
  usb-stick remove DEVICE NAME...   remove ISOs by file name
  usb-stick list DEVICE

ISO: an .iso file, or a flake output holding one (.#iso-full, .#iso-minimal).
GRUB lists isos/*.iso of the ISOS partition at every boot: copying or deleting
files there by hand works too. DEVICE may be an image file.
EOF
}

die() {
  echo "usb-stick: $*" >&2
  exit 1
}

say() { echo "usb-stick: $*"; }

as_root() {
  if [ "$(id -u)" = 0 ]; then "$@"; else sudo "$@"; fi
}

work=$(mktemp -d)
loopdev=""
mounted=()

cleanup() {
  local i
  for ((i = ${#mounted[@]} - 1; i >= 0; i--)); do
    as_root umount "${mounted[i]}" 2>/dev/null || true
  done
  if [ -n "$loopdev" ]; then as_root losetup -d "$loopdev" 2>/dev/null || true; fi
  rm -rf "$work"
}
trap cleanup EXIT

mount_at() {
  mkdir -p "$2"
  if [ -n "${3:-}" ]; then as_root mount -o "$3" "$1" "$2"; else as_root mount "$1" "$2"; fi
  mounted+=("$2")
}

umount_at() {
  as_root umount "$1"
  local kept=() m
  for m in "${mounted[@]}"; do [ "$m" = "$1" ] || kept+=("$m"); done
  mounted=("${kept[@]}")
}

human() { numfmt --to=iec --suffix=B "$1"; }

# resolve_iso prints the .iso file of an argument (a file or a flake output).
resolve_iso() {
  local out=$1 f
  case $1 in
  *'#'*) out=$(nix build --no-link --print-out-paths "$1") || die "$1 does not build" ;;
  esac
  if [ -f "$out" ]; then
    readlink -f "$out"
    return
  fi
  if [ -d "$out/iso" ]; then
    local found=()
    for f in "$out"/iso/*.iso; do [ -f "$f" ] && found+=("$f"); done
    [ ${#found[@]} = 1 ] || die "$1: expected one ISO in $out/iso"
    echo "${found[0]}"
    return
  fi
  die "$1: not an ISO file or a flake output with one"
}

# iso_kind: how GRUB boots it from a file (loopback, nixos), or nothing.
iso_kind() {
  local dir="$work/probe" kind=""
  mkdir -p "$dir"
  as_root mount -o loop,ro "$1" "$dir" 2>/dev/null || return 0
  if [ -f "$dir/boot/grub/loopback.cfg" ]; then
    kind=loopback
  elif [ -e "$dir/EFI/nixos-installer-image" ] && [ -e "$dir/.dotnix-findiso" ]; then
    kind=nixos
  elif [ -e "$dir/EFI/nixos-installer-image" ]; then
    kind=nixos-upstream
  fi
  as_root umount "$dir"
  echo "$kind"
}

# iso_name: the file name on the stick (GRUB-safe characters, ending in .iso).
iso_name() {
  local name base=${1##*/}
  if [ "${1%/*}" = /nix/store ]; then base=${base#*-}; fi
  name=$(printf '%s' "$base" | tr -c 'A-Za-z0-9._+-' '_')
  case $name in
  *.iso) ;;
  *.ISO) name="${name%.ISO}.iso" ;;
  *) name="$name.iso" ;;
  esac
  echo "$name"
}

# signing: this machine has sbctl keys (dotnix.core.boot.secureBoot)
signing() {
  local keys=/var/lib/sbctl/keys
  if [ -f /etc/sbctl/sbctl.conf ]; then
    keys=$(sed -n 's/.*"keydir": *"\([^"]*\)".*/\1/p' /etc/sbctl/sbctl.conf)
  fi
  as_root test -f "$keys/db/db.key"
}

# secure_front: systemd-boot, signed, in front of GRUB (which moves aside): with
# Secure Boot GRUB can't hand over to anything it didn't verify itself
secure_front() {
  local esp=$1
  if ! as_root test -f "$esp/EFI/grub/grubx64.efi"; then
    as_root mkdir -p "$esp/EFI/grub"
    as_root mv "$esp/EFI/BOOT/BOOTX64.EFI" "$esp/EFI/grub/grubx64.efi"
  fi
  as_root cp "$SYSTEMD_BOOT" "$esp/EFI/BOOT/BOOTX64.EFI"
  as_root sbctl sign "$esp/EFI/BOOT/BOOTX64.EFI" >/dev/null
  as_root mkdir -p "$esp/loader/entries"
  printf 'timeout 10\ndefault *.iso.efi\n' | as_root tee "$esp/loader/loader.conf" >/dev/null
  printf 'title Other ISOs (GRUB, Secure Boot off)\nefi /EFI/grub/grubx64.efi\n' |
    as_root tee "$esp/loader/entries/grub.conf" >/dev/null
  say "systemd-boot: signed for Secure Boot"
}

# sync_ukis: for each NixOS ISO named, a UKI (its kernel, initrd and command
# line, plus findiso=) in the ESP's EFI/Linux, signed: systemd-boot lists it
# and the firmware checks it. UKIs whose ISO is gone are dropped.
sync_ukis() {
  local esp=$1 dir=$work/isos/isos name f cfg kernel initrd params
  as_root mkdir -p "$esp/EFI/Linux"
  for f in "$esp"/EFI/Linux/*.efi; do
    [ -f "$f" ] || continue
    name=${f##*/}
    as_root test -f "$dir/${name%.efi}" || as_root rm "$f"
  done
  for name in "${@:2}"; do
    [ "$(iso_kind "$dir/$name")" = nixos ] || continue
    mkdir -p "$work/uki"
    as_root mount -o loop,ro "$dir/$name" "$work/uki"
    cfg=$work/uki/EFI/BOOT/grub.cfg
    # the first entry: linux KERNEL ${isoboot} PARAMS, then initrd INITRD
    kernel=$(awk '$1 == "linux" { print $2; exit }' "$cfg")
    params=$(awk '$1 == "linux" { for (i = 3; i <= NF; i++) if ($i != "${isoboot}") printf " %s", $i; exit }' "$cfg")
    initrd=$(awk '$1 == "initrd" { print $2; exit }' "$cfg")
    [ -n "$kernel" ] && [ -n "$initrd" ] || die "$name: no kernel in its grub.cfg"
    printf 'NAME=NixOS\nID=nixos\nPRETTY_NAME="%s"\n' "$name" >"$work/os-release"
    ukify build --linux="$work/uki$kernel" --initrd="$work/uki$initrd" --os-release="@$work/os-release" \
      --cmdline="findiso=/isos/$name$params" --output="$work/$name.efi" >/dev/null
    as_root umount "$work/uki"
    as_root cp "$work/$name.efi" "$esp/EFI/Linux/$name.efi"
    rm "$work/$name.efi"
    as_root sbctl sign "$esp/EFI/Linux/$name.efi" >/dev/null
    say "$name: signed for Secure Boot"
  done
}

# signed_isos: with keys, the signed front and the UKIs of these ISOs (and
# none of ISOs gone)
signed_isos() {
  local esp
  signing || return 0
  esp=$(part_of ESP) || die "$disk has no ESP partition"
  mount_at "$esp" "$work/esp"
  mount_isos ro
  secure_front "$work/esp"
  sync_ukis "$work/esp" "$@"
  umount_at "$work/isos"
  umount_at "$work/esp"
}

# check_isos fills srcs/names/sizes, refusing what GRUB can't boot.
srcs=()
names=()
sizes=()
check_isos() {
  local arg src name kind seen
  for arg in "$@"; do
    src=$(resolve_iso "$arg")
    name=$(iso_name "$src")
    kind=$(iso_kind "$src")
    if [ "$kind" = nixos-upstream ]; then
      die "$arg: an upstream NixOS ISO can't read the stick (its initrd has no ext4): use one built from this flake (.#iso-full, .#iso-minimal)"
    fi
    [ -n "$kind" ] || die "$arg: not a Linux ISO that boots from a file (no boot/grub/loopback.cfg, not NixOS)"
    for seen in "${names[@]}"; do
      [ "$seen" != "$name" ] || die "two ISOs named $name"
    done
    srcs+=("$src")
    names+=("$name")
    sizes+=("$(stat -L -c %s "$src")")
    say "$name: $kind, $(human "${sizes[-1]}")"
  done
}

open_stick() {
  if [ -f "$1" ]; then
    loopdev=$(as_root losetup -fP --show "$1")
    disk=$loopdev
    image=1
  elif [ -b "$1" ]; then
    disk=$(readlink -f "$1")
    image=0
  else
    die "$1: not a block device or an image file"
  fi
  [ "$(lsblk -dno TYPE "$disk")" != part ] || die "$1 is a partition: give the whole disk"
  as_root udevadm settle 2>/dev/null || true
}

part_of() {
  local path label
  while read -r path label; do
    if [ "$label" = "$1" ]; then
      echo "$path"
      return 0
    fi
  done < <(lsblk -nrpo PATH,PARTLABEL "$disk")
  return 1
}

mount_isos() {
  local p
  p=$(part_of ISOS) || die "$disk has no ISOS partition: create it again with ISOs"
  mount_at "$p" "$work/isos" "${1:-rw}"
  if [ "${1:-rw}" = rw ]; then as_root mkdir -p "$work/isos/isos"; fi
}

free_bytes() { df -B1 --output=avail "$1" | tail -n 1 | tr -d ' '; }

# copy_isos: space check, copy, then read everything back from the stick.
copy_isos() {
  local dir="$work/isos/isos" i need=0 reclaim=0 avail dest
  for i in "${!names[@]}"; do
    need=$((need + sizes[i]))
    dest="$dir/${names[i]}"
    if as_root test -f "$dest"; then reclaim=$((reclaim + $(as_root stat -c %s "$dest"))); fi
  done
  avail=$(free_bytes "$work/isos")
  if ((need + 16 * MIB > avail + reclaim)); then
    die "the ISOs need $(human "$need"), the stick has $(human $((avail + reclaim))) for them"
  fi
  for i in "${!names[@]}"; do
    dest="$dir/${names[i]}"
    say "copying ${names[i]}"
    as_root rm -f "$dest" "$dir/.${names[i]}.partial"
    as_root cp "${srcs[i]}" "$dir/.${names[i]}.partial"
    as_root mv "$dir/.${names[i]}.partial" "$dest"
  done
  sync
  umount_at "$work/isos"
  mount_isos ro
  for i in "${!names[@]}"; do
    as_root cmp "${srcs[i]}" "$dir/${names[i]}" || die "${names[i]} on the stick differs from its source"
    say "${names[i]}: verified"
  done
  umount_at "$work/isos"
}

grub_cfg() {
  echo "# usb-stick: lists isos/*.iso of the ISOS partition at every boot"
  echo "insmod part_gpt"
  echo "insmod fat"
  echo "insmod ext2"
  echo "insmod iso9660"
  echo "insmod loopback"
  echo "insmod regexp"
  echo "insmod all_video"
  if [ "$2" = 1 ]; then
    echo "serial --unit=0 --speed=115200"
    echo "terminal_input console serial"
    echo "terminal_output console serial"
  fi
  echo "search --no-floppy --fs-uuid --set=isos $1"
  cat <<'EOF'
set root=$isos
set timeout=10
set default=0
# bootable ones first, so the default entry always boots
for pass in supported other; do
  for iso in /isos/*.iso; do
    if [ ! -f "$iso" ]; then continue; fi
    loopback probe "$iso"
    kind=other
    if [ -f (probe)/boot/grub/loopback.cfg ]; then
      kind=loopback
    elif [ -f (probe)/EFI/nixos-installer-image -a -f (probe)/.dotnix-findiso ]; then
      kind=nixos
    fi
    loopback -d probe
    if [ "$pass" = supported -a "$kind" = loopback ]; then
      menuentry "$iso" "$iso" --class linux {
        set iso_path="$2"
        export iso_path
        loopback loop "$iso_path"
        set root=(loop)
        configfile /boot/grub/loopback.cfg
      }
    elif [ "$pass" = supported -a "$kind" = nixos ]; then
      menuentry "$iso" "$iso" --class nixos {
        set iso_path="$2"
        export iso_path
        loopback loop "$iso_path"
        set root=(loop)
        configfile /EFI/BOOT/grub.cfg
      }
    elif [ "$pass" = other -a "$kind" = other ]; then
      menuentry "$iso (not supported)" "$iso" {
        echo "$2: no boot/grub/loopback.cfg, it can't boot from a file"
        sleep 10
      }
    fi
  done
done
menuentry "Firmware setup" {
  fwsetup
}
menuentry "Power off" {
  halt
}
EOF
}

create() {
  local pin=0 nokey=0 yes=0 serial=0 args=()
  while (($#)); do
    case $1 in
    --pin) pin=1 ;;
    --no-key) nokey=1 ;;
    --yes) yes=1 ;;
    --serial) serial=1 ;;
    -*) die "create: unknown option $1" ;;
    *) args+=("$1") ;;
    esac
    shift
  done
  ((${#args[@]} >= 1)) || die "create: no DEVICE"
  ((pin == 0 || nokey == 0)) || die "--pin and --no-key together"
  open_stick "${args[0]}"
  check_isos "${args[@]:1}"

  if ((image == 0)); then
    [ "$(lsblk -dno TRAN "$disk")" = usb ] || die "$disk is not a USB device"
  fi
  [ -z "$(lsblk -nro MOUNTPOINTS "$disk" | tr -d '[:space:]')" ] || die "$disk is mounted: unmount it first"

  # FILES shrinks (or goes) to fit the ISOs; without ISOs it takes the whole stick
  local total avail need=0 s isos_part=0 files_part
  total=$(as_root blockdev --getsize64 "$disk")
  avail=$((total - 2 * MIB))
  files_part=$avail
  if ((${#names[@]})); then
    for s in "${sizes[@]}"; do need=$((need + s)); done
    isos_part=$(((need + 128 * MIB) * 50 / 49 / MIB * MIB + MIB))
    ((isos_part >= 256 * MIB)) || isos_part=$((256 * MIB))
    avail=$((avail - ESP_SIZE_MIB * MIB))
    ((isos_part <= avail)) || die "the ISOs need $(human "$need"), $disk ($(human "$total")) is too small for them"
    files_part=$((avail - isos_part))
    ((files_part <= FILES_SIZE_MIB * MIB)) || files_part=$((FILES_SIZE_MIB * MIB))
    ((files_part >= 64 * MIB)) || files_part=0
    isos_part=$((avail - files_part))
  fi
  ((files_part >= 64 * MIB || isos_part)) || die "$disk is too small: $(human "$total")"

  local table=("label: gpt") layout=()
  if ((files_part)); then
    table+=("size=$((files_part / MIB))MiB, type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7, name=FILES")
    layout+=("FILES $(human "$files_part")")
  fi
  if ((isos_part)); then
    table+=("size=${ESP_SIZE_MIB}MiB, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name=ESP")
    table+=("type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name=ISOS")
    layout+=("ESP ${ESP_SIZE_MIB}MiB" "ISOS $(human "$isos_part")")
  fi

  lsblk -o NAME,SIZE,TRAN,MODEL,FSTYPE,LABEL "$disk"
  echo "EVERYTHING on $disk is erased: ${layout[*]}."
  if ((yes == 0)); then
    local answer
    read -rp "Type ${args[0]} to continue: " answer
    [ "$answer" = "${args[0]}" ] || die "aborted"
  fi

  as_root wipefs -aq "$disk"
  printf '%s\n' "${table[@]}" | as_root sfdisk --quiet --wipe always --wipe-partitions always "$disk"
  as_root udevadm settle 2>/dev/null || true
  local files esp isos
  if ((files_part)); then
    files=$(part_of FILES) || die "the FILES partition did not show up"
    as_root mkfs.vfat -F 32 -n FILES "$files" >/dev/null
  fi

  if ((isos_part)); then
    esp=$(part_of ESP) || die "the ESP partition did not show up"
    isos=$(part_of ISOS) || die "the ISOS partition did not show up"
    as_root mkfs.vfat -F 32 -n ESP "$esp" >/dev/null
    as_root mkfs.ext4 -q -F -m 0 -T largefile -L ISOS "$isos"
    mount_at "$esp" "$work/esp"
    as_root grub-install --target=x86_64-efi --efi-directory="$work/esp" \
      --boot-directory="$work/esp/boot" --removable --no-nvram "$disk"
    grub_cfg "$(as_root blkid -s UUID -o value "$isos")" "$serial" | as_root tee "$work/esp/boot/grub/grub.cfg" >/dev/null
    umount_at "$work/esp"
    mount_isos
    copy_isos
    signed_isos "${names[@]}"
  fi

  as_root sfdisk --verify --quiet "$disk" || die "the partition table does not verify"
  if ((nokey == 0)); then
    local keyopt=()
    if ((pin)); then keyopt=(-pin); fi
    as_root dotnix-key create -yes -force "${keyopt[@]}" "$disk" ||
      die "the stick is ready, but without a key: run 'dotnix-key create' on it"
    as_root dotnix-key list
  fi
  say "done"
}

add() {
  (($# >= 2)) || die "add: DEVICE ISO..."
  open_stick "$1"
  shift
  check_isos "$@"
  mount_isos
  copy_isos
  signed_isos "${names[@]}"
  list_open
}

remove() {
  (($# >= 2)) || die "remove: DEVICE NAME..."
  open_stick "$1"
  shift
  mount_isos
  local name
  for name in "$@"; do
    as_root test -f "$work/isos/isos/$name" || die "$name is not on the stick"
  done
  for name in "$@"; do
    as_root rm "$work/isos/isos/$name"
    say "removed $name"
  done
  sync
  umount_at "$work/isos"
  signed_isos
  list_open
}

list_open() {
  mount_isos ro
  local f any=0 kind
  for f in "$work/isos/isos/"*.iso; do
    [ -f "$f" ] || continue
    any=1
    kind=$(iso_kind "$f")
    case $kind in
    loopback | nixos) ;;
    nixos-upstream) kind="not supported (upstream NixOS)" ;;
    *) kind="not supported" ;;
    esac
    printf '%-50s %8s  %s\n' "${f##*/}" "$(human "$(stat -c %s "$f")")" "$kind"
  done
  ((any)) || echo "no ISO on the stick"
  echo "free: $(human "$(free_bytes "$work/isos")")"
  umount_at "$work/isos"
}

list() {
  (($# == 1)) || die "list: DEVICE"
  open_stick "$1"
  list_open
}

case ${1:-} in
create | add | remove | list)
  cmd=$1
  shift
  "$cmd" "$@"
  ;;
-h | --help | help)
  usage
  ;;
*)
  usage >&2
  exit 2
  ;;
esac
