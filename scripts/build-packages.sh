#!/usr/bin/env bash
# Builds MpireOS's own packages (packages/*) into a pacman repository.
#
# Usage: scripts/build-packages.sh <output-dir> [channel]
# Runs as root on Arch Linux. If MPIRE_SIGNING_KEY holds an armored private key,
# packages and the database are signed with it.
# Output: mpire.db, mpire.files, *.pkg.tar.zst, and <channel>.channel for every channel.
set -euo pipefail
out="$(realpath -m "$1")"
channel="${2:-stable}"
repo="$(cd "$(dirname "$0")/.." && pwd)"
work=/tmp/mpire-packages

pacman -S --noconfirm --needed base-devel >/dev/null
id builder &>/dev/null || useradd -m builder
rm -rf "$work" "$out"
mkdir -p "$work" "$out"
cp -a "$repo/packages/." "$work/"
tr -d '[:space:]' < "$repo/channels/$channel" > "$work/mpire-base/snapshot"
chown -R builder: "$work"

sign=()
if [[ -n ${MPIRE_SIGNING_KEY:-} ]]; then
    sudo -u builder gpg --batch --import <<< "$MPIRE_SIGNING_KEY"
    key="$(sudo -u builder gpg --batch --list-secret-keys --with-colons | awk -F: '/^fpr/ {print $10; exit}')"
    sign=(--sign --key "$key")
    echo "==> Signing with $key"
else
    echo "==> MPIRE_SIGNING_KEY not set: building unsigned packages"
fi

for dir in "$work"/*/; do
    [[ -f $dir/PKGBUILD ]] || continue
    echo "==> Building $(basename "$dir")"
    (cd "$dir" && sudo -u builder makepkg --nodeps --force --cleanbuild "${sign[@]}")
    cp "$dir"/*.pkg.tar.zst* "$out/"
done

repo_add_sign=()
[[ ${#sign[@]} -gt 0 ]] && repo_add_sign=(--sign --key "$key")
chown -R builder: "$out"
(cd "$out" && sudo -u builder repo-add "${repo_add_sign[@]}" mpire.db.tar.gz ./*.pkg.tar.zst)
# GitHub release assets can't be symlinks: replace mpire.db/mpire.files links with copies.
for f in mpire.db mpire.files mpire.db.sig mpire.files.sig; do
    [[ -L $out/$f ]] && cp --remove-destination "$(readlink -f "$out/$f")" "$out/$f"
done
for c in "$repo"/channels/*; do
    tr -d '[:space:]' < "$c" > "$out/$(basename "$c").channel"
    echo >> "$out/$(basename "$c").channel"
done
ls -l "$out"
