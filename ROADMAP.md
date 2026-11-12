# Roadmap

MpireOS grows in small, shippable steps. Each milestone ends with something people can download, run, or join. Dates are targets, not promises.

## v0.0: Foundation (now)

- [x] Name, license (GPLv3), and repository
- [x] Architecture document ([docs/architecture.md](docs/architecture.md))
- [x] Contributor guide
- [x] Visual direction and design system ([docs/design-system.md](docs/design-system.md))
- [ ] Logo, wordmark, and default wallpaper
- [ ] Domain registration and a trademark check for "MpireOS"
- [ ] Code of conduct

## v0.1: First bootable ISO

Goal: a developer ISO that boots in a VM and on common hardware, and installs to disk. It uses KDE Plasma as temporary scaffolding and is not publicly announced.

- [ ] archiso profile in `iso/`, built by GitHub Actions on every push to `main`
- [ ] Package build pipeline for MpireOS's own packages in `packages/`
- [ ] Signed `mpire` package repository with the project's signing key
- [ ] `testing` and `stable` channels pinned to dated Arch snapshots
- [ ] Btrfs subvolume layout, snapper, snap-pac, and grub-btrfs for rollback
- [ ] Plasma (Wayland) live session as development scaffolding
- [ ] Mpire Setup: the MpireOS graphical installer (welcome, where to install, about you, review), with erase-disk, encryption, and dual boot
- [ ] Unattended install mode used by CI to test every ISO
- [ ] `mpire-update`: a safe update command that snapshots, updates, and shows release news
- [ ] Automated boot test of the ISO in QEMU
- [ ] Released on GitHub with SHA-256 checksums and a signature

## v0.2: Mpire Desktop, first session

Goal: boot and install straight into Mpire Desktop, with no Plasma.

- [ ] `MpireOS.Style` QML module implementing the design system (shared with Mpire Setup)
- [ ] Desktop widgets: Today, A moment of focus, Now playing
- [ ] `mpire-session`: starts the compositor (KWin for now) and the shell
- [ ] `mpire-shell`: top bar, dock, app launcher, notifications, quick settings, volume and brightness pop-ups
- [ ] `mpire-greeter` and `mpire-lock`
- [ ] `mpire-decoration` and window animations
- [ ] `mpire-settings`: Wi-Fi, Bluetooth, display, sound, appearance, users, updates, about
- [ ] `mpire-welcome`: first-run app
- [ ] Icons, cursors, wallpapers, and sounds
- [ ] Remove Plasma from the ISO

## Compositor track: `mpire-compositor`

Runs alongside v0.2 and v0.3 so it does not block the desktop.

- [ ] Minimal wlroots compositor: outputs, input, xdg-shell windows, layer-shell for the shell
- [ ] Window management: focus, move and resize, snapping, workspaces
- [ ] Effects: rounded corners, shadows, background blur, open and close animations
- [ ] Session lock, XWayland, screen sharing through portals, idle and power management
- [ ] Multi-monitor, HiDPI, fractional scaling
- [ ] Overview and task switching
- [ ] Hardware test matrix passes, then it becomes the default and KWin is removed

## v0.3: Public launch

Goal: people can find MpireOS, try it, and talk to each other.

- [ ] Website with downloads, screenshots, installation guide, and FAQ
- [ ] Documentation site
- [ ] Community spaces: Matrix or Discord, plus a forum or GitHub Discussions
- [ ] Bug report and feature request templates
- [ ] Launch announcements

## v0.4 and later: MpireOS apps

1. Software center (pacman, Flatpak, and AUR with clear trust labels)
2. Files
3. Overview and window management polish
4. Further core apps, replacing the styled KDE apps one at a time

## Toward v1.0

- Self-hosted, US-based package mirrors and a CDN
- Secure Boot support
- Reproducible ISO builds and a published SBOM
- A legal home for the project (a US nonprofit or fiscal sponsor)
- Defined release cadence and support policy
