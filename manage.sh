#!/usr/bin/env bash

set -xeuo pipefail
[ "${DEBUG:-false}" == true ] && set -x

binpath=$(readlink -f "$0")
current_dir=$(dirname "$binpath")
BASEDIR=${BASEDIR:-$current_dir}

usage() {
  x=$(basename "$binpath")
  cat <<EOF
Usage:
  $x [OPTION]

Options:
  -h, --help             Show this message
  -u, --update <module>  Update module (home|system|all)
  -i, --install <module> Install module (home|system|all)

Modules:
  home    home-manager (~/.config/nixpkgs/)
  system  nixos (/etc/nixos/configuration.nix)

Examples:
  $x -i home             # install home
  $x -u home             # update home
  $x -i system           # install system (after create partitions)
  $x -u system           # update system
  $x -u system -u home   # update system and home

Envs:
  DEBUG=true|false   # set debug (default false)
  INFO=true|false    # set info (default true)

EOF
}

log(){
  [ "${INFO:-true}" == true ] && echo "$@"
}

err() {
  echo "err: $*"
  usage
  exit 1
}

update_system_files(){
  basedir=$*
  log update system files
  # do not remove hardware configuration
  GLOBIGNORE=$basedir/hardware-configuration.nix
  # replace all system modules
  sudo rm -rf "$basedir"/*
  sudo cp -rf system/. "$basedir"
}

install_system(){
  log install system
  unstable_channel

  sudo mkdir /mnt/share
  sudo chmod 775 /mnt/share
  sudo chown :users /mnt/share
  cp imgs/wallpaper.png /mnt/share

  update_system_files /mnt/etc/nixos

  sudo nixos-install

  # libvirt requirements
  images=/var/lib/libvirt/images
  sudo mkdir -p $images
  sudo chgrp libvirtd $images
  sudo chmod g+w $images
  sudo virsh pool-define-as default dir --target $images
  sudo virsh pool-autostart default
  sudo virsh pool-start default
}

update_system(){
  log update system
  update_system_files /etc/nixos
  log nixos rebuild switch
  sudo nixos-rebuild switch
}

unstable_channel(){
  log add unstable channel
  sudo nix-channel --add https://nixos.org/channels/nixos-unstable nixos
  sudo nix-channel --update
}

install_home(){
  log install home
  mkdir -p "$HOME"/.config/nixpkgs/
  update_home_files
  nix-channel \
    --add https://github.com/rycee/home-manager/archive/master.tar.gz \
    home-manager
  nix-channel --update

  nix-shell '<home-manager>' -A install

  multilockscreen -u home/imgs/wallpaper.png
}

update_home(){
  log update home
  update_home_files

  log home manager switch
  home-manager switch
}

update_home_files(){
  basedir=$HOME/.config/nixpkgs
  log update home files
  rm -rf "${basedir:?missing basedir}"/*
  cp -rf home/. "$basedir"
}

[ $# -lt 1 ] && err "missing option"

case $1 in
  "-h"|"--help")
    usage
    exit 0;;
esac

[ $# -lt 2 ] && err "missing option"

case $2 in
  system|home);;
  *) err "invalid module: $1";;
esac

cd "${BASEDIR}"

while [ $# -gt 0 ] ; do
  nSkip=2
  module=$2
  case $1 in
    "--update"|"-u")
      update_"$module"
      ;;
    "--install"|"-i")
      install_"$module"
      ;;
    *)
      err "invalid option: $1"
      ;;
  esac
  shift $nSkip
done

