"""Keeps API keys out of config files and out of other users' reach.

Backends, best first:
  creds   systemd-creds, scoped to this user: the key is encrypted with this
          computer's key (and its TPM, when it has one), so a copied file is
          useless elsewhere. No prompts, works before any keyring exists.
  keyring the Secret Service (KWallet or GNOME Keyring), through secret-tool.
  file    a file only this user can read (0600), as a last resort.
Keys are never put on a command line (they go through stdin) and never logged.
A key exported in the environment (ANTHROPIC_API_KEY and friends) is used
when nothing is stored.
"""
import os
import shutil
import subprocess
from pathlib import Path

from . import config

SERVICE = "mpire-ai"
LABELS = {
    "creds": "Encrypted on this computer",
    "keyring": "In your keyring",
    "file": "In a private file in your home folder",
    "env": "From your environment",
}


def _dir() -> Path:
    d = config.data_dir() / "keys"
    d.mkdir(parents=True, exist_ok=True, mode=0o700)
    os.chmod(d, 0o700)
    return d


def _run(args, data: str | None = None, timeout=15) -> subprocess.CompletedProcess | None:
    try:
        return subprocess.run(args, input=data, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.SubprocessError):
        return None


def _cred_name(pid: str) -> str:
    return f"mpire-ai-{pid}"


def _creds_store(pid: str, key: str) -> bool:
    if not shutil.which("systemd-creds"):
        return False
    out = _dir() / f"{pid}.cred"
    tmp = out.with_suffix(".tmp")
    r = _run(["systemd-creds", "encrypt", "--user", f"--name={_cred_name(pid)}", "-", str(tmp)], key)
    if not r or r.returncode != 0 or not tmp.exists():
        tmp.unlink(missing_ok=True)
        return False
    os.chmod(tmp, 0o600)
    # Check it decrypts before trusting it with the only copy of the key.
    r = _run(["systemd-creds", "decrypt", "--user", f"--name={_cred_name(pid)}", str(tmp), "-"])
    if not r or r.returncode != 0 or r.stdout != key:
        tmp.unlink(missing_ok=True)
        return False
    os.replace(tmp, out)
    return True


def _creds_lookup(pid: str) -> str | None:
    path = _dir() / f"{pid}.cred"
    if not path.exists() or not shutil.which("systemd-creds"):
        return None
    r = _run(["systemd-creds", "decrypt", "--user", f"--name={_cred_name(pid)}", str(path), "-"])
    return r.stdout if r and r.returncode == 0 and r.stdout else None


def _keyring_attrs(pid: str):
    return ["application", SERVICE, "provider", pid]


def _keyring_store(pid: str, key: str, label: str) -> bool:
    if not shutil.which("secret-tool"):
        return False
    r = _run(["secret-tool", "store", f"--label=MpireOS AI: {label}", *_keyring_attrs(pid)], key, timeout=60)
    (_dir() / f"{pid}.keyring").touch(mode=0o600)
    if r and r.returncode == 0 and _keyring_lookup(pid) == key:
        return True
    (_dir() / f"{pid}.keyring").unlink(missing_ok=True)
    return False


def _keyring_lookup(pid: str) -> str | None:
    # Only ask the keyring about keys we put there: asking can make the
    # keyring pop up a password prompt.
    if not (_dir() / f"{pid}.keyring").exists() or not shutil.which("secret-tool"):
        return None
    r = _run(["secret-tool", "lookup", *_keyring_attrs(pid)], timeout=10)
    return r.stdout if r and r.returncode == 0 and r.stdout else None


def _file_store(pid: str, key: str) -> bool:
    path = _dir() / f"{pid}.key"
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(key)
    os.chmod(path, 0o600)
    return True


def _file_lookup(pid: str) -> str | None:
    try:
        return (_dir() / f"{pid}.key").read_text(encoding="utf-8") or None
    except OSError:
        return None


def remove(pid: str) -> None:
    if (_dir() / f"{pid}.keyring").exists() and shutil.which("secret-tool"):
        _run(["secret-tool", "clear", *_keyring_attrs(pid)], timeout=10)
    for suffix in (".cred", ".key", ".keyring"):
        (_dir() / f"{pid}{suffix}").unlink(missing_ok=True)


def store(pid: str, key: str, label: str = "") -> str:
    """Saves a key, replacing any earlier one. Returns the backend used."""
    key = key.strip()
    if not key:
        raise ValueError("empty key")
    remove(pid)
    order = os.environ.get("MPIRE_AI_KEY_BACKENDS", "creds,keyring,file").split(",")
    for backend in order:
        ok = {"creds": lambda: _creds_store(pid, key),
              "keyring": lambda: _keyring_store(pid, key, label or pid),
              "file": lambda: _file_store(pid, key)}.get(backend.strip(), lambda: False)()
        if ok:
            return backend.strip()
    raise RuntimeError("no place to keep the key")


def lookup(pid: str, preset: str = "") -> tuple[str | None, str]:
    """The key for a provider and where it came from ("" when there is none)."""
    for backend, fn in (("creds", _creds_lookup), ("file", _file_lookup)):
        key = fn(pid)
        if key:
            return key, backend
    key = _keyring_lookup(pid)
    if key:
        return key, "keyring"
    env = config.PRESETS.get(preset, {}).get("env", "")
    if env and os.environ.get(env):
        return os.environ[env], "env"
    return None, ""


def where(pid: str, preset: str = "") -> str:
    """Where a provider's key is kept, without reading it from the keyring."""
    d = _dir()
    if (d / f"{pid}.cred").exists():
        return "creds"
    if (d / f"{pid}.key").exists():
        return "file"
    if (d / f"{pid}.keyring").exists():
        return "keyring"
    env = config.PRESETS.get(preset, {}).get("env", "")
    return "env" if env and os.environ.get(env) else ""
