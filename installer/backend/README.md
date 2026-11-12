# mpire-install

The privileged half of Mpire Setup. It takes an install plan (JSON) and installs MpireOS from the running live ISO. The graphical frontend never touches disks; it writes the plan, runs `pkexec mpire-install --plan <file>`, and reads progress from stdout, one JSON object per line. A D-Bus service can replace the process boundary later without changing the plan format.

```sh
mpire-install --plan plan.json            # install (root only)
mpire-install --plan plan.json --dry-run  # print steps and commands, change nothing
```

The plan format is documented at the top of `mpire-install`. The full log goes to `/var/log/mpire-install.log` and is copied to the installed system.

## What it does (erase mode)

1. Checks the plan and that the target disk is not in use
2. Partitions the disk as GPT: 1 MiB BIOS boot, 1 GiB FAT32 `/boot` (also the EFI system partition), and the rest for MpireOS
3. Optionally encrypts the MpireOS partition with LUKS2, unlocked with the account password by default
4. Creates Btrfs with the `@`, `@home`, `@snapshots`, `@var_log`, `@var_cache` subvolumes (zstd compression)
5. Copies the live system image and the kernel
6. Removes live-only files, services, and packages; resets machine ID and the pacman keyring; locks root
7. Sets language, keyboard, time zone, and computer name
8. Creates the user (in `wheel`, with sudo)
9. Builds a systemd-based initramfs (with `sd-encrypt` when encrypted)
10. Installs GRUB for UEFI (plus the removable fallback path) or BIOS
11. Configures snapper and takes a "Fresh install" snapshot
12. Enables services and unmounts

Installing alongside another OS is not supported yet; the plan is rejected with a clear message.

## Testing

CI boots every ISO with `mpire.autoinstall`, which runs `mpire-install` with `/usr/share/mpire-setup/ci-plan.json` against a blank virtual disk under UEFI, then boots the installed disk and waits for the login screen (`scripts/install-test.sh`).
