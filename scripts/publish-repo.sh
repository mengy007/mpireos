#!/usr/bin/env bash
# Publishes a built [mpire] repository to a GitHub release, which installed
# systems use as their package server (see packages/mpire-base/mpire-update).
#
# Usage: scripts/publish-repo.sh <release-tag> <repo-dir> <channel>
#   release-tag  "repo" (stable channel) or "repo-testing" (testing channel)
#   repo-dir     output of scripts/build-packages.sh (mpire.db, *.pkg.tar.zst, ...)
#   channel      which <channel>.channel file to publish with it
# Needs the GitHub CLI with GH_TOKEN set (contents: write).
#
# Order matters for systems updating at the same moment: packages first, then
# the database that lists them, then the channel date, and only then are
# packages no longer listed removed.
set -euo pipefail
tag="$1" dir="$2" channel="$3"
cd "$dir"
[[ -f mpire.db && -f $channel.channel ]] || { echo "publish-repo: $dir has no mpire.db or $channel.channel" >&2; exit 1; }

case "$tag" in
    repo) title="MpireOS package repository (stable)" ;;
    repo-testing) title="MpireOS package repository (testing)" ;;
    *) echo "publish-repo: unknown release $tag" >&2; exit 1 ;;
esac
gh release view "$tag" >/dev/null 2>&1 || \
    gh release create "$tag" --title "$title" --latest=false \
        --notes "Packages and the Arch snapshot date for MpireOS's $channel channel. Installed systems update from here (mpire-update). Managed by CI: do not edit by hand."

shopt -s nullglob
packages=(*.pkg.tar.zst *.pkg.tar.zst.sig)
databases=(mpire.db mpire.files mpire.db.tar.gz mpire.files.tar.gz mpire.db.sig mpire.files.sig mpire.db.tar.gz.sig mpire.files.tar.gz.sig)
existing_dbs=()
for f in "${databases[@]}"; do [[ -f $f ]] && existing_dbs+=("$f"); done

gh release upload "$tag" "${packages[@]}" --clobber
gh release upload "$tag" "${existing_dbs[@]}" --clobber
gh release upload "$tag" "$channel.channel" --clobber

keep=("${packages[@]}" "${existing_dbs[@]}" "$channel.channel")
gh release view "$tag" --json assets --jq '.assets[].name' | while read -r asset; do
    printf '%s\n' "${keep[@]}" | grep -qxF "$asset" && continue
    # Channel files stay: MpireOS 0.1's updater reads every channel from "repo".
    [[ $asset == *.channel ]] && continue
    echo "publish-repo: removing $asset"
    gh release delete-asset "$tag" "$asset" --yes
done
echo "publish-repo: $tag now serves $channel ($(tr -d '[:space:]' < "$channel.channel"))"
