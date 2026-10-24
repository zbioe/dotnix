# The whole desktop as a live USB (iso/live.nix)
{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/installer/cd-dvd/iso-image.nix"
    # initrd modules and firmware for whatever machine it lands on
    "${modulesPath}/profiles/all-hardware.nix"
    ./live.nix
    ./findiso.nix
  ];

  isoImage = {
    edition = "dotnix";
    volumeID = "DOTNIX";
    makeEfiBootable = true;
    makeUsbBootable = true;
    # the smallest image (a 32 GB drive): slower to build, as fast to read
    squashfsCompression = "zstd -Xcompression-level 19";
  };
}
