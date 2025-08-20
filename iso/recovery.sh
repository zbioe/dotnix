#!/usr/bin/env sh

disk=${disk:-/dev/nvme0n1}
mapfile -t parts < <(lsblk -l $disk -p -o name -n | grep -v ^$disk$)

cryptsetup luksOpen ${parts[3]} enc
mount -t btrfs /dev/mapper/enc /mnt
mount -o subvol=root,compress=zstd,noatime /dev/mapper/enc /mnt

mount -o subvol=home,compress=zstd,noatime /dev/mapper/enc /mnt/home
mount -o subvol=nix,compress=zstd,noatime /dev/mapper/enc /mnt/nix
mount -o subvol=persist,compress=zstd,noatime /dev/mapper/enc /mnt/persist
mount -o subvol=log,compress=zstd,noatime /dev/mapper/enc /mnt/var/log
mount ${parts[1]} /mnt/boot

nixos-enter --root /mnt
