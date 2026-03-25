#!/usr/bin/env bash
cd ~/dotnix
home-manager switch --flake .#$(hostname)
