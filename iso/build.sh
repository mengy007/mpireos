#!/usr/bin/env bash
# Builds the MpireOS live ISO.
#
# Usage: iso/build.sh [channel] [output-dir]
#   channel     stable (default) or testing; picks the Arch snapshot date from channels/
#   output-dir  where the ISO is written (default: ./out)
#
# Runs as root on Arch Linux with archiso installed (CI uses an archlinux container).
# The profile is Arch's "releng" profile from the installed archiso, with MpireOS's
# packages, files, and branding layered on top.
set -euo pipefail

channel="${1:-stable}"
out="$(realpath -m "${2:-out}")"
repo="$(cd "$(dirname "$0")/.." && pwd)"
releng=/usr/share/archiso/configs/releng
work="${WORK_DIR:-/tmp/mpireos-work}"
profile="$work/profile"

[[ $EUID -eq 0 ]] || { echo "build.sh must run as root" >&2; exit 1; }
[[ -d $releng ]] || { echo "archiso is not installed ($releng missing)" >&2; exit 1; }
[[ -f $repo/channels/$channel ]] || { echo "unknown channel: $channel" >&2; exit 1; }
snapshot="$(tr -d '[:space:]' < "$repo/channels/$channel")"
echo "==> Channel: $channel (Arch snapshot $snapshot)"

rm -rf "$work"
mkdir -p "$work" "$out"
cp -a "$releng" "$profile"

# Arch's live-medium networking (iwd, systemd-networkd) and root autologin are
# replaced by NetworkManager and a graphical live session.
rm -f "$profile"/airootfs/etc/systemd/system/multi-user.target.wants/{iwd,systemd-networkd,reflector}.service \
      "$profile"/airootfs/etc/systemd/system/sockets.target.wants/systemd-networkd*.socket \
      "$profile"/airootfs/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service \
      "$profile"/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf
rm -rf "$profile"/airootfs/etc/systemd/network

# MpireOS files on top of releng's airootfs, plus the installer backend.
cp -a "$repo/iso/airootfs/." "$profile/airootfs/"
install -Dm755 "$repo/installer/backend/mpire-install" "$profile/airootfs/usr/local/bin/mpire-install"

# Package list: releng's plus MpireOS's, deduplicated.
cat "$releng/packages.x86_64" "$repo/iso/packages.x86_64" \
    | sed 's/#.*//; s/[[:space:]]//g; /^$/d' | sort -u > "$profile/packages.x86_64"

# Pacman config. The live and installed system get the real one (pacman.conf.in);
# the build uses the same layout with the channel's snapshot and the [mpire]
# packages just built by scripts/build-packages.sh.
mpire_repo="$(realpath -m "${MPIRE_REPO_DIR:-$out/repo}")"
[[ -f $mpire_repo/mpire.db ]] || { echo "no [mpire] repo at $mpire_repo; run scripts/build-packages.sh first" >&2; exit 1; }
cp "$repo/iso/pacman.conf.in" "$profile/airootfs/etc/pacman.conf"
if [[ -s $repo/packages/mpire-keyring/mpireos.gpg ]]; then
    echo "==> Project signing key present: [mpire] requires signatures"
    sed -i '/^\[mpire\]/,/^\[/{s|^SigLevel = .*|SigLevel = Required|}' "$profile/airootfs/etc/pacman.conf"
fi
# Systems installed from a testing ISO stay on testing (see mpire-update --channel).
if [[ $channel != stable ]]; then
    mkdir -p "$profile/airootfs/etc/mpireos"
    echo "$channel" > "$profile/airootfs/etc/mpireos/channel"
fi
mirror="Server = https://archive.archlinux.org/repos/$snapshot/\$repo/os/\$arch"
sed -e "/^\[mpire\]/,/^\[core\]/{s|^SigLevel = .*|SigLevel = Optional TrustAll|;s|^Include = .*|Server = file://$mpire_repo|}" \
    -e "s|^Include = /etc/pacman.d/mpire-snapshot|$mirror|" \
    "$repo/iso/pacman.conf.in" > "$profile/pacman.conf"

# Identity and file permissions.
sed -i \
    -e 's/^iso_name=.*/iso_name="mpireos"/' \
    -e 's/^iso_label=.*/iso_label="MPIREOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"/' \
    -e 's|^iso_publisher=.*|iso_publisher="MpireOS <https://github.com/mengy007/mpireos>"|' \
    -e 's/^iso_application=.*/iso_application="MpireOS Live"/' \
    "$profile/profiledef.sh"
cat >> "$profile/profiledef.sh" <<'PERMS'
file_permissions+=(
  ["/etc/sudoers.d/10-mpire-live"]="0:0:440"
  ["/usr/local/bin/mpire-live-setup"]="0:0:755"
  ["/usr/local/bin/mpire-boot-check"]="0:0:755"
  ["/usr/local/bin/mpire-install"]="0:0:755"
  ["/usr/local/bin/mpire-autoinstall"]="0:0:755"
  ["/usr/local/bin/mpire-setup-live"]="0:0:755"
)
PERMS

# Boot menus: MpireOS's own, in place of releng's. BIOS uses SYSLINUX with our
# splash (iso/syslinux); UEFI uses GRUB with the MpireOS theme (iso/grub plus
# the theme from mpire-branding), since systemd-boot can't be themed.
# Entries start the live system with the Plymouth splash and a serial console
# so CI can watch the boot.
rm -rf "$profile"/{syslinux,grub,efiboot}
cp -a "$repo/iso/syslinux" "$repo/iso/grub" "$profile/"
mkdir -p "$profile/grub/themes"
cp -a "$repo/packages/mpire-branding/grub/mpireos" "$profile/grub/themes/"
echo "bootmodes=('bios.syslinux' 'uefi.grub')" >> "$profile/profiledef.sh"

# The live system's initramfs starts the splash too.
sed -i -E 's/^HOOKS=\((base udev)/HOOKS=(\1 plymouth/' "$profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf"
grep -q '^HOOKS=(base udev plymouth' "$profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf" \
    || { echo "couldn't add plymouth to the live initramfs hooks" >&2; exit 1; }
# On UEFI the splash draws on the firmware's framebuffer. Legacy BIOS has none, so
# bring the virtual machine graphics drivers (small, unlike the full kms hook
# with its GPU firmware); on other BIOS PCs the splash appears once the root
# file system loads the graphics driver.
echo 'MODULES=(bochs virtio_gpu qxl vmwgfx)' >> "$profile/airootfs/etc/mkinitcpio.conf.d/archiso.conf"

echo "==> Building ISO"
mkarchiso -v -w "$work/build" -o "$out" "$profile"
ls -lh "$out"/*.iso
