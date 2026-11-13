#!/usr/bin/env bash
# One-time setup: create the MpireOS package signing key.
#
# Run on a trusted computer with gpg and the GitHub CLI (gh) logged in as a
# maintainer. It:
#   1. creates an Ed25519 signing key with no passphrase (CI must use it unattended),
#   2. stores the private key as the MPIRE_SIGNING_KEY Actions secret,
#   3. writes the public key into packages/mpire-keyring/ for you to commit,
#   4. saves an offline backup of the private key in ./mpireos-signing-key.asc.
# Keep the backup somewhere safe and offline, then delete it from this computer.
set -euo pipefail
repo="${1:-mengy007/mpireos}"
root="$(cd "$(dirname "$0")/.." && pwd)"
home="$(mktemp -d)"; trap 'rm -rf "$home"' EXIT
export GNUPGHOME="$home"

gpg --batch --pinentry-mode loopback --passphrase '' \
    --quick-generate-key "MpireOS Package Signing <packages@mpireos.invalid>" ed25519 sign 3y
fpr="$(gpg --list-keys --with-colons | awk -F: '/^fpr/ {print $10; exit}')"

gpg --armor --export-secret-keys "$fpr" > mpireos-signing-key.asc
gh secret set MPIRE_SIGNING_KEY --repo "$repo" < mpireos-signing-key.asc

gpg --export "$fpr" > "$root/packages/mpire-keyring/mpireos.gpg"
echo "$fpr:4:" > "$root/packages/mpire-keyring/mpireos-trusted"
: > "$root/packages/mpire-keyring/mpireos-revoked"

echo
echo "Signing key $fpr created and saved as the MPIRE_SIGNING_KEY secret on $repo."
echo "Next: commit packages/mpire-keyring/, set [mpire] SigLevel to Required in iso/pacman.conf.in,"
echo "and move mpireos-signing-key.asc to offline storage."
