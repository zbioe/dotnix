# Dotnix

My NixOS setup, system and home in one flake: `bx` (desktop) and `te`
(laptop). [mango](https://github.com/DreamMaoMao/mangowc) with
[noctalia](https://github.com/noctalia-dev/noctalia-shell); LUKS and btrfs,
unlocked by a key hidden on a USB stick.

![overview](./assets/overview.png)

## Themes

30 themes, light and dark (or `auto`), built ahead of time: everything
switches at once. From the palette icon in the bar, or:

```sh
theme set gruvbox dark
theme toggle
theme list
```

![themes](./assets/themes.png)

Fonts and icons switch live too (right click the palette icon):

```sh
theme font term "Iosevka"       # roles: ui serif mono term emoji
theme font size +1
theme font preset plex
theme icons pack lucide
theme icons apps tela
```

`nix flake check` fails on a missing font family, tofu, or an icon from the
wrong font.

## Desktop

| Key | Does |
|---|---|
| `Super+/` | every key binding |
| `Super+Enter` | terminal |
| `Super+P` | launcher |
| `Super+1..0` / `Super+Shift+1..0` | go to tag / move window there |
| `Super+V` | clipboard history |
| `Super+Shift+U` | rebuild |

![shortcuts](./assets/shortcuts.png)

```sh
vpn up BR            # Proton or WireGuard; also from the shield in the bar
pw copy pass://VAULT/ITEM   # Proton Pass; /pw in the launcher
, cowsay hi          # any package without installing it (comma)
```

- Activity: ActivityWatch with a Grafana dashboard (`Activity` in the
  launcher), local only.
- Editors: [zmacs](https://github.com/zbioe/zmacs) (its own flake) and a small
  Neovim, both themed and formatting like `nix flake check`.
- `dotnix.packages.pentest` (HTB toolbox) and `dotnix.packages.media`.

## Security

- Kernel and sysctl hardening (privsec.dev), DNS over TLS with DNSSEC, NTS
  time, a MAC per network, Docker rootless, a locked-down LibreWolf.
- Secrets: `secrets/*.yaml` with sops, opened by your age key
  (`~/.config/sops/age/keys.txt`, keep a copy) and each host's SSH key.

```sh
sops secrets/common.yaml
dotnix-enroll <host> <address>   # a new host opens them
```

## Layout

```
lib/      hosts, homes, packages, checks
hosts/    one folder per machine; common.nix is the shared desktop
system/   NixOS modules      home/   home-manager modules
pkgs/     own packages       overlays/  patched nixpkgs packages
checks/   flake checks and VM tests      iso/  install images
```

An option's name is its file's path (`dotnix.storage.backup` is
`system/storage/backup.nix`); all off by default. `nix run .#options -- bx`
lists a host's.

## Install

```sh
nix build .#iso-full        # or .#iso-minimal
dd if=result/iso/*.iso of=/dev/sdX bs=4M conv=fsync
```

1. Boot it, run `dotnix-install`: disk, host, Secure Boot (firmware in Setup
   Mode), all offline from the full ISO.
2. On bx: `dotnix-adopt ADDRESS` (the new host into the flake and secrets).
3. The new host rebuilds itself once online and asks for a reboot.
4. `backup setup`, then restore.

`rebuild` after that. `dotnix-diff` shows what `/` got that impermanence will
wipe. What bx builds goes to [zbioe.cachix.org](https://zbioe.cachix.org).

A host installed before this layout: name its partitions
(`sgdisk -c 2:dotnix-efi -c 3:dotnix-swap -c 4:dotnix-luks`), and zero any
partition another OS left (`blkdiscard -z`, then remove its firmware entry).

## Secure Boot and TPM

Limine signed with the host's own keys (`/persist/var/lib/sbctl`, in the
backup), kernel and initrd hashes in its signed config; then the TPM opens the
disk with a PIN. Use one set of keys for every host. On an installed host:

1. `dotnix.core.boot.loader = "limine";`, rebuild, reboot.
2. Firmware setup: clear the Secure Boot keys.
3. `dotnix.core.boot.secureBoot.enable = true;`, rebuild (keys made and enrolled).
4. Reboot, turn Secure Boot on.
5. `dotnix.core.boot.tpm2.enable = true;`, rebuild, `dotnix-tpm2-enroll`.

## USB key

A random key in the gap before the first partition: the stick stays a normal
drive. No stick or a wrong PIN: the password.

```sh
sudo dotnix-key create [-pin] /dev/sdX
sudo dotnix-key list
sudo dotnix-key export /dev/sdX | sudo dotnix-key import /dev/sdY   # same key, same slot
```

## Multiboot stick

FILES (FAT32), a menu of ISOs and the disk key. Signed when made on a host
with Secure Boot keys.

```sh
nix run .#usb-stick -- create [--keep-key] /dev/sdX .#iso-full ~/Downloads/zorin.iso
nix run .#usb-stick -- add /dev/sdX other.iso
nix run .#usb-stick -- list /dev/sdX
```

## Checks

```sh
nix flake check            # hosts evaluate, tests, fonts, format, lint
nix build .#disk-test      # and the other *-test: VM tests, run by CI
nix run .#iso-closure      # the full ISO installs a host offline (~3 min)
nix build .#install-test   # dotnix-install end to end (~45 min, 8 GB): not in CI
```

`nix develop` (or direnv) installs the format and lint checks as a git hook.
