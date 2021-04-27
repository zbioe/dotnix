{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [ rust cargo rustc rust-analyzer rustup ];
}
