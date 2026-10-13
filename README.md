# Dotnix

My NixOS setup: system and home-manager in one flake, for my desktop (`bx`)
and laptop (`te`).

The disk is LUKS with btrfs on top. It unlocks from a key hidden inside an
ordinary USB stick, and falls back to the password after 10 seconds.

The desktop is [mango](https://github.com/DreamMaoMao/mangowc) with
[noctalia](https://github.com/noctalia-dev/noctalia-shell) as the bar,
launcher, notifications and lock screen. Hyprland is still there as a
second session.

![overview](./assets/overview.png)

## Themes

There are 30 themes, each with a light and a dark variant (or `auto`, which
follows the sun). Everything is built ahead of time, so switching is instant:
the bar, terminals, GTK apps, Chromium/Brave, Emacs, the wallpaper and the
boot splash all change together. Pick one from the palette icon in the bar,
or from the terminal:

```sh
theme set gruvbox dark
theme toggle        # light <-> dark
theme list
```

![themes](./assets/themes.png)

## Shortcuts

`Super+/` opens a list of every key binding. The list is generated from the
same file that defines the binds (`home/ui/mango.nix`), so it never goes out
of date.

![shortcuts](./assets/shortcuts.png)

The ones I use most:

| Key | Does |
|---|---|
| `Super+Enter` | terminal |
| `Super+P` | launcher |
| `Super+1..0` | go to tag |
| `Super+Shift+1..0` | move window to tag |
| `Super+H/J/K/L` | move focus |
| `Super+Shift+Q` | close window |
| `Super+V` | clipboard history |
| `Super+Shift+U` | rebuild system and home |

## Install

Build the installer ISO and write it to a USB stick:

```sh
nix build .#nixosConfigurations.minimal-iso.config.system.build.isoImage
dd if=result/iso/nixos-minimal-<version>.iso of=/dev/sdX
```

Boot from it, then partition, encrypt and install a minimal system:

```sh
iso/scripts/setup.sh -p "<luks password>"
iso/scripts/update-hardware.sh <hardware file>
cp iso/minimal-configuration.nix .
vim minimal-configuration.nix   # user, password, hostname
systemctl reboot -i
```

Once it boots from the disk, set your user in `flake.nix`, edit
`default/config.nix` and `default/key.nix`, and add
`hosts/<host>/default.nix` and `hosts/<host>/hardware.nix`. Then:

```sh
sudo nixos-rebuild switch --flake .#<host>
home-manager switch --flake .#<host>
```

After that, `rebuild` (or `Super+Shift+U`) does both.

## USB key

The LUKS key sits in the gap before the stick's first partition, so the
stick still works as a normal drive. Put some files on it and nobody will
guess it is a key. See also the [wiki](https://nixos.wiki/wiki/Full_Disk_Encryption).

Create the key and add it to LUKS:

```sh
dd if=/dev/random of=hdd.key bs=4096 count=1
cryptsetup luksAddKey /dev/disk/by-uuid/<luks uuid> ./hdd.key
```

Partition the stick with `fdisk`, leaving at least 6144 bytes before the
first partition, and format that partition as vfat. Then write the key 2048
bytes in:

```sh
dd if=hdd.key of=/dev/disk/by-id/<usb id> bs=1 seek=2048
```

And point the host's `hardware.nix` at it:

```nix
boot.initrd.luks.devices.enc = {
  device = "/dev/disk/by-uuid/<luks uuid>";
  keyFile = "/dev/disk/by-id/<usb id>";
  keyFileSize = 4096;
  keyFileOffset = 2048;
  keyFileTimeout = 10; # then ask for the password
};
```
