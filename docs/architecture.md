# MpireOS architecture

Status: draft, v0.0. This document describes how MpireOS is built and why. Open an issue to challenge any part of it.

## Goals

1. **A cohesive, polished desktop** that feels like one product.
2. **Arch ecosystem, calm updates.** Access to Arch's packages, the AUR, and the Arch Wiki, without the breakage risk of tracking Arch directly.
3. **Every change is reversible.** A bad update costs one reboot, not an evening.
4. **US-based and auditable.** Public builds, signed releases, no telemetry by default.
5. **Our own desktop, end to end.** MpireOS builds every layer of the desktop, from the compositor up. Proven libraries are reused underneath (wlroots, Qt, system services).

## Non-goals for v0.1

- Architectures other than x86_64
- Secure Boot (planned before v1.0)
- An immutable or image-based root filesystem
- MpireOS's own browser, office suite, or kernel fork

## Overview

```
┌─────────────────────────────────────────────────────────┐
│ Mpire Desktop (Qt 6 / QML): greeter · lock · shell ·     │
│ settings · welcome · files · software                    │
├─────────────────────────────────────────────────────────┤
│ mpire-compositor (C++ on wlroots): windows, input, blur  │
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

An additional pacman repository, `[mpire]`, holds MpireOS's own packages: branding, default configuration, `mpire-update`, the installer, and later the desktop components. It is listed before Arch's repos so its packages take priority where names overlap.

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

### `mpire-update` and automatic updates

Installed systems keep themselves up to date; nobody should need to reinstall to get a newer MpireOS.

- **What moves:** each channel is a dated Arch snapshot. CI publishes the current date for each channel (`stable.channel`, `testing.channel`) alongside MpireOS's own packages in the `repo` release on GitHub. `mpire-update` reads the date for the system's channel, points `/etc/pacman.d/mpire-snapshot` at it (never backwards), and upgrades.
- **MpireOS's own pieces update the same way.** Branding, defaults, the updater itself, and later the desktop are pacman packages in the `[mpire]` repository (`packages/`), so a change merged to `main` reaches every installed system on its next update.
- **Safe by default:** snap-pac takes a Btrfs snapshot before and after the upgrade, keyrings update first, and if the database refresh fails the previous snapshot date is restored. If an upgrade breaks something, the "before" snapshot is in the boot menu.
- **Automatic:** `mpire-update.timer` runs daily (20 minutes after boot, then every day, randomized by up to an hour), only on AC power, at low CPU and I/O priority. It also updates Flatpak apps. `AUTO=no` in `/etc/mpireos/update.conf` turns it off.
- **Manual:** `mpire-update` (asks first), `mpire-update --check`, `mpire-update --yes`. A graphical updater in Settings will use the same tool.
- **Signing:** packages and the repository database are signed in CI with the project key (`MPIRE_SIGNING_KEY` secret, public key in `mpire-keyring`). Until that key exists the repository is used with `SigLevel = Optional TrustedOnly`, and it must be switched to `Required` before any public release.

Running `pacman -Syu` directly still works and is still covered by snap-pac.

### Kernels

Both `linux` (from the channel's snapshot) and `linux-lts` are installed by default, so there is always a fallback kernel in the boot menu.

## Desktop: Mpire Desktop

MpireOS ships its own desktop environment, **Mpire Desktop**. Everything a user sees and touches is MpireOS's own: the login screen, lock screen, panel, dock, launcher, notifications, quick settings, settings app, and over time the core apps. It is written in **C++ and Qt 6 / QML** and shares one design system (color, type, spacing, motion, icons) with Mpire Setup, so the whole system looks like one product. The design system is defined in [design-system.md](design-system.md): light and airy, lavender backdrop, white rounded cards with soft shadows, one violet accent, pastel colors to tell things apart, a frosted top bar, a floating dock, and desktop widgets.

### What we build and what we reuse

MpireOS builds the whole desktop, **including its own Wayland compositor**, `mpire-compositor`: the layer that draws every window, handles input, and talks to the graphics drivers. Owning it means the frosted bar, the floating dock, window animations, blur, and the overview all behave exactly as designed, with no compromise from someone else's compositor.

**How it is built:**

- **C++ on [wlroots](https://gitlab.freedesktop.org/wlroots/wlroots)** (MIT license, hosted by freedesktop.org), the same foundation as Sway and Hyprland. wlroots handles the hard, hardware-specific parts (DRM/KMS, libinput, multi-GPU, XWayland) so our code focuses on window management, effects, and the scene.
- **Small and crash-safe.** The compositor only manages windows, input, and effects. The shell, settings, greeter, and lock screen are separate Qt clients that talk to it over standard protocols (`wlr-layer-shell`, `ext-session-lock`, `xdg-activation`, `ext-foreign-toplevel-list`, `ext-background-effect` for blur). A shell crash never takes your windows down.
- **Standard protocols only for apps**, so every Wayland, Qt, GTK, Flatpak, and X11 (through XWayland) app works normally.
- **Effects in the compositor:** background blur, rounded corners and shadows on every window, open and close animations, workspaces, and an overview.

**Interim:** because the shell talks to the compositor only through standard protocols, Mpire Desktop also runs on KWin. Development builds use KWin until `mpire-compositor` passes a hardware test matrix (Intel, AMD, and NVIDIA GPUs; laptops with hybrid graphics; HiDPI, fractional scaling, and multiple monitors). It then becomes the default, and KWin is dropped.

| Layer | Mpire Desktop component | Notes |
|---|---|---|
| Login and lock | `mpire-greeter`, `mpire-lock` | SDDM greeter theme in QML; lock screen of our own |
| Shell | `mpire-shell` | One process: top bar, dock, app launcher, notifications, quick settings, on-screen displays, task switcher. Uses the Wayland layer-shell protocol. |
| Settings | `mpire-settings` | Our own control center. Talks to standard system services (NetworkManager, PipeWire, UPower, BlueZ, systemd, AccountsService, fwupd). |
| Compositor | `mpire-compositor` | Window management, input, blur, shadows, animations, workspaces, overview |
| Window look | `mpire-decoration` | Window title bars and controls, drawn by the compositor |
| Session | `mpire-session` | Starts the compositor and the shell, autostart, logout and shutdown |
| First run | `mpire-welcome` | Optional setup moved out of the installer |
| Apps | `mpire-files`, `mpire-software`, ... | See below |
| Look | `mpire-icons`, `mpire-cursors`, `mpire-wallpapers`, `mpire-sounds`, `mpire-fonts` | One visual language |

All components live in `desktop/` and are packaged separately so each can be updated on its own.

### Apps

MpireOS writes its own apps where the app defines the experience: **Files**, **Software** (pacman, Flatpak, and AUR with clear trust labels), **Settings**, and **Welcome**. Until each exists, MpireOS ships an existing Qt app styled to match (Dolphin, Konsole, Kate, Gwenview, Okular, Ark, Spectacle). Third-party apps (Firefox, LibreOffice) are kept and themed through Qt and GTK themes so they fit in.

### Platform services

Mpire Desktop builds on standard Linux services and freedesktop.org protocols instead of inventing its own, so Flatpak apps, GTK apps, and portals work normally: `xdg-desktop-portal` (with KDE's backend at first, ours later), PipeWire, NetworkManager, BlueZ, UPower, PolicyKit (with our own authentication dialog), and the StatusNotifier and notification specs.

### Scaffolding during development

Until `mpire-shell` and `mpire-settings` reach a usable state, development ISOs boot into KDE Plasma so the build, installer, and update pipelines can be tested end to end. Plasma is scaffolding only: **no public release ships with it.** It is removed from the ISO as soon as Mpire Desktop can run a full session.

## Installer

MpireOS has its own installer, **Mpire Setup**. The goal is an install that feels premium and takes a couple of minutes of attention: fully graphical, friendly, and asking only what MpireOS cannot work out for itself. Everything optional moves to the first-boot welcome app.

### Principles

- **Only ask what is required.** If a value can be detected or sensibly defaulted, do that and show it on the review screen instead of asking.
- **One decision per screen**, in plain language, with no partitioning or bootloader jargon on the default path.
- **Never lose data by surprise.** Anything destructive is spelled out on the review screen before the Install button is enabled.
- **Works offline.** The install copies the live system from the ISO, so no network is needed.
- **Advanced options exist but stay out of the way**, behind a single "Advanced" link.

### The flow

| # | Screen | What the user does | What is decided for them |
|---|---|---|---|
| 1 | **Welcome** | Picks "Install MpireOS" or "Try it first". Language is preselected and can be changed. | Language from firmware and live-session locale |
| 2 | **Where to install** | Picks one card: "Erase this disk and install" or, if another OS is found, "Install alongside Windows/Linux". An "Encrypt my disk" switch is on this screen. | Disk choice if there is only one; Btrfs layout; partition sizes; bootloader |
| 3 | **About you** | Enters name and password. | Username from the name (editable); computer name such as `meng-laptop`; keyboard from language; timezone from location |
| 4 | **Review** | Confirms a short plain-English summary, then presses Install. | — |
| 5 | **Installing** | Watches a progress bar with a short tour of MpireOS. | — |
| 6 | **Done** | Presses Restart. | — |

That is three questions for most people: language (usually just confirmed), where to install, and who they are.

**Not asked during install** (handled automatically or moved to the welcome app): keyboard layout, timezone, computer name, partitioning, swap, filesystem, bootloader, graphics drivers, light or dark theme, extra apps, Wi-Fi, update channel, privacy settings. Detected values appear on the review screen with an "Edit" link.

If an encryption passphrase is needed, MpireOS reuses the account password by default, with an option to set a separate one.

### Look and feel

- Full-screen, borderless, using the same design system as MpireOS's desktop components (typography, color, motion).
- Smooth transitions between screens, a visible step indicator, and a large primary button in the same place on every screen.
- Light and dark modes that follow the live session.
- Accessible: full keyboard navigation, screen reader labels, scalable text.

### How it is built

- **Frontend:** Qt 6 / QML, in `installer/`. It never touches disks itself.
- **Backend:** a small privileged service that the frontend drives over D-Bus with a single install plan (disk, encryption, user, locale). It partitions, creates the Btrfs subvolumes, copies the live system, installs the bootloader, configures snapper, creates the user, and removes live-only packages. Every step reports progress and logs to a file the user can save if something fails.
- **Tested in CI:** the backend runs unattended from a plan file, so the QEMU smoke test performs a real install on every ISO build.

Building our own installer is more work than reusing Calamares, but the installer is the first thing anyone sees, and Calamares cannot easily be cut down to this flow or made to look native. Calamares stays available as a fallback in development builds until Mpire Setup covers dual boot and encryption.

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
