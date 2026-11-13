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
mirror="Server = https://archive.archlinux.org/repos/$snapshot/\$repo/os/\$arch"
sed -e "/^\[mpire\]/,/^\[core\]/{s|^SigLevel = .*|SigLevel = Optional TrustAll|;s|^Server = .*|Server = file://$mpire_repo|}" \
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

# Boot menus: MpireOS naming, and a serial console so CI can watch the boot.
find "$profile"/{syslinux,grub,efiboot} -type f \( -name '*.cfg' -o -name '*.conf' \) 2>/dev/null | while read -r f; do
    sed -i -e 's/Arch Linux install medium/MpireOS live/g' \
           -e 's/Arch Linux/MpireOS/g' \
           -e '/archisobasedir=/ s/$/ console=tty0 console=ttyS0,115200/' "$f"
done

echo "==> Building ISO"
mkarchiso -v -w "$work/build" -o "$out" "$profile"
ls -lh "$out"/*.iso
