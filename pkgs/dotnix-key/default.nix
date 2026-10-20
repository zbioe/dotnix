{
  lib,
  buildGoModule,
  cryptsetup,
  systemd,
  util-linux,
  dosfstools,
}:
buildGoModule {
  pname = "dotnix-key";
  version = "2.0";
  src = lib.cleanSource ./.;
  vendorHash = null;

  env.CGO_ENABLED = 0;
  ldflags = [
    "-s"
    "-w"
    "-X main.cryptsetupBin=${lib.getExe' cryptsetup "cryptsetup"}"
    "-X main.askPasswordBin=${lib.getExe' systemd "systemd-ask-password"}"
  ];

  # the tests make disk images and LUKS volumes in files
  nativeCheckInputs = [
    cryptsetup
    util-linux
    dosfstools
  ];

  meta = {
    description = "LUKS key hidden in the gap of any USB stick";
    mainProgram = "dotnix-key";
  };
}
