"""Which AI providers the person has set up, and the presets they pick from.

~/.config/mpire-ai/config.json holds no secrets (keys live in keys.py):

    {
      "default": "anthropic",
      "providers": [
        {"id": "anthropic", "name": "Anthropic", "kind": "anthropic",
         "url": "https://api.anthropic.com", "model": "claude-opus-5-5",
         "where": "cloud", "preset": "anthropic"}
      ],
      "gateway": {"tcp": false, "port": 11500}
    }

kind: the wire protocol, "anthropic" (Messages API) or "openai" (any
OpenAI-compatible server: OpenAI, Gemini, OpenRouter, Ollama, LM Studio,
llama.cpp, vLLM...). where: "cloud", "local" (this computer), or "network"
(another computer on the LAN).

An administrator can ship defaults in /etc/mpire-ai/config.json; it is used
until the person saves their own.
"""
import json
import os
import re
from pathlib import Path

SYSTEM_CONFIG = Path("/etc/mpire-ai/config.json")


def config_dir() -> Path:
    base = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    return Path(base) / "mpire-ai"


def data_dir() -> Path:
    base = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    return Path(base) / "mpire-ai"


def config_path() -> Path:
    return config_dir() / "config.json"


# Cloud services offered in Settings. "key" is the environment variable that
# also supplies a key (handy for people who already export one).
PRESETS = {
    "anthropic": dict(name="Anthropic", kind="anthropic", url="https://api.anthropic.com",
                      model="claude-opus-5-5", where="cloud", env="ANTHROPIC_API_KEY",
                      blurb="Claude models", keyUrl="https://console.anthropic.com/settings/keys"),
    "openai": dict(name="OpenAI", kind="openai", url="https://api.openai.com/v1", model="",
                   where="cloud", env="OPENAI_API_KEY", blurb="GPT models",
                   keyUrl="https://platform.openai.com/api-keys"),
    "gemini": dict(name="Google Gemini", kind="openai", url="https://generativelanguage.googleapis.com/v1beta/openai",
                   model="", where="cloud", env="GEMINI_API_KEY", blurb="Gemini models",
                   keyUrl="https://aistudio.google.com/apikey"),
    "openrouter": dict(name="OpenRouter", kind="openai", url="https://openrouter.ai/api/v1", model="",
                       where="cloud", env="OPENROUTER_API_KEY", blurb="Many models, one key",
                       keyUrl="https://openrouter.ai/keys"),
    "custom": dict(name="Other service", kind="openai", url="", model="", where="cloud", env="",
                   blurb="Any OpenAI-compatible API", keyUrl=""),
}

# Model servers people run themselves: the port each listens on by default.
SERVERS = {
    "ollama": dict(name="Ollama", port=11434, path="/v1"),
    "lmstudio": dict(name="LM Studio", port=1234, path="/v1"),
    "llamacpp": dict(name="llama.cpp", port=8080, path="/v1"),
    "vllm": dict(name="vLLM", port=8000, path="/v1"),
}


def empty() -> dict:
    return {"default": "", "providers": [], "gateway": {"tcp": False, "port": 11500}}


def load() -> dict:
    for path in (config_path(), SYSTEM_CONFIG):
        try:
            with open(path, encoding="utf-8") as f:
                cfg = json.load(f)
        except FileNotFoundError:
            continue
        except (OSError, ValueError):
            continue
        base = empty()
        base.update({k: v for k, v in cfg.items() if k in base})
        base["providers"] = [p for p in base["providers"] if isinstance(p, dict) and p.get("id")]
        if not any(p["id"] == base["default"] for p in base["providers"]):
            base["default"] = base["providers"][0]["id"] if base["providers"] else ""
        return base
    return empty()


def save(cfg: dict) -> None:
    path = config_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)


def find(cfg: dict, pid: str = "") -> dict | None:
    pid = pid or cfg.get("default", "")
    return next((p for p in cfg["providers"] if p["id"] == pid), None)


def new_id(cfg: dict, base: str) -> str:
    base = re.sub(r"[^a-z0-9]+", "-", base.lower()).strip("-") or "ai"
    taken = {p["id"] for p in cfg["providers"]}
    pid, n = base, 2
    while pid in taken:
        pid, n = f"{base}-{n}", n + 1
    return pid


def add(cfg: dict, provider: dict) -> dict:
    """Adds a provider (or updates the one with the same URL) and returns it."""
    p = {k: provider.get(k, "") for k in ("id", "name", "kind", "url", "model", "where", "preset", "server")}
    p["kind"] = p["kind"] if p["kind"] in ("anthropic", "openai") else "openai"
    p["where"] = p["where"] if p["where"] in ("cloud", "local", "network") else "cloud"
    p["url"] = p["url"].rstrip("/")
    same = next((q for q in cfg["providers"] if q["url"] == p["url"] and q["kind"] == p["kind"]
                 and p["url"] and p["preset"] in ("", q.get("preset", ""))), None)
    if same:
        same.update({k: v for k, v in p.items() if v and k != "id"})
        p = same
    else:
        p["id"] = p["id"] if p["id"] and not find(cfg, p["id"]) else new_id(cfg, p["id"] or p["name"] or "ai")
        cfg["providers"].append(p)
    if not cfg.get("default"):
        cfg["default"] = p["id"]
    return p


def from_preset(preset: str, **overrides) -> dict:
    if preset not in PRESETS:
        raise KeyError(preset)
    pr = PRESETS[preset]
    p = dict(id=preset if preset != "custom" else "", name=pr["name"], kind=pr["kind"], url=pr["url"],
             model=pr["model"], where=pr["where"], preset=preset)
    p.update({k: v for k, v in overrides.items() if v})
    return p
