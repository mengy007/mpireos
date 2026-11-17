"""What the CLI, the gateway, and the desktop share: chatting with the chosen
provider, and the state shown in AI settings."""
import datetime
import platform

from . import config, discovery, keys, providers

SYSTEM_PROMPT = """You are the assistant built into MpireOS, a Linux desktop operating system based on Arch Linux, with its own desktop called Mpire Desktop (KDE apps and tools underneath). The person is talking to you from their desktop's assistant panel or universal search.

Answer clearly and briefly; lead with the answer. Use Markdown for lists, steps and code. When asked how to do something on this computer, give steps that work on MpireOS: pacman or Discover for software, `mpire-update` for system updates (it snapshots first), `mpire-rollback` to undo a bad update, systemctl for services, and KDE System Settings for anything Mpire Desktop doesn't cover yet. Never claim to have run commands or changed settings yourself."""


def system_prompt() -> str:
    today = datetime.date.today().strftime("%A, %B %-d, %Y")
    return f"{SYSTEM_PROMPT}\n\nToday is {today}. Kernel: {platform.release()}."


def needs_key(p: dict) -> bool:
    return p.get("where") == "cloud"


def resolve(pid: str = "") -> dict:
    cfg = config.load()
    p = config.find(cfg, pid)
    if not p:
        if pid:
            raise providers.ProviderError(f"There's no AI called {pid!r}. See `mpire-ai providers`.")
        raise providers.ProviderError("No AI is set up yet. Open AI settings to choose one.")
    return p


def ensure_model(p: dict, key: str | None) -> str:
    """The provider's model; picks and saves one when none was chosen."""
    if p.get("model"):
        return p["model"]
    model = providers.pick_model(providers.list_models(p, key))
    if not model:
        raise providers.ProviderError(f"{p['name']} has no models yet."
                                      + (" Download one with `ollama pull`." if p.get("server") == "ollama" else ""))
    cfg = config.load()
    saved = config.find(cfg, p["id"])
    if saved is not None:
        saved["model"] = model
        config.save(cfg)
    p["model"] = model
    return model


def chat(messages: list[dict], pid: str = "", model: str = "", system: str | None = None):
    """Yields ("meta", provider) once, then ("text", chunk)... Raises ProviderError."""
    p = resolve(pid)
    key, _ = keys.lookup(p["id"], p.get("preset", ""))
    if needs_key(p) and not key:
        raise providers.ProviderError(f"Add your {p['name']} API key in AI settings.")
    model = model or ensure_model(p, key)
    yield "meta", dict(p, model=model)
    for chunk in providers.stream_chat(p, key, messages, system_prompt() if system is None else system, model):
        yield "text", chunk


def status() -> dict:
    cfg = config.load()
    out = []
    for p in cfg["providers"]:
        where = keys.where(p["id"], p.get("preset", "")) if needs_key(p) else ""
        out.append(dict(p, hasKey=bool(where), keyStorage=where, keyLabel=keys.LABELS.get(where, ""),
                        needsKey=needs_key(p), isDefault=p["id"] == cfg["default"]))
    presets = [dict(id=k, **{f: v for f, v in pr.items() if f != "env"}) for k, pr in config.PRESETS.items()]
    known = {p["url"] for p in cfg["providers"]}
    found = [dict(s, added=s.get("url") in known) for s in discovery.recall()]
    return dict(default=cfg["default"], providers=out, presets=presets, gateway=cfg["gateway"], found=found)
