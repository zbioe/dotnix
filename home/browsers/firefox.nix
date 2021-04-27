{ config, lib, pkgs, ... }:

{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox;
    extensions = with pkgs.nur.repos.rycee.firefox-addons; [
      # manage your secrets (security)
      bitwarden
      # local emulation of content delivery networks (privacy, security)
      decentraleyes
      # Makes YouTube stream H.264 videos instead of VP8/VP9 videos (speed)
      h264ify
      # automatically use https (security)
      https-everywhere
      # organize your tabs in container topics (organization)
      multi-account-containers
      # temporary containers islating context (securit, organization)
      temporary-containers
      # block invisible trackers (security, privacy)
      privacy-badger
      # ad block (privacy)
      ublock-origin
      # vim keyboard (movement)
      vimium
      # dark reader (eyes)
      darkreader
    ];
  };
}
