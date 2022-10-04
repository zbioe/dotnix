{ stdenv, fetchFromGitHub, pkgconfig, libusbmuxd, libplist, speex, libav
, alsaLib, gtk3, libappindicator-gtk3, libjpeg_turbo }:
# Thanks nix-locate ! (do not forget to nix-index first)
# And to get only most relevant packages: nix-locate 'yoursearch' --top-level
# https://github.com/aramg/droidcam/tree/v1.5/linux
# libavutil-dev --> seems to be present in ffmpeg and libav
# libswscale-dev --> in ffmpeg and libav
# libasound2-dev --> alsaLib?
# libspeex-dev --> ffmpeg and speex
# libusbmuxd-dev --> ok
# libplist-dev --> ok
#
# gtk+-3.0               # Only needed for GUI client
# libappindicator3-dev   # Only needed for GUI client
# try gtk3-x11 maybe?

stdenv.mkDerivation rec {
  pname = "droidcam";
  version = "1.5";

  src = fetchFromGitHub {
    owner = "aramg";
    repo = "droidcam";
    rev = "v1.5";
    sha256 = "tIb7wqzAjSHoT9169NiUO+z6w5DrJVYvkQ3OxDqI1DA=";
  };

  sourceRoot = "source/linux";

  buildInputs = [ pkgconfig ];
  nativeBuildInputs = [
    libappindicator-gtk3
    speex
    libav
    gtk3
    libjpeg_turbo
    libusbmuxd
    libplist
    alsaLib
  ];

  makeFlags =
    [ "JPEG_DIR=${libjpeg_turbo.out}" "JPEG_LIB=${libjpeg_turbo.out}/lib" ];
  postPatch = ''
    sed -i -e 's:(JPEG_LIB)/libturbojpeg.a:(JPEG_LIB)/libturbojpeg.so:' Makefile
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp droidcam droidcam-cli $out/bin/
  '';

  meta = with stdenv.lib; {
    description = "DroidCam Linux client";
    homepage = "https://github.com/aramg/droidcam";
  };
}
