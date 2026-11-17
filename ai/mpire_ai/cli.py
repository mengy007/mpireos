"""mpire-ai: MpireOS's AI from the command line.

  mpire-ai ask "how do I resize a partition?"   ask the chosen AI
  mpire-ai status                                what's set up
  mpire-ai add anthropic                         add a cloud provider (then: key set)
  mpire-ai add --url http://192.168.1.20:11434/v1 --name "Ollama on studio" --where network
  mpire-ai key set anthropic < keyfile           store an API key (read from stdin)
  mpire-ai discover [--network]                  find model servers
  mpire-ai default <id> | model <id> <model> | models <id> | remove <id> | test <id>
  mpire-ai local setup [model]                   install Ollama and a model sized for this computer
  mpire-ai gateway on|off|status                 the OpenAI-compatible endpoint for apps
  mpire-ai env                                   shell exports pointing OpenAI clients at it
  mpire-ai chat --json                           for the desktop: JSON in, JSON lines out
"""
import argparse
import getpass
import json
import os
import shutil
import subprocess
import sys

from . import config, core, discovery, gateway, keys, providers


def _out(obj, as_json: bool, text: str = "") -> None:
    if as_json:
        print(json.dumps(obj))
    elif text:
        print(text)


def _fail(message: str, as_json: bool = False) -> int:
    if as_json:
        print(json.dumps({"error": message}), flush=True)
    else:
        print(f"mpire-ai: {message}", file=sys.stderr)
    return 1


def cmd_ask(a) -> int:
    text = " ".join(a.text) if a.text else sys.stdin.read()
    if not text.strip():
        return _fail("nothing to ask")
    try:
        for kind, value in core.chat([{"role": "user", "content": text}], a.provider, a.model):
            if kind == "text":
                sys.stdout.write(value)
                sys.stdout.flush()
    except providers.ProviderError as e:
        return _fail(str(e))
    print()
    return 0


def cmd_chat(a) -> int:
    """stdin: {"messages": [...], "provider": "", "model": ""}. stdout: one JSON
    object per line: {"provider": {...}}, {"delta": "..."}..., then {"done": true}
    or {"error": "..."}."""
    try:
        req = json.loads(sys.stdin.read() or "{}")
    except ValueError:
        return _fail("the request isn't JSON", True)
    try:
        for kind, value in core.chat(req.get("messages", []), req.get("provider", a.provider), req.get("model", a.model)):
            if kind == "meta":
                print(json.dumps({"provider": {k: value.get(k, "") for k in ("id", "name", "model", "where")}}), flush=True)
            else:
                print(json.dumps({"delta": value}), flush=True)
    except providers.ProviderError as e:
        return _fail(str(e), True)
    except KeyboardInterrupt:
        return 130
    print(json.dumps({"done": True}), flush=True)
    return 0


def cmd_status(a) -> int:
    st = core.status()
    if a.json:
        print(json.dumps(st))
        return 0
    if not st["providers"]:
        print("No AI is set up yet. Try `mpire-ai add anthropic` or `mpire-ai discover`.")
    for p in st["providers"]:
        mark = "*" if p["isDefault"] else " "
        key = "" if not p["needsKey"] else (f"  key: {p['keyLabel'].lower()}" if p["hasKey"] else "  needs a key")
        print(f"{mark} {p['id']:<16} {p['name']} ({p['where']}) {p['model'] or '(model not chosen)'}{key}")
    return 0


def cmd_add(a) -> int:
    cfg = config.load()
    if a.from_json:
        p = config.add(cfg, json.loads(a.from_json))
    elif a.preset:
        try:
            p = config.add(cfg, config.from_preset(a.preset, url=a.url, name=a.name, model=a.model))
        except KeyError:
            return _fail(f"unknown preset {a.preset!r}; one of: {', '.join(config.PRESETS)}", a.json)
    elif a.url:
        p = config.add(cfg, dict(name=a.name or "AI server", kind=a.kind, url=a.url, model=a.model,
                                 where=a.where, server=a.server))
    else:
        return _fail("give a preset, --url, or --from-json", a.json)
    if a.make_default:
        cfg["default"] = p["id"]
    config.save(cfg)
    _out({"provider": p}, a.json, f"Added {p['name']} as {p['id']}.")
    return 0


def cmd_remove(a) -> int:
    cfg = config.load()
    if not config.find(cfg, a.id):
        return _fail(f"no provider {a.id!r}", a.json)
    cfg["providers"] = [p for p in cfg["providers"] if p["id"] != a.id]
    if cfg["default"] == a.id:
        cfg["default"] = cfg["providers"][0]["id"] if cfg["providers"] else ""
    config.save(cfg)
    keys.remove(a.id)
    _out({"ok": True}, a.json, f"Removed {a.id}.")
    return 0


def cmd_default(a) -> int:
    cfg = config.load()
    if not config.find(cfg, a.id):
        return _fail(f"no provider {a.id!r}", a.json)
    cfg["default"] = a.id
    config.save(cfg)
    _out({"ok": True}, a.json, f"{a.id} answers from now on.")
    return 0


def cmd_model(a) -> int:
    cfg = config.load()
    p = config.find(cfg, a.id)
    if not p:
        return _fail(f"no provider {a.id!r}", a.json)
    p["model"] = a.model
    config.save(cfg)
    _out({"ok": True}, a.json, f"{p['name']} uses {a.model}.")
    return 0


def cmd_models(a) -> int:
    try:
        p = core.resolve(a.id)
        key, _ = keys.lookup(p["id"], p.get("preset", ""))
        models = providers.list_models(p, key)
    except providers.ProviderError as e:
        return _fail(str(e), a.json)
    _out({"id": p["id"], "models": models, "current": p.get("model", "")}, a.json, "\n".join(models))
    return 0


def cmd_test(a) -> int:
    try:
        p = core.resolve(a.id)
        key, _ = keys.lookup(p["id"], p.get("preset", ""))
        if core.needs_key(p) and not key:
            raise providers.ProviderError(f"Add your {p['name']} API key first.")
        models = providers.list_models(p, key)
        model = core.ensure_model(p, key)
    except providers.ProviderError as e:
        return _fail(str(e), a.json)
    _out({"ok": True, "id": p["id"], "model": model, "models": len(models)}, a.json,
         f"{p['name']} works: {len(models)} models, using {model}.")
    return 0


def cmd_key(a) -> int:
    cfg = config.load()
    p = config.find(cfg, a.id)
    if not p:
        return _fail(f"no provider {a.id!r}", a.json)
    if a.action == "remove":
        keys.remove(a.id)
        _out({"ok": True}, a.json, "Key removed.")
        return 0
    if a.action == "status":
        where = keys.where(a.id, p.get("preset", ""))
        _out({"storage": where, "label": keys.LABELS.get(where, "")}, a.json, keys.LABELS.get(where, "No key stored."))
        return 0
    key = getpass.getpass("API key: ") if sys.stdin.isatty() else sys.stdin.readline()
    try:
        backend = keys.store(a.id, key, p["name"])
    except (ValueError, RuntimeError) as e:
        return _fail(f"couldn't store the key: {e}", a.json)
    _out({"ok": True, "storage": backend, "label": keys.LABELS[backend]}, a.json,
         f"Key saved ({keys.LABELS[backend].lower()}).")
    return 0


def cmd_discover(a) -> int:
    found = discovery.local()
    if a.network:
        found += discovery.network()
    cfg = config.load()
    known = {p["url"] for p in cfg["providers"]}
    for f in found:
        f["added"] = f["url"] in known
    discovery.remember(found, a.network)
    if a.json:
        print(json.dumps({"servers": found}))
    elif not found:
        print("No model servers found." + ("" if a.network else " Try --network to look on your network."))
    for f in found:
        print(f"{f['label']}: {f['url']}  ({len(f['models'])} models){'  [added]' if f['added'] else ''}")
    if a.add:
        for f in found:
            if not f["added"]:
                pid = f["server"] if f["where"] == "local" else f"{f['server']}-{f['host'].replace('.', '-')}"
                config.add(cfg, dict(id=pid, name=f["label"], kind="openai", url=f["url"], where=f["where"],
                                     server=f["server"], model=providers.pick_model(f["models"])))
        config.save(cfg)
    return 0


def _ram_gb() -> float:
    try:
        with open("/proc/meminfo") as f:
            return int(f.readline().split()[1]) / 1024 / 1024
    except (OSError, ValueError, IndexError):
        return 8


# Ollama models sized by memory: (minimum GB of RAM, model). Small enough to
# leave room for everything else the person runs.
LOCAL_MODELS = [(30, "qwen3:14b"), (14, "qwen3:8b"), (7, "llama3.2:3b"), (0, "gemma3:1b")]


def cmd_local(a) -> int:
    if a.action == "recommend":
        ram = _ram_gb()
        model = next(m for need, m in LOCAL_MODELS if ram >= need)
        _out({"model": model, "ramGB": round(ram, 1)}, a.json, model)
        return 0
    # setup: install Ollama, start it, download a model, and use it.
    run = lambda *cmd: subprocess.run(cmd).returncode == 0
    if not shutil.which("ollama"):
        pkg = "ollama-cuda" if os.path.exists("/proc/driver/nvidia/version") else "ollama"
        print(f"Installing {pkg}...", flush=True)
        if not run("pkexec", "pacman", "-S", "--needed", "--noconfirm", pkg):
            return _fail("couldn't install Ollama")
    if not discovery._open("127.0.0.1", 11434):
        print("Starting Ollama...", flush=True)
        if not run("pkexec", "systemctl", "enable", "--now", "ollama.service"):
            return _fail("couldn't start Ollama")
    model = a.model or next(m for need, m in LOCAL_MODELS if _ram_gb() >= need)
    print(f"Downloading {model} (this can take a while)...", flush=True)
    if not run("ollama", "pull", model):
        return _fail(f"couldn't download {model}")
    cfg = config.load()
    p = config.add(cfg, dict(id="ollama", name="Ollama on this computer", kind="openai",
                             url="http://127.0.0.1:11434/v1", model=model, where="local", server="ollama"))
    p["model"] = model
    cfg["default"] = p["id"]
    config.save(cfg)
    print(f"Done. MpireOS now answers with {model}, right on this computer.")
    return 0


def cmd_gateway(a) -> int:
    cfg = config.load()
    if a.action in ("on", "off"):
        cfg["gateway"]["tcp"] = a.action == "on"
        config.save(cfg)
        if a.action == "on":
            gateway.token()
        if shutil.which("systemctl"):
            verb = ["enable", "--now"] if a.action == "on" else ["disable"]
            subprocess.run(["systemctl", "--user", *verb, "mpire-ai.service"], capture_output=True)
            subprocess.run(["systemctl", "--user", "restart", "mpire-ai.service"], capture_output=True)
    on = cfg["gateway"].get("tcp", False)
    port = cfg["gateway"].get("port", 11500)
    _out({"tcp": on, "url": f"http://127.0.0.1:{port}/v1", "socket": gateway.socket_path()}, a.json,
         f"Apps can use AI at http://127.0.0.1:{port}/v1 (key: ~/.config/mpire-ai/gateway-token)" if on
         else f"Only through {gateway.socket_path()}. Turn on with `mpire-ai gateway on`.")
    return 0


def cmd_env(a) -> int:
    cfg = config.load()
    if not cfg["gateway"].get("tcp"):
        return _fail("the gateway is off; run `mpire-ai gateway on` first")
    port = cfg["gateway"].get("port", 11500)
    print(f"export OPENAI_BASE_URL=http://127.0.0.1:{port}/v1")
    print(f"export OPENAI_API_KEY={gateway.token()}")
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="mpire-ai", description="MpireOS's built-in AI.",
                                 formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__)
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    sub = ap.add_subparsers(dest="cmd")

    s = sub.add_parser("ask", help="ask the chosen AI")
    s.add_argument("text", nargs="*")
    s.add_argument("-p", "--provider", default="")
    s.add_argument("-m", "--model", default="")
    s.set_defaults(fn=cmd_ask)

    s = sub.add_parser("chat", help="JSON chat for the desktop")
    s.add_argument("-p", "--provider", default="")
    s.add_argument("-m", "--model", default="")
    s.set_defaults(fn=cmd_chat)

    for name in ("status", "providers"):
        sub.add_parser(name, help="what's set up").set_defaults(fn=cmd_status)

    s = sub.add_parser("add", help="add a provider")
    s.add_argument("preset", nargs="?", default="")
    s.add_argument("--url", default="")
    s.add_argument("--name", default="")
    s.add_argument("--model", default="")
    s.add_argument("--kind", default="openai", choices=["openai", "anthropic"])
    s.add_argument("--where", default="cloud", choices=["cloud", "local", "network"])
    s.add_argument("--server", default="")
    s.add_argument("--from-json", default="")
    s.add_argument("--default", dest="make_default", action="store_true")
    s.set_defaults(fn=cmd_add)

    for name, fn, extra in (("remove", cmd_remove, None), ("default", cmd_default, None), ("models", cmd_models, None),
                            ("test", cmd_test, None), ("model", cmd_model, "model")):
        s = sub.add_parser(name)
        s.add_argument("id")
        if extra:
            s.add_argument(extra)
        s.set_defaults(fn=fn)

    s = sub.add_parser("key", help="store or remove an API key")
    s.add_argument("action", choices=["set", "remove", "status"])
    s.add_argument("id")
    s.set_defaults(fn=cmd_key)

    s = sub.add_parser("discover", help="find model servers")
    s.add_argument("--network", action="store_true", help="also look on the local network")
    s.add_argument("--add", action="store_true", help="add what's found")
    s.set_defaults(fn=cmd_discover)

    s = sub.add_parser("local", help="run AI on this computer with Ollama")
    s.add_argument("action", choices=["setup", "recommend"])
    s.add_argument("model", nargs="?", default="")
    s.set_defaults(fn=cmd_local)

    s = sub.add_parser("gateway", help="the OpenAI-compatible endpoint for apps")
    s.add_argument("action", choices=["on", "off", "status"])
    s.set_defaults(fn=cmd_gateway)

    sub.add_parser("env", help="exports for OpenAI-compatible tools").set_defaults(fn=cmd_env)
    sub.add_parser("serve", help="run the gateway").set_defaults(fn=lambda a: gateway.serve() or 0)

    # --json is accepted before or after the command.
    argv = list(sys.argv[1:] if argv is None else argv)
    as_json = "--json" in argv
    argv = [x for x in argv if x != "--json"]
    a = ap.parse_args(argv)
    a.json = as_json
    if not getattr(a, "fn", None):
        ap.print_help()
        return 0
    try:
        return a.fn(a)
    except BrokenPipeError:
        return 0
