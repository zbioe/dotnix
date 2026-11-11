# pam_either: a password or a fingerprint, whichever comes first (after
# Florian Bernier's pam-race, see src/lib.rs)
{
  lib,
  rustPlatform,
  linux-pam,
}:
rustPlatform.buildRustPackage {
  pname = "pam-either";
  version = "0.1.0";
  src = lib.cleanSource ./.;
  cargoLock.lockFile = ./Cargo.lock;

  buildInputs = [ linux-pam ];

  postInstall = ''
    mkdir -p $out/lib/security
    mv $out/lib/libpam_either.so $out/lib/security/pam_either.so
    rm -f $out/lib/*.rlib
  '';

  meta = {
    description = "PAM module: a password or a fingerprint, whichever comes first";
    platforms = lib.platforms.linux;
    mainProgram = "pam-either-helper";
  };
}
