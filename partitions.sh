#!/bin/sh
# create partitions for nixos system
#  - disk password encryption by ZFS native feature
#  - (optional/warning) swap
#  - reserved size

set -euo pipefail
set -x

# find location of dev in /dev/disk-by-id
find_disk(){
  dev=$1
  for disk in /dev/disk/by-id/*; do
    readlink -f $disk | grep -wq $dev \
      && echo -n $disk \
      && break
  done
}

# disk by-id used by system
# documentation recomendation for /dev/disk/by-id/*
# for zpool
DISK=${DISK:-$(find_disk /dev/sda)}

# reserved size to recover when disk exceeded size
# you can't even remove files when disk is full
RESERVED_SIZE=${RESERVED_SIZE:-1G}

# swap could cause deadlock problems
# see: https://github.com/openzfs/zfs/issues/7734
SWAP_ENABLED=${SWAP_ENABLED:-true}
SWAP_SIZE=${SWAP_SIZE:-4G}

# pass password as file (priority to this flag over env)
PASSWORD_FILE=${PASSWORD_FILE:-/dev/stdin}

# pass password as env (priority to password_file)
PASSWORD=${PASSWORD:-insecure}

# create pool attempts configurations
ATTEMPTS_MAX=${ATTEMPTS_MAX:-3}
ATTEMPTS_TIME_RETRY=${ATTEMPTS_TIME_RETRY:-1s}

# gpt partition
sgdisk --zap-all $DISK
# boot legacy (BIOS)
sgdisk -a1 -n1:34:2047 -t1:EF02 -c 1:bios $DISK
# EFI support
sgdisk -n2:1M:+512M -t2:EF00 -c 2:efi $DISK
# root partition
sgdisk -n3:0:0 -t3:BF01 -c 3:root $DISK

# sometimes zpool could get fast and have problems
# attempts prevent this to break installation
# and give it a time to get things up
attempts=0
while true; do
  # full encryptation disk
  echo $PASSWORD | \
    zpool create -f \
          -o ashift=12 \
          -o altroot="/mnt" \
          -O acltype=posixacl \
          -O xattr=sa \
          -O mountpoint=none \
          -O atime=off \
          -O compression=lz4 \
          -O encryption=aes-256-gcm \
          -O keyformat=passphrase \
          -O keylocation=file://$PASSWORD_FILE \
          zroot \
          $DISK-part3 \
    && break || echo "retrying create pool"
  attempts=$((attempts+1))
  (($attempts == $ATTEMPTS_MAX)) \
    && echo "max attempts create zfs error" \
    && exit 1
  sleep $ATTEMPTS_TIME_RETRY
done

# Avoid disk space problems reserving 1G of disk
# without disk space you can't do nothing in ZFS
# even delete a file
# From wiki: https://nixos.wiki/wiki/NixOS_on_ZFS
## To recover the space when disk is fully just run
## zfs set refreservation=none zroot/reserved
zfs create -o refreservation=$RESERVED_SIZE \
    -o sync=disabled \
    -o mountpoint=none \
    zroot/reserved

# root partition
zfs create \
    -o mountpoint=legacy \
    -o com.sun:auto-snapshot=true \
    zroot/root

# nixos partition
zfs create \
    -o com.sun:auto-snapshot=true \
    -o mountpoint=legacy \
    zroot/root/nixos

# home partition separated for easily multi-os installation
zfs create \
    -o mountpoint=legacy \
    -o com.sun:auto-snapshot=true \
    zroot/home

# tmp partition
zfs create \
    -o mountpoint=legacy \
    -o sync=disabled \
    zroot/root/tmp

# WARNING: For now swap could cause a deadlok in some stress cases
# https://github.com/openzfs/zfs/issues/7734
[ "$SWAP_ENABLED" = true ] \
  && zfs create -V $SWAP_SIZE -b $(getconf PAGESIZE) \
      -o compression=zle \
      -o logbias=throughput -o sync=standard \
      -o primarycache=metadata -o secondarycache=none \
      -o com.sun:auto-snapshot=false zroot/swap \
  && mkswap -f /dev/zvol/zroot/swap \
  && swapon /dev/zvol/zroot/swap

# mount root
mount -t zfs zroot/root/nixos /mnt
# create partitions mountpoints
mkdir /mnt/{home,tmp,boot}
# mount efi
mkfs.vfat $DISK-part2
mount $DISK-part2 /mnt/boot
# mount home
mount -t zfs zroot/home /mnt/home
# mount tmp
mount -t zfs zroot/root/tmp /mnt/tmp/

# generate hardware-config.nix with machine
# and partitions configuration
nixos-generate-config --root /mnt
