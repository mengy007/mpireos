# MpireOS

MpireOS is a US-based, open source Linux distribution focused on a polished, cohesive desktop. It is built on Arch Linux, then held back and tested so that updates arrive calm and reversible.

> **Status:** pre-alpha. There is no installable image yet. See the [roadmap](ROADMAP.md) for what comes first.

## Why MpireOS

- **A desktop that feels designed, not assembled.** One visual language across the shell, settings, and core apps, in the spirit of Deepin, built in the open.
- **The Arch ecosystem with stability.** Full access to Arch packages and the AUR, delivered through MpireOS's own tested channels instead of straight from the rolling firehose.
- **Every update can be undone.** Btrfs snapshots are taken automatically before each update, and you can boot into any earlier one from the boot menu.
- **US-based and transparent.** Governance, infrastructure, and release signing are based in the United States. Builds run in public CI, and there is no telemetry by default.

## How it is built

| Layer | Choice |
|---|---|
| Base | Arch Linux (x86_64) |
| Package channels | `testing` and `stable`, both promoted from dated Arch snapshots |
| Filesystem | Btrfs with snapper and boot-menu rollback |
| Desktop | KDE Plasma 6 on Wayland, themed and preconfigured, with MpireOS components replacing parts over time |
| Installer | Calamares |
| Image build | archiso, built in GitHub Actions |

The full design lives in [docs/architecture.md](docs/architecture.md).

## Getting involved

MpireOS is just getting started, which makes now a good time to shape it. Read [CONTRIBUTING.md](CONTRIBUTING.md) and open an issue or discussion with ideas, questions, or offers to help.

## License

MpireOS's own code and configuration are licensed under the [GNU General Public License v3.0 or later](LICENSE). Packages pulled from Arch Linux and other upstreams keep their own licenses.

MpireOS is not affiliated with Arch Linux, KDE, or Deepin.
