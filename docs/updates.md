# Updates: how MpireOS changes reach installed systems

Installed MpireOS systems update in place. Nobody reinstalls to get a newer MpireOS.

```
push to main ──CI: build, boot test, install test──▶ repo-testing release ──▶ testing systems
                                                          │
                                  "Promote testing to stable" (manual)
                                                          ▼
                                                    repo release ──────────▶ stable systems
```

## What a system follows

Each system is on one **channel**, `stable` (the default) or `testing`. A channel is two things:

| | Testing | Stable |
|---|---|---|
| MpireOS packages (`[mpire]`) | GitHub release `repo-testing` | GitHub release `repo` |
| Arch packages (`[core]`, `[extra]`) | Arch Linux Archive, date in `testing.channel` | Arch Linux Archive, date in `stable.channel` |

`mpire-update` (daily timer, or run by hand) reads the channel's date, writes `/etc/pacman.d/mpire-snapshot` and `/etc/pacman.d/mpire-repo`, and runs the upgrade. snap-pac takes a Btrfs snapshot before and after.

Switch a system's channel with `sudo mpire-update --channel testing` (or `stable`). Updates never move backwards, so a system that goes back to stable stays where it is until stable catches up.

## Shipping a change (maintainers)

1. **Merge to `main`.** CI builds every package in `packages/`, builds the ISO, boots it, runs an unattended install, and boots the installed system. Only if all of that passes does it publish the packages to `repo-testing` (`scripts/publish-repo.sh`). Testing systems pick them up on their next update.
2. **Let it soak.** Run testing on real hardware for a while (about a week for normal changes).
3. **Promote.** Actions → *Promote testing to stable* → Run workflow, and type `promote`. It copies exactly the packages testers ran to `repo`, sets stable's Arch date to testing's, and commits that date to `channels/stable` so new ISOs match.

To move testing to a newer Arch snapshot, change the date in `channels/testing` in a pull request. Dates come from <https://archive.archlinux.org/repos/>.

Bump `pkgver` or `pkgrel` in a package's PKGBUILD whenever its contents change, or pacman will not see it as an update.

## Signing

Packages are signed in CI with the project key once it exists. One-time setup, on a trusted computer with `gpg` and a logged-in `gh`:

```sh
scripts/create-signing-key.sh          # creates the key, stores the MPIRE_SIGNING_KEY secret
git add packages/mpire-keyring && git commit -m "Add the MpireOS package signing key"
```

Bump `pkgrel` in `packages/mpire-keyring/PKGBUILD` in the same commit. After that, everything switches to required signatures without anyone editing pacman.conf: new ISOs are built with `SigLevel = Required` for `[mpire]`, installed systems switch on the update that brings the new keyring, and CI on `main` refuses to publish unsigned packages. Keep the offline backup of the private key somewhere safe.

## Undoing an update (users)

1. Restart. In the boot menu (hold Shift, or press Esc, if it is hidden) choose **MpireOS snapshots**, then the entry from before the problem, for example *Before update, Nov 15, 2026 6:30 PM*.
2. MpireOS starts from that snapshot. Anything you change in the system is thrown away at shutdown; your files in `/home` are the real ones.
3. If everything works, run `sudo mpire-rollback` to keep this snapshot, then restart.

`mpire-rollback --list` shows the snapshots, and `sudo mpire-rollback NUMBER` goes back to one without booting it first. The system you left is kept as the Btrfs subvolume `@before-rollback-<date>` until you delete it.

How it works: `/boot` is the EFI partition and is not part of snapshots, so `mpire-keep-kernel` keeps a copy of each kernel that gets replaced (`/boot/mpire-kernels/<version>/`). The boot menu entry for a snapshot uses the kernel matching the modules inside it, and boots the read-only snapshot with `systemd.volatile=overlay`. Snapshots whose kernel is no longer kept are left out of the menu.
