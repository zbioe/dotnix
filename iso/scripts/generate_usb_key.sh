#!/usr/bin/env sh
file="$(uuid).lek"
size="256"
dd if=/dev/urandom bs=1 count=${size} >"${file}"
sudo cryptsetup luksAddKey /dev/disk/by-label/luks "${file}"
