# mpire-keyring

Public keys that sign MpireOS packages. **Empty until the project signing key is created** (see `scripts/create-signing-key.sh` and [docs/updates.md](../../docs/updates.md#signing)). Until then the `[mpire]` repository is used with `SigLevel = Optional TrustedOnly` and CI signs nothing. Once a key is committed here, ISOs and installed systems switch to `SigLevel = Required` by themselves.
