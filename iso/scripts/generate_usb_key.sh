#!/usr/bin/env sh
file="$(uuid).lek"
size="4096"
dd if=/dev/urandom bs=1 count=${size} >"${file}"
sudo cryptsetup luksAddKey /dev/disk/by-label/luks "${file}"
