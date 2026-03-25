#!/usr/bin/env bash
cd ~/dotnix
sudo nixos-rebuild switch --flake .#$(hostname)
