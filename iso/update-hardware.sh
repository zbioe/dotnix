#!/usr/bin/env sh

hf=${1:-hardware-auto.nix}

sed -i s/'"subvol=root" ]'/'"subvol=root" "compress=zstd" "noatime" ]'/ $hf
sed -i s/'"subvol=home" ]'/'"subvol=home" "compress=zstd" "noatime" ]'/ $hf
sed -i s/'"subvol=nix" ]'/'"subvol=nix" "compress=zstd" "noatime" ]'/ $hf
sed -i s/'"subvol=persist" ]'/'"subvol=persist" "compress=zstd" "noatime" ]'/ $hf
sed -i s/'"subvol=log" ]'/'"subvol=log" "compress=zstd" "noatime" ]; neededForBoot = true'/ $hf
nixfmt $hf

exit 0
