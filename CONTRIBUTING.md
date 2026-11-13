# Contributing to MpireOS

Thanks for your interest. MpireOS is at a very early stage, so ideas and feedback are as valuable as code right now.

## Ways to help

- **Try things and report back.** Once ISOs exist, testing on real hardware is the most useful thing you can do.
- **Discuss the design.** Open an issue on anything in [docs/architecture.md](docs/architecture.md) you think is wrong or missing.
- **Design.** Icons, wallpapers, the theme, and the layout of MpireOS's own components all need designers.
- **Packaging and build.** PKGBUILDs, the archiso profile, and CI.
- **Mpire Desktop.** Qt 6 / QML work on the shell, settings, and apps (see the [roadmap](ROADMAP.md)).

## Before you start

For anything bigger than a typo, open an issue first describing what you plan to do. That avoids two people building the same thing, or work that conflicts with the architecture.

## Making a change

1. Fork the repository and create a branch from `main` with a short, descriptive name, such as `installer/disk-screen` or `docs/fix-install-steps`.
2. Keep each pull request focused on one change.
3. Write commit messages in the imperative mood, with a short summary line ("Add snapper config for root subvolume").
4. Explain in the pull request what changed, why, and how you tested it.
5. A maintainer will review it. Expect questions; they are not a rejection.

## Repository layout

The layout will grow as the project does. The planned top-level directories are:

| Path | Contents |
|---|---|
| `docs/` | Architecture and design documents |
| `iso/` | The archiso profile used to build the MpireOS image |
| `packages/` | PKGBUILDs for MpireOS's own packages |
| `installer/` | Mpire Setup, the graphical installer |
| `desktop/` | Mpire Desktop: shell, settings, greeter, and apps (Qt 6 / QML) |
| `.github/workflows/` | CI that builds packages and ISOs |

## Licensing of contributions

By submitting a contribution, you agree that it is licensed under the GNU General Public License v3.0 or later, the same license as the project. Artwork may later move to a Creative Commons license; that will be stated clearly in the relevant directory.

Only submit work you have the right to contribute. Do not copy code or artwork from other projects unless their license allows it and you keep their notices.

## Conduct

Be respectful and assume good faith. A formal code of conduct is on the roadmap; until then, maintainers will remove harassment or abuse.

## Security

Please do not report security problems in public issues. Until a dedicated address exists, use GitHub's private vulnerability reporting on this repository.
