"""Finds model servers on this computer and on the local network.

On this computer: the default ports of Ollama, LM Studio, llama.cpp, and vLLM.
On the network (only when the person asks): every address in this computer's
own /24 (or smaller) subnets, on the same ports, plus servers that announce
themselves over mDNS as _ollama._tcp or _openai._tcp (avahi-browse, if
installed). A port only counts once it answers like a model server, with a
list of models.
"""
import concurrent.futures as futures
import ipaddress
import json
import shutil
import socket
import subprocess
import urllib.request

from . import config
from .config import SERVERS

CONNECT_TIMEOUT = 0.35
HTTP_TIMEOUT = 2.5


def _get(url: str):
    req = urllib.request.Request(url, headers={"user-agent": "mpire-ai/0.1 (MpireOS)"})
    # Never send LAN probes through a proxy.
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(req, timeout=HTTP_TIMEOUT) as r:
        return json.load(r)


def identify(host: str, port: int, hint: str = "") -> dict | None:
    """What model server, if any, answers at host:port."""
    hostport = f"[{host}]:{port}" if ":" in host else f"{host}:{port}"
    base = f"http://{hostport}"
    server, models = "", []
    try:
        tags = _get(base + "/api/tags")          # Ollama's own API
        models = [m.get("name") or m.get("model") for m in tags.get("models", [])]
        server = "ollama"
    except Exception:
        try:
            body = _get(base + "/v1/models")
            models = [m.get("id") for m in body.get("data", []) if isinstance(m, dict)]
            server = hint or next((k for k, s in SERVERS.items() if s["port"] == port), "openai")
        except Exception:
            return None
    models = [m for m in models if m]
    return dict(server=server, host=host, port=port, url=base + "/v1", models=models,
                name=SERVERS.get(server, {}).get("name", "AI server"))


def _open(host: str, port: int) -> bool:
    try:
        with socket.create_connection((host, port), timeout=CONNECT_TIMEOUT):
            return True
    except OSError:
        return False


def _ports():
    return sorted({s["port"] for s in SERVERS.values()})


def local() -> list[dict]:
    found = []
    with futures.ThreadPoolExecutor(8) as pool:
        hits = [port for port, ok in zip(_ports(), pool.map(lambda p: _open("127.0.0.1", p), _ports())) if ok]
        for result in pool.map(lambda p: identify("127.0.0.1", p), hits):
            if result:
                result.update(where="local", label=f"{result['name']} on this computer")
                found.append(result)
    return found


def own_networks() -> tuple[list, set]:
    """This computer's IPv4 subnets (at most /24 each) and its own addresses."""
    nets, mine = [], set()
    try:
        out = subprocess.run(["ip", "-j", "-4", "addr", "show", "up"], capture_output=True, text=True, timeout=5).stdout
        for iface in json.loads(out or "[]"):
            if iface.get("ifname") == "lo" or "LOOPBACK" in iface.get("flags", []):
                continue
            for a in iface.get("addr_info", []):
                if a.get("family") != "inet" or a.get("scope") != "global":
                    continue
                ip = ipaddress.ip_address(a["local"])
                mine.add(str(ip))
                net = ipaddress.ip_network(f"{ip}/{max(int(a.get('prefixlen', 24)), 24)}", strict=False)
                if net.is_private and net not in nets:
                    nets.append(net)
    except (OSError, ValueError, subprocess.SubprocessError):
        pass
    return nets, mine


def _mdns() -> list[tuple[str, int, str]]:
    if not shutil.which("avahi-browse"):
        return []
    hits = []
    for service, hint in (("_ollama._tcp", "ollama"), ("_openai._tcp", "openai")):
        try:
            out = subprocess.run(["avahi-browse", "-rtp", service], capture_output=True, text=True, timeout=4).stdout
        except (OSError, subprocess.SubprocessError):
            continue
        for line in out.splitlines():
            f = line.split(";")
            if f[0] == "=" and len(f) > 8 and f[2] == "IPv4":
                hits.append((f[7], int(f[8]), hint))
    return hits


def network() -> list[dict]:
    nets, mine = own_networks()
    targets = [(str(h), port) for net in nets for h in net.hosts() if str(h) not in mine for port in _ports()]
    found, seen = [], set()
    with futures.ThreadPoolExecutor(128) as pool:
        open_ports = [t for t, ok in zip(targets, pool.map(lambda t: _open(*t), targets)) if ok]
        candidates = [(h, p, "") for h, p in open_ports] + [c for c in _mdns() if c[0] not in mine]
        for result in pool.map(lambda c: identify(*c), candidates):
            if result and (result["host"], result["port"]) not in seen:
                seen.add((result["host"], result["port"]))
                result.update(where="network", label=f"{result['name']} on {_hostname(result['host'])}")
                found.append(result)
    return found


def _hostname(ip: str) -> str:
    pool = futures.ThreadPoolExecutor(1)
    job = pool.submit(socket.gethostbyaddr, ip)
    try:
        name = job.result(timeout=1)[0]
        return name.split(".")[0] if name and not name.startswith(ip) else ip
    except Exception:
        return ip
    finally:
        pool.shutdown(wait=False)


def _cache():
    return config.data_dir() / "servers.json"


def remember(found: list[dict], network: bool) -> None:
    """Keeps the last search's results, so AI settings can list them later.
    A search of this computer only keeps earlier network results."""
    kept = [] if network else [s for s in recall() if s.get("where") == "network"]
    try:
        path = _cache()
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(found + kept))
    except OSError:
        pass


def recall() -> list[dict]:
    try:
        return json.loads(_cache().read_text())
    except (OSError, ValueError):
        return []
