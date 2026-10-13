# Dark Reader that also accepts theme updates from the nix-theme extension
# (pkgs/nix-theme), so pages follow `theme` live. Firefox: same add-on id, so
# the profile keeps its settings. Chromium: an unpacked MV3 build with the
# Web Store id (`key`), loaded by the browsers' wrappers in its place.
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  jq,
  unzip,
  zip,
}:
buildNpmPackage rec {
  pname = "darkreader-theme-bridge";
  version = "4.9.133";

  src = fetchFromGitHub {
    owner = "darkreader";
    repo = "darkreader";
    rev = "v${version}";
    hash = "sha256-dtFsM4xeiBoF9mNRC8Y1RN1/boW/cGVim4UZBFUCBtc=";
  };

  patches = [ ../../patches/darkreader-theme-bridge.patch ];

  npmDepsHash = "sha256-FsuIsoVHYOBnG0RiryCoKmh3B8f/FbOihMPh3c7nKXw=";
  buildPhase = ''
    runHook preBuild
    node --max-old-space-size=3072 tasks/cli.js build --release --firefox --chrome-mv3
    runHook postBuild
  '';

  nativeBuildInputs = [
    jq
    unzip
    zip
  ];

  # bump the version above the AMO release so it replaces it in the profile
  installPhase = ''
    runHook preInstall
    mkdir xpi
    unzip -q build/release/darkreader-firefox.xpi -d xpi
    jq '.version = "${version}.1"' xpi/manifest.json > manifest.json
    mv manifest.json xpi/manifest.json
    mkdir -p $out
    (cd xpi && zip -qr $out/darkreader.xpi .)
    mkdir $out/chromium
    unzip -q build/release/darkreader-chrome-mv3.zip -d $out/chromium
    # Chromium keeps running a cached copy of an extension's service worker
    # until both its address and the extension version change: both follow
    # the build's hash (the version stays above the Web Store release)
    hash=$(cat $out/chromium/background/index.js $out/chromium/inject/*.js | sha256sum | cut -c1-12)
    sw=background/index-$hash.js
    mv $out/chromium/background/index.js $out/chromium/$sw
    jq --arg key ${lib.escapeShellArg chromiumKey} --arg sw "$sw" --arg v "${version}.$((16#''${hash:4:4}))" \
      '.key = $key | .version = $v | .background.service_worker = $sw' \
      $out/chromium/manifest.json > manifest.json
    mv manifest.json $out/chromium/manifest.json
    runHook postInstall
  '';

  # the Chrome Web Store release's public key (published with it): same id,
  # so this build takes the store install's place and keeps its settings
  chromiumKey = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqBY2tfTtJYiVMirbII2r3WofqCDaxS2zwPddSsgxUWKRm/MW/ymL2ZaP24MmwnegGIoxHkBVyi4cps4/q76c98ViyijoQvdJjAv3ZtUOwbWlYnZ5pU6gPCeZrScHxoTJdxxJJ30DZpMc6qsc3yJVQJlABG2FQFPrhPEGFLP9sCq/M7pY1xH++KsG+jYLB6cU3ItvZ4zntUXRwG2ZBx+XZelsd6FdkVXbDXj/47TNk2Qq8PAqyiK45GgQ+KJjuISAo89ip1xI4tONLCjSHPinD3nz6HiMikQzwn4L8SsB4Wy7rBhMhPRGIWbwHed+L+W3LXhB05Lhwk0YxuOb7QNWRQIDAQAB";

  passthru = {
    addonId = "addon@darkreader.org";
    chromiumId = "eimadpbcbfnmbkopoojfekhnkhdbieeh";
  };
}
