# Dotnix

My NixOS setup: system and home-manager in one flake, for my desktop (`bx`)
and laptop (`te`).

The disk is LUKS with btrfs on top. It unlocks from a key hidden in any USB
stick, and falls back to the password after 10 seconds.

The desktop is [mango](https://github.com/DreamMaoMao/mangowc) with
[noctalia](https://github.com/noctalia-dev/noctalia-shell) as the bar,
launcher, notifications and lock screen.

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

## Fonts

Fonts switch live too: interface, serif, monospace, terminal and emoji each
pick from a catalog (`home/theme/fonts/catalog.nix`, all installed), with
their own sizes. GTK, Qt, the bar, Emacs, every terminal (foot through
`overlays/patches/foot-osc50-font.patch`, tmux inside too), Discord and Chromium/Brave
pages change at once; LibreWolf on its next start. Right click the palette
icon, or:

```sh
theme font                      # what is in use
theme font term "Iosevka"       # ROLE FAMILY: ui serif mono term emoji
theme font size +1              # every size; or: size term 9
theme font preset plex          # theme font presets
theme font list mono
theme font save work            # your own preset: fonts, sizes and icons
theme font default              # what reset goes back to (default clear: the catalog's)
theme font reset
```

Every icon of the bar comes from an icon pack (Tabler, Nerd Font, Material
Symbols outlined, rounded and sharp, Lucide, Font Awesome;
`home/theme/icons/catalog.nix`): the tags and every glyph a widget draws, each
state included (Wi-Fi levels, volume, battery...). Any of them can take any icon
of the pack, and app icons pick from 16 themes (Papirus, Numix, Tela, Qogir,
Fluent, WhiteSur, Colloid, Kora, Breeze, Yaru...), from the Icons and Apps tabs or:

```sh
theme icons pack lucide         # theme icons packs
theme icons find dice           # icons of the pack by name
theme icons tag 6 dice-6        # a tag's own icon; theme icons reset 6
theme icons bar wifi wifi-high  # a bar glyph's own icon; theme icons reset wifi
theme icons apps tela           # app icons (theme icons apps lists them)
theme icons tint on             # app icons in the theme's color
```

The bar's glyphs need `overlays/patches/noctalia-glyph-override.patch`: noctalia draws
them from its own Tabler font only.

`nix flake check` fails if a catalog family is missing from its package, if
any script, symbol or emoji would show as tofu, or if an icon would come from
the wrong font; building the icon index fails if a pack names an icon its font
lacks.

## VPN

The shield in the bar lights up while a VPN is up: right click connects to
the last place (or the fastest server) and disconnects; left click opens a
panel with quick connections (Fastest, Brazil, United States, Secure Core;
add any country, server or city) and WireGuard files. Proton goes through its
own CLI, so nothing opens; its app is a click away for every other setting.

```sh
vpn up BR            # fastest in a country; or BR#10, fastest, securecore, city:Tokyo
vpn down
vpn toggle           # the last one used
vpn fav add DE       # one more quick connection (the first ones: home/default.nix)
vpn add other.conf   # a WireGuard file from anywhere; vpn remove NAME
```

## Passwords

Proton Pass is in the launcher: `/pw github` finds an item and Enter copies
its password (marked secret, so it stays out of the clipboard history, and
cleared after 30 seconds); with few matches left, the username, e-mail,
one-time code and website show up too. Pass has its own lock code: it locks
with the screen and after 15 idle minutes, and the launcher asks for the code
in a small panel. The browsers come with its extension. The desktop app
follows Proton's newest stable release (`flake-updates`).

```sh
pass-cli login                                     # once
pass-cli session create-lock --idle-timeout 900    # the lock code
pw copy pass://VAULT/ITEM [username|email|note]    # pw search TEXT finds the URI
pw run terraform apply                             # ~/.env values like pass://Dev/AWS/key, resolved for one command
```

## Hardening

Following [Privacy Guides](https://www.privacyguides.org/en/desktop-browsers/),
[arkenfox](https://github.com/arkenfox/user.js) and
[privsec.dev](https://privsec.dev/posts/linux/desktop-linux-hardening/), as far
as they fit a desktop (SMT and user namespaces stay):

- kernel: hardened boot parameters (memory, IOMMU) and sysctls, no core dumps;
- time: chrony with NTS (authenticated, several operators);
- DNS: over TLS to Cloudflare, with DNSSEC;
- network: a stable MAC address of its own per network, no hostname in DHCP;
- VPN: while a WireGuard tunnel is up, the physical interfaces carry only the
  tunnel, the LAN and DHCP (Proton's kill switch lets programs bound to the
  interface out);
- Docker rootless (the docker group is root by another name); Flatpak apps
  get nothing unless allowed one by one;
- LibreWolf: its hardening locked, HTTPS only, nothing fetched ahead, a closed
  list of extensions; uBlock's rules and the sites that stay logged in are
  private (`secrets/librewolf.yaml`, `librewolf-save`).

## Secrets

The login password, searx's key and the Wi-Fi networks (names included) live
in `secrets/common.yaml`, encrypted with [sops](https://github.com/getsops/sops):
public, but only you and the hosts open it. At boot each host decrypts it
with its SSH host key into `/run/secrets` (RAM); a new install gets the
networks it lacks, so it connects by itself. Your key is
`~/.config/sops/age/keys.txt`: keep a copy in Proton Pass, it opens
everything.

```sh
sops secrets/common.yaml                # edit (opens decrypted, saves encrypted)
mkpasswd -m yescrypt                    # a new user-password hash
dotnix-enroll                           # this host opens it: .sops.yaml and updatekeys
dotnix-enroll <host> <address>          # another one, through its SSH host key
sops updatekeys secrets/common.yaml     # after changing .sops.yaml by hand
```

Only what can be changed if it ever leaks goes here (it is public for good);
personal secrets stay in Proton Pass.

## Shortcuts

`Super+/` opens a list of every key binding. The list is generated from the
same file that defines the binds (`home/desktop/mango`), so it never goes out
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

A command that isn't installed says which package has it, and `, cowsay hi`
runs it without installing ([comma](https://github.com/nix-community/comma),
over a prebuilt [nix-index](https://github.com/nix-community/nix-index-database)
database).

## Activity

Where the time goes, kept on this machine only: [ActivityWatch](https://activitywatch.net)
(`aw-server-rust` on `127.0.0.1:5600`, out of the backup) with a watcher for
everything: windows and AFK ([awatcher](https://github.com/2e3s/awatcher),
Wayland), the browsers' tabs (its extension, in all three), zmacs (buffer,
project, mode, function, org heading, typing and commands), every shell
command (fish), what plays (MPRIS), and the machine itself (CPU, GPU, memory,
temperatures, disk, network, the programs using them, VPN, Wi-Fi, Bluetooth,
audio output, generation). `Activity` in the launcher opens Grafana on
`127.0.0.1:5610` over it, started on the first visit and stopped after 30
idle minutes; the dashboard is `home/desktop/activity/dashboard.nix`.
LibreWolf's extension asks for consent once.

## Editors

[zmacs](https://github.com/zbioe/zmacs) and a small Neovim, both in Nix.
zmacs is its own flake: Emacs and every package pinned by
[twist.nix](https://github.com/emacs-twist/twist.nix), nothing fetched at
startup, with vterm, pdf-tools, mu4e and every tree-sitter grammar. It runs as
a daemon (`emacsclient -c`). Mail is mu4e over mbsync, Proton
through its Bridge, the password from `secrets/mail.yaml`.

Neovim (`home/editors/nvim`) is a short `init.lua`: tree-sitter, LSP, blink
completion, mini, fzf-lua, oil and gitsigns, no framework.

Both take their colours (and Emacs its fonts) from `theme` and format on save with the very tools
`nix flake check` uses, so a file looks the same whichever editor wrote it:
nixfmt for Nix, gofumpt, shfmt, black, stylua, prettier.

## Labs

`dotnix.packages.pentest` is the HackTheBox and HTB Academy toolbox: recon,
web, Active Directory, password cracking, reverse engineering, forensics,
pivoting and Metasploit. `$SECLISTS` points at the wordlists. Professional
video and audio editing (DaVinci Resolve, Kdenlive, Ardour, Reaper, OBS and
the rest) is in `dotnix.packages.media`.

## Layout

```
flake.nix     inputs; the outputs are built by lib/
lib/          hosts, homes, packages, checks; the option helpers
hosts/        one folder per machine (only what differs) and common.nix,
              the desktop both machines run
system/       NixOS: core, nix, hardware, storage, network, desktop,
              services, packages
home/         home-manager: shell, editors, desktop, theme, dev
pkgs/         our own packages
overlays/     nixpkgs packages with our patches
checks/       flake checks and VM tests
iso/          the install images
```

Anything that can be turned off is an option, and the option's name is the
file's path: `dotnix.storage.backup` lives in `system/storage/backup.nix`.
Everything is off by default; `hosts/common.nix` and `home/default.nix` turn
on the desktop, the hosts add their hardware. Options come in three kinds:

```nix
dotnix.desktop.browsers.enable = true;      # a group: all of it,
dotnix.desktop.browsers = {                 # or item by item, with a main one
  chromium.enable = true;
  default = "chromium";
};
dotnix.desktop.greeter = "sddm";            # one of a kind
dotnix.packages.dev = {                     # a package group
  enable = true;
  exclude = [ "julia" ];
};
```

The home follows the host's choices (`osConfig`): the desktop and the main
browser picked in `hosts/` are the home's defaults too.

## Install

`nix develop` has every tool used below (ISOs, sticks, the Go code).

Build an ISO and write it to a USB stick:

```sh
nix build .#iso-minimal   # or .#iso-full: this whole setup, live
dd if=result/iso/*.iso of=/dev/sdX bs=4M conv=fsync
```

Boot from it and run `dotnix-install`: it adds `hosts/<host>` to the flake,
formats its disk with the layout of `system/storage/disk.nix` (declared with
[disko](https://github.com/nix-community/disko), the same one the hosts mount)
and installs it. From the full ISO it needs no network: the ISO carries what
building a new host takes. The nixos-hardware modules of the CPU, GPU and disk
it finds go to `hosts/<host>/hardware.nix`, from the first `rebuild` on.
`dotnix-mount` opens an installed disk on `/mnt` for recovery.

Then `rebuild` (or `Super+Shift+U`) rebuilds system and home. With
impermanence, `dotnix-diff` lists what was written to `/` since boot and goes
away on the next one (`-a` with caches and `/tmp`): what may need a place in
`/persist`.

What bx builds (zmacs, the GTK4 swap, this flake's packages) goes to
[zbioe.cachix.org](https://zbioe.cachix.org) after each switch, so the other
hosts and CI download it instead of building; unfree packages stay out
(`system/services/cache.nix`).

## Checks

```sh
nix flake check            # every host evaluates, Go tests, fonts, formatting, dead code, lint
nix run .#options -- bx    # every dotnix.* option of a host and its value
nix fmt                    # format
nix build .#usb-key-test   # boots VMs: unlock from a stick, PIN, password fallback
nix build .#usb-stick-test # boots a VM from a multiboot stick
nix build .#disk-test      # installs on a VM as dotnix-install does, boots it
nix build .#secure-boot-test # Limine, Secure Boot keys, then the TPM and its PIN, on a VM
nix build .#install-test   # dotnix-install itself from the full ISO, offline (~1h)
```

## USB key

The key hides in the gap before the stick's first partition: the whole gap is
random bytes, the key somewhere in it, so the stick looks like any other and
keeps working as a normal drive. Next to the key goes a tag (HMAC-SHA512 made
with the key itself) naming the LUKS volume and key slot: at boot the initrd
reads the gap of every disk, recognizes the stick made for this disk in a few
milliseconds, and opens that one slot. Without the key the tag is just noise.

```sh
sudo dotnix-key create /dev/sdX        # a new key, in its own LUKS slot
sudo dotnix-key create -pin /dev/sdX   # the stick also needs a short PIN at boot
sudo dotnix-key adopt /dev/sdX         # a key written the old way (offset 2048)
sudo dotnix-key list                   # sticks found and what they open
```

Partitions and files are never touched, only the gap; a gap holding something
else (GRUB, Ventoy) is refused. Running `create` again replaces the stick's key
and revokes the old one. No stick, a stick for another machine or a wrong PIN
(three times): the password is asked.

Enable it on a host with `dotnix.storage.usbKey.enable = true;`.

## Secure Boot and TPM

`/boot` is not encrypted: with GRUB, whoever gets the machine for a while can
swap the initrd for one that keeps the disk password. With Secure Boot the
host boots Limine signed with its own keys (sbctl, made on the host, kept in
`/persist/var/lib/sbctl`), and Limine's signed config holds the hashes of every
kernel and initrd: anything changed doesn't boot. The TPM then opens the disk
with a short PIN, but only after that boot chain (PCR 7); the password and the
USB key still work.

Once per host, in this order:

1. `dotnix.core.boot.loader = "limine";`, rebuild and reboot (the boot menu
   is Limine's from now on).
2. In the firmware setup, clear the Secure Boot keys (Setup Mode).
3. `dotnix.core.boot.secureBoot.enable = true;` and `rebuild`: it makes the
   keys, enrolls them next to Microsoft's (GPU firmware needs those) and signs.
4. Reboot, turn Secure Boot on in the firmware; `sbctl status` shows it.
5. `dotnix.core.boot.tpm2.enable = true;`, rebuild, `dotnix-tpm2-enroll` (asks
   the disk password and the new PIN).

The boot starts with the default theme: the kernel command line is sealed, so
it can't follow `theme` as with GRUB (the session and SDDM still do). The ISOs
and the multiboot stick keep GRUB, unsigned: Secure Boot off to boot them.
`nix build .#secure-boot-test` goes through these steps on a VM.

## Multiboot stick

One stick for everything: a FILES partition (FAT32, first, up to 4GiB), a GRUB
menu of Linux ISOs and the disk key. Without ISOs, `create` makes only FILES
(the whole stick) and the key; with them, FILES shrinks to fit a small stick.

```sh
nix run .#usb-stick -- create /dev/sdX .#iso-full .#iso-minimal ~/Downloads/zorin.iso
nix run .#usb-stick -- add /dev/sdX ~/Downloads/other.iso   # or replace one
nix run .#usb-stick -- remove /dev/sdX other.iso
nix run .#usb-stick -- list /dev/sdX
```

GRUB lists `isos/*.iso` of the ISOS partition at every boot, so copying or
deleting files there by hand works too; `add` also checks that the ISO boots
from a file and fits, and reads the copy back. Unsupported ISOs show up in the
menu as such. Booting from a file works for ISOs with `boot/grub/loopback.cfg`
(Ubuntu, Zorin, Mint, Debian live, Arch...) and for the NixOS ISOs of this
flake (`iso/findiso.nix`); upstream NixOS ISOs can't, their initrd reads no ext4.
