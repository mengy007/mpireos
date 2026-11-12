# Roadmap

MpireOS grows in small, shippable steps. Each milestone ends with something people can download, run, or join. Dates are targets, not promises.

## v0.0: Foundation (now)

- [x] Name, license (GPLv3), and repository
- [x] Architecture document ([docs/architecture.md](docs/architecture.md))
- [x] Contributor guide
- [ ] Visual identity direction: logo, color palette, typography, wallpaper
- [ ] Domain registration and a trademark check for "MpireOS"
- [ ] Code of conduct

## v0.1: First bootable ISO

Goal: a live ISO that boots in a VM and on common hardware, and installs to disk.

- [ ] archiso profile in `iso/`, built by GitHub Actions on every push to `main`
- [ ] Package build pipeline for MpireOS's own packages in `packages/`
- [ ] Signed `mpire` package repository with the project's signing key
- [ ] `testing` and `stable` channels pinned to dated Arch snapshots
- [ ] Btrfs subvolume layout, snapper, snap-pac, and grub-btrfs for rollback
- [ ] KDE Plasma 6 (Wayland) with the MpireOS theme, layout, and defaults
- [ ] Calamares installer with MpireOS branding and the Btrfs layout
- [ ] `mpire-update`: a safe update command that snapshots, updates, and shows release news
- [ ] Automated boot test of the ISO in QEMU
- [ ] Released on GitHub with SHA-256 checksums and a signature

## v0.2: Public launch

Goal: people can find MpireOS, try it, and talk to each other.

- [ ] Website with downloads, screenshots, installation guide, and FAQ
- [ ] Documentation site
- [ ] Community spaces: Matrix or Discord, plus a forum or GitHub Discussions
- [ ] Bug report and feature request templates
- [ ] Launch announcements

## v0.3 and later: MpireOS desktop components

Goal: replace Plasma parts with MpireOS's own Qt 6 / QML components, one at a time, so each ships independently.

1. Dock
2. App launcher
3. Control center (settings)
4. Welcome and first-run app
5. Software center (pacman, Flatpak, and AUR with clear trust labels)
6. File manager and other core apps

## Toward v1.0

- Self-hosted, US-based package mirrors and a CDN
- Secure Boot support
- Reproducible ISO builds and a published SBOM
- A legal home for the project (a US nonprofit or fiscal sponsor)
- Defined release cadence and support policy
