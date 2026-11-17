# MpireOS ISO

The live ISO is Arch Linux's `releng` archiso profile with MpireOS layered on top.

| Path | Purpose |
|---|---|
| `build.sh` | Assembles the profile and runs `mkarchiso` |
| `packages.x86_64` | Packages added on top of releng's list |
| `pacman.conf.in` | Pacman config pinned to the channel's Arch snapshot |
| `airootfs/` | Files copied into the live system (live user, SDDM autologin, branding) |
| `syslinux/` | The BIOS boot menu (MpireOS look; `splash.png` from `../branding/make-boot-art.py`) |
| `grub/` | The UEFI boot menu, using the GRUB theme from `../packages/mpire-branding` |
| `../channels/` | The Arch snapshot date for each channel |
| `../scripts/smoke-test.sh` | Boots the ISO in QEMU and waits for the desktop |
| `../scripts/boot-screens.sh` | Screenshots of each boot stage (menus, splash) on BIOS, UEFI and an installed disk |

## Building locally

On Arch Linux, as root:

```sh
pacman -S --needed archiso grub
./iso/build.sh stable out
```

Anywhere with Docker:

```sh
docker run --rm --privileged -v "$PWD:/src" -w /src archlinux:latest \
  bash -c "pacman -Syu --noconfirm --needed archiso && ./iso/build.sh stable /src/out"
```

## Testing

```sh
scripts/smoke-test.sh out/mpireos-*.iso
```

Or boot it with a window: `qemu-system-x86_64 -enable-kvm -m 4096 -cdrom out/mpireos-*.iso`.

CI builds and boot-tests the ISO on every pull request. Download it from the run's **mpireos-iso** artifact.
