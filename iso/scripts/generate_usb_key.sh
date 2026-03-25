#!/usr/bin/env sh
file="$(uuid).lek"
size="4096"
pendrive=$1
dd if=/dev/urandom bs=1 count=${size} >"${file}"
dd if="${file}" of="$1" bs=1 seek=2048 count=${size} conv=fsync
sudo cryptsetup luksAddKey /dev/disk/by-label/luks "${file}"
