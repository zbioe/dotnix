# usb-stick: music (FAT32, for the car), Linux ISOs booted from files by GRUB, and the dotnix-key.

MUSIC_SIZE_MIB=4096
ESP_SIZE_MIB=512
MIB=$((1024 * 1024))

usage() {
  cat <<'EOF'
usage:
  usb-stick create [--pin | --no-key] [--yes] [--serial] DEVICE [ISO...]
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
  p=$(part_of ISOS) || die "$disk was not made by usb-stick (no ISOS partition): use create"
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

  local total isos_part usable need=0 s
  total=$(as_root blockdev --getsize64 "$disk")
  isos_part=$((total - (2 + MUSIC_SIZE_MIB + ESP_SIZE_MIB) * MIB))
  ((isos_part >= 256 * MIB)) || die "$disk is too small: $(human "$total")"
  usable=$((isos_part - isos_part / 50 - 128 * MIB))
  for s in "${sizes[@]}"; do need=$((need + s)); done
  ((need <= usable)) || die "the ISOs need $(human "$need"), $disk has about $(human "$usable") for them"

  lsblk -o NAME,SIZE,TRAN,MODEL,FSTYPE,LABEL "$disk"
  echo "EVERYTHING on $disk is erased: MUSIC ${MUSIC_SIZE_MIB}MiB, ESP ${ESP_SIZE_MIB}MiB, ISOS $(human "$isos_part")."
  if ((yes == 0)); then
    local answer
    read -rp "Type ${args[0]} to continue: " answer
    [ "$answer" = "${args[0]}" ] || die "aborted"
  fi

  as_root wipefs -aq "$disk"
  printf '%s\n' "label: gpt" \
    "size=${MUSIC_SIZE_MIB}MiB, type=EBD0A0A2-B9E5-4433-87C0-68B6B72699C7, name=MUSIC" \
    "size=${ESP_SIZE_MIB}MiB, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name=ESP" \
    "type=0FC63DAF-8483-4772-8E79-3D69D8477DE4, name=ISOS" |
    as_root sfdisk --quiet --wipe always --wipe-partitions always "$disk"
  as_root udevadm settle 2>/dev/null || true
  local music esp isos
  music=$(part_of MUSIC) || die "the MUSIC partition did not show up"
  esp=$(part_of ESP) || die "the ESP partition did not show up"
  isos=$(part_of ISOS) || die "the ISOS partition did not show up"
  as_root mkfs.vfat -F 32 -n MUSIC "$music" >/dev/null
  as_root mkfs.vfat -F 32 -n ESP "$esp" >/dev/null
  as_root mkfs.ext4 -q -F -m 0 -T largefile -L ISOS "$isos"

  mount_at "$esp" "$work/esp"
  as_root grub-install --target=x86_64-efi --efi-directory="$work/esp" \
    --boot-directory="$work/esp/boot" --removable --no-nvram "$disk"
  grub_cfg "$(as_root blkid -s UUID -o value "$isos")" "$serial" | as_root tee "$work/esp/boot/grub/grub.cfg" >/dev/null
  umount_at "$work/esp"

  if ((${#names[@]})); then
    mount_isos
    copy_isos
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
