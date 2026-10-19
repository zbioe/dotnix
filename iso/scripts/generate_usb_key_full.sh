#!/usr/bin/env bash
set -euo pipefail

# Layout:
#   [0–1 MiB gap]  → keyfile at byte offset 2048
#   p1 MUSIC       → FAT32 (visible to car)
#   p2 ESP         → GRUB + grub.cfg
#   p3 ISOS        → ext4, label ISOS (holds the ISO files)

DEVICE="${1:-/dev/sda}"
KEY_SIZE=4096
KEY_SEEK=2048
MUSIC_SIZE_MIB=4096
ESP_SIZE_MIB=512
LUKS_LABEL="luks"

ISO_FULL="${HOME}/iso/full/iso/nixos-dotnix-26.05.20261013.53fd9a0-x86_64-linux.iso"
ISO_MINIMAL="${HOME}/iso/minimal/iso/nixos-minimal-26.05.20261013.53fd9a0-x86_64-linux.iso"
ISO_THIRD="${HOME}/Downloads/Zorin-OS-18.1-Core-64-bit.iso"

cleanup() {
  sudo umount /mnt/music /mnt/esp /mnt/isos 2>/dev/null || true
}
trap cleanup EXIT

# --- Pre-flight ---
for cmd in parted mkfs.vfat mkfs.ext4 grub-install blockdev; do
  command -v "$cmd" >/dev/null || {
    echo "Missing: $cmd"
    exit 1
  }
done

if ! [[ -f "$(dirname "$(command -v grub-install)")/../lib/grub/x86_64-efi/modinfo.sh" ]]; then
  echo "Erro: GRUB sem suporte EFI."
  echo "Rode o script assim:"
  echo "  nix-shell -p 'grub2.override { efiSupport = true; }' --run '$0 $@'"
  exit 1
fi

[[ -b "${DEVICE}" ]] || {
  echo "${DEVICE} is not a block device"
  exit 1
}

if findmnt -n "${DEVICE}"* >/dev/null 2>&1; then
  echo "${DEVICE} or its partitions are mounted. Unmount first."
  exit 1
fi

echo "=== Target: ${DEVICE} ==="
lsblk "${DEVICE}" || true
read -rp "Type YES to continue: " confirm
[[ "${confirm}" == "YES" ]] || {
  echo "Aborted."
  exit 1
}

DISK_MIB=$(sudo blockdev --getsize64 "${DEVICE}" | awk '{print int($1/1024/1024)}')
NEEDED=$((1 + MUSIC_SIZE_MIB + ESP_SIZE_MIB + 2048))
((DISK_MIB >= NEEDED)) || {
  echo "Disk too small (${DISK_MIB} MiB)"
  exit 1
}

# --- Collect ISOs ---
ISOS=()
[[ -f "${ISO_FULL}" ]] && ISOS+=("${ISO_FULL}")
[[ -n "${ISO_MINIMAL}" && -f "${ISO_MINIMAL}" ]] && ISOS+=("${ISO_MINIMAL}")
[[ -n "${ISO_THIRD}" && -f "${ISO_THIRD}" ]] && ISOS+=("${ISO_THIRD}")

echo "ISOs: ${#ISOS[@]}"
printf '  - %s\n' "${ISOS[@]}"

# --- Partition ---
echo "=== Partitioning ==="
sudo wipefs -a "${DEVICE}"
sudo parted "${DEVICE}" --script mklabel gpt

MUSIC_END=$((1 + MUSIC_SIZE_MIB))
ESP_END=$((MUSIC_END + ESP_SIZE_MIB))

sudo parted "${DEVICE}" --script \
  mkpart MUSIC fat32 1MiB "${MUSIC_END}MiB" \
  mkpart ESP fat32 "${MUSIC_END}MiB" "${ESP_END}MiB" \
  set 2 esp on \
  mkpart ISOS ext4 "${ESP_END}MiB" 100%

sudo partprobe "${DEVICE}" || true
sudo udevadm settle

# --- Format ---
echo "=== Formatting ==="
sudo mkfs.vfat -F32 -n MUSIC "${DEVICE}1"
sudo mkfs.vfat -F32 -n ESP "${DEVICE}2"
sudo mkfs.ext4 -F -L ISOS "${DEVICE}3"

# --- Keyfile ---
echo "=== Keyfile at offset ${KEY_SEEK} ==="
KEY_FILE="$(command -v uuidgen >/dev/null && uuidgen || date +%s).lek"
dd if=/dev/urandom bs=1 count="${KEY_SIZE}" of="${KEY_FILE}" status=none
sudo dd if="${KEY_FILE}" of="${DEVICE}" bs=1 seek="${KEY_SEEK}" count="${KEY_SIZE}" conv=fsync status=progress

if [[ -e "/dev/disk/by-label/${LUKS_LABEL}" ]]; then
  sudo cryptsetup luksAddKey "/dev/disk/by-label/${LUKS_LABEL}" "${KEY_FILE}" ||
    echo "Warning: luksAddKey failed"
else
  echo "Warning: LUKS label '${LUKS_LABEL}' not found"
fi

# --- Mount ---
echo "=== Mounting ==="
sudo mkdir -p /mnt/music /mnt/esp /mnt/isos
sudo mount "${DEVICE}1" /mnt/music
sudo mount "${DEVICE}2" /mnt/esp
sudo mount "${DEVICE}3" /mnt/isos

# --- GRUB ---
echo "=== Installing GRUB ==="
sudo mkdir -p /mnt/esp/EFI/BOOT /mnt/esp/boot/grub
sudo grub-install \
  --target=x86_64-efi \
  --efi-directory=/mnt/esp \
  --boot-directory=/mnt/esp/boot \
  --removable \
  "${DEVICE}"

# --- Copy ISOs ---
echo "=== Copying ISOs ==="
sudo mkdir -p /mnt/isos/isos
for iso in "${ISOS[@]}"; do
  sudo cp -v "${iso}" /mnt/isos/isos/
done

# --- grub.cfg ---
echo "=== Writing grub.cfg ==="
{
  cat <<'EOF'
insmod part_gpt
insmod fat
insmod ext2
insmod search
insmod loopback
insmod iso9660

set timeout=8
set default=0
search --label ISOS --set=root
EOF
  echo
  for iso in "${ISOS[@]}"; do
    base="$(basename "${iso}")"
    name="${base%.iso}"
    cat <<EOF
menuentry "${name}" {
    loopback loop /isos/${base}
    set iso_path="/isos/${base}"
    linux (loop)/boot/bzImage findiso=\${iso_path}
    initrd (loop)/boot/initrd
}

EOF
  done
} | sudo tee /mnt/esp/boot/grub/grub.cfg >/dev/null

sync
echo
echo "=== Done ==="
echo "Keyfile: ${KEY_FILE}"
echo "Music:   ${DEVICE}1 (FAT32)"
echo "ESP:     ${DEVICE}2"
echo "ISOs:    ${DEVICE}3 (label ISOS)"
echo "Key at raw offset ${KEY_SEEK}"
echo
echo "If an ISO fails to boot, mount it and copy the exact linux/initrd lines from its grub.cfg or loopback.cfg."
