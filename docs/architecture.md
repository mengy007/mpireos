# MpireOS architecture

Status: draft, v0.0. This document describes how MpireOS is built and why. Open an issue to challenge any part of it.

## Goals

1. **A cohesive, polished desktop** that feels like one product.
2. **Arch ecosystem, calm updates.** Access to Arch's packages, the AUR, and the Arch Wiki, without the breakage risk of tracking Arch directly.
3. **Every change is reversible.** A bad update costs one reboot, not an evening.
4. **US-based and auditable.** Public builds, signed releases, no telemetry by default.
5. **Progressive ownership.** Ship early on proven components, then replace them with MpireOS's own one at a time.

## Non-goals for v0.1

- Architectures other than x86_64
- Secure Boot (planned before v1.0)
- An immutable or image-based root filesystem
- MpireOS's own browser, office suite, or kernel fork

## Overview

```
┌─────────────────────────────────────────────────────────┐
│ MpireOS desktop components (Qt 6 / QML, from v0.3)       │
│ dock · launcher · control center · welcome · software    │
├─────────────────────────────────────────────────────────┤
│ KDE Plasma 6 on Wayland, with MpireOS theme and defaults │
├─────────────────────────────────────────────────────────┤
│ mpire packages: branding, configs, mpire-update, ...     │
├─────────────────────────────────────────────────────────┤
│ Arch Linux packages, from a tested, dated snapshot       │
├─────────────────────────────────────────────────────────┤
│ Btrfs + snapper + grub-btrfs (rollback)                  │
└─────────────────────────────────────────────────────────┘
```

## Base system

MpireOS is Arch Linux underneath. It uses pacman, Arch's package format, and Arch's package set, so the Arch Wiki applies almost unchanged.

The difference is **where packages come from and when**.

### Package channels

MpireOS does not point systems at live Arch mirrors. It points them at **dated snapshots** of Arch, which MpireOS promotes through channels after testing.

| Channel | What it is | Who it is for |
|---|---|---|
| `testing` | A recent Arch snapshot, typically a few days old | Contributors and testers |
| `stable` | A snapshot that passed testing, promoted roughly every two weeks | Everyone else (default) |

How promotion works:

1. A scheduled CI job picks a new Arch snapshot date and points `testing` at it.
2. Automated tests run: build the ISO from that snapshot, boot it in QEMU, run an install, run an update from the previous `stable` to this one, and check that the desktop session starts.
3. Testers run `testing` on real hardware for about a week.
4. If nothing blocking is found, a maintainer promotes the snapshot to `stable`. Urgent security fixes can be promoted early.

**v0.1 implementation:** each channel is a pacman mirrorlist pointing at a dated path on the [Arch Linux Archive](https://archive.archlinux.org/repos/) (for example `.../repos/2026/11/01/$repo/os/$arch`). This needs no infrastructure of our own.

**Later:** MpireOS mirrors snapshots onto its own US-hosted servers, so it does not depend on Arch's archive bandwidth and can keep snapshots as long as needed.

### MpireOS's own repository

An additional pacman repository, `[mpire]`, holds MpireOS's own packages: branding, default configuration, `mpire-update`, the Calamares configuration, and later the desktop components. It is listed before Arch's repos so its packages take priority where names overlap.

- PKGBUILDs live in `packages/` in this repository.
- CI builds them in a clean Arch container and publishes a signed repository.
- v0.1 hosts the repository on GitHub Releases. It moves to project servers later.
- All packages and the repository database are signed with the MpireOS signing key, which ships in an `mpire-keyring` package.

### The AUR

The AUR is available, because it is a big part of why people choose Arch. MpireOS ships `paru` but treats the AUR as **unsupported**: the software center and `mpire-update` will label AUR packages clearly, and AUR packages built against a newer Arch than the user's channel may fail. For desktop apps, Flatpak from Flathub is the recommended route, and it is installed by default.

## Updates and rollback

### Filesystem layout

The installer creates Btrfs with these subvolumes:

| Subvolume | Mount point | Snapshotted |
|---|---|---|
| `@` | `/` | Yes |
| `@home` | `/home` | No (user data is not rolled back) |
| `@snapshots` | `/.snapshots` | n/a |
| `@var_log` | `/var/log` | No (keep logs across rollbacks) |
| `@var_cache` | `/var/cache` | No |

Compression (`zstd`) is on by default.

### Snapshots

- **snapper** manages snapshots of `/`.
- **snap-pac** takes a snapshot before and after every pacman transaction.
- **grub-btrfs** adds snapshots to the boot menu, so a system that no longer boots can still be started from an earlier snapshot and rolled back.
- Retention defaults: the last 10 update pairs plus weekly snapshots for a month. This can be changed in settings.

GRUB is used instead of systemd-boot because snapshot booting is mature on GRUB. This can be revisited.

### `mpire-update`

A small command, and later a graphical updater, that wraps the update flow:

1. Shows MpireOS release news, including any manual steps.
2. Takes a labeled snapshot.
3. Updates pacman packages, then Flatpaks.
4. Reports the result and how to roll back if needed.

Running `pacman -Syu` directly still works and is still covered by snap-pac.

### Kernels

Both `linux` (from the channel's snapshot) and `linux-lts` are installed by default, so there is always a fallback kernel in the boot menu.

## Desktop

### v0.1: themed Plasma

MpireOS starts on **KDE Plasma 6 on Wayland**, with SDDM as the login manager. Plasma is Qt-based like Deepin's DDE, mature, and highly configurable, which makes it the best base to replace piece by piece.

MpireOS ships its look as packages:

- `mpire-plasma-theme`: global theme (Plasma style, color scheme, window decoration, cursor, splash, SDDM theme)
- `mpire-icons` and `mpire-wallpapers`
- `mpire-desktop-defaults`: panel and dock layout, default apps, keyboard shortcuts, font choices

### v0.3 onward: MpireOS components

Components are written in **C++ and Qt 6 / QML**, shipped as separate packages, and each one replaces a single Plasma part. They live in `desktop/` and share one design system (colors, spacing, typography, motion) so they look like one product.

Planned order: dock, app launcher, control center, welcome app, software center, file manager. Each must be at least as usable as the Plasma part it replaces before it becomes the default.

## Installer

**Calamares** with MpireOS branding and configuration (`mpire-calamares-config`). It creates the Btrfs layout above, sets up snapper, enables the chosen channel, and offers an optional disk encryption choice (LUKS2).

## Building the ISO

- The archiso profile lives in `iso/`.
- GitHub Actions builds it in a privileged `archlinux` container, using the `stable` snapshot plus the `[mpire]` repository.
- Every build is booted in QEMU as a smoke test.
- Tagged releases attach the ISO, a SHA-256 checksum, and a signature to a GitHub Release.

Larger images may outgrow GitHub's release limits. If so, ISOs move to project-hosted storage with the same checksums and signatures.

## Trust and privacy

- No telemetry by default. Any future opt-in data collection will be documented, minimal, and off by default.
- Build pipelines are public, and releases are signed.
- Project infrastructure and signing keys are held in the United States.
- Goal before v1.0: reproducible ISO builds and a published SBOM (software bill of materials).

## Open questions

- Long-term hosting for packages and ISOs (and budget for it)
- Whether to ship an LTS-style channel with longer promotion intervals
- Whether to switch boot loaders once Secure Boot work starts
- Artwork license (GPL or Creative Commons)
