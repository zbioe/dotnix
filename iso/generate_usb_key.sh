#!/usr/bin/env sh
file="$(uuid).lek"
dd if=/dev/urandom bs=1 count=256 >"${file}"
sudo cryptsetup luksAddKey /dev/disk/by-label/luks "${file}"
