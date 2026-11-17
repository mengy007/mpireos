"""An OpenAI-compatible endpoint for every app on the computer.

Apps and coding tools that speak the OpenAI API can point at MpireOS instead
of a particular provider, and get whichever AI the person chose in Settings,
with keys staying inside mpire-ai:

  unix socket  $XDG_RUNTIME_DIR/mpire-ai.sock   (only this user can open it)
  TCP          http://127.0.0.1:11500/v1         (off by default; needs the
               token in ~/.config/mpire-ai/gateway-token as the API key)

Endpoints: GET /v1/models, POST /v1/chat/completions (streaming or not).
Models: "default" (the chosen AI), "<provider id>" (its chosen model), or
"<provider id>/<model>". Run by systemd (mpire-ai.socket starts it on first
use) or by hand with `mpire-ai serve`.
"""
import hmac
import json
import os
import secrets
import socket
import socketserver
import threading
import time
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from . import config, core, providers


def socket_path() -> str:
    return os.path.join(os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}", "mpire-ai.sock")


def token(create=True) -> str:
    path = config.config_dir() / "gateway-token"
    try:
        return path.read_text().strip()
    except OSError:
        if not create:
            return ""
    path.parent.mkdir(parents=True, exist_ok=True)
    value = "mpire-" + secrets.token_urlsafe(32)
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(value + "\n")
    return value


def _text(content) -> str:
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(p.get("text", "") for p in content if isinstance(p, dict) and p.get("type") in ("text", None))
    return ""


class Handler(BaseHTTPRequestHandler):
    server_version = "mpire-ai"
    protocol_version = "HTTP/1.1"
    need_token = False

    def log_message(self, fmt, *args):
        pass

    def address_string(self):
        return "local"

    def _json(self, code: int, obj) -> None:
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _error(self, code: int, message: str) -> None:
        self._json(code, {"error": {"message": message, "type": "mpire_ai_error"}})

    def _authorized(self) -> bool:
        if not self.need_token:
            return True
        given = self.headers.get("authorization", "").removeprefix("Bearer ").strip()
        return bool(given) and hmac.compare_digest(given, token())

    def do_GET(self):
        if not self._authorized():
            return self._error(401, "Use the token in ~/.config/mpire-ai/gateway-token as your API key.")
        if self.path.rstrip("/") in ("/v1/models", "/models"):
            cfg = config.load()
            data = [{"id": "default", "object": "model", "owned_by": "mpireos"}]
            for p in cfg["providers"]:
                data.append({"id": p["id"], "object": "model", "owned_by": p.get("name", "")})
                if p.get("model"):
                    data.append({"id": f"{p['id']}/{p['model']}", "object": "model", "owned_by": p.get("name", "")})
            return self._json(200, {"object": "list", "data": data})
        if self.path in ("/", "/health"):
            return self._json(200, {"ok": True})
        self._error(404, "Not found")

    def do_POST(self):
        if not self._authorized():
            return self._error(401, "Use the token in ~/.config/mpire-ai/gateway-token as your API key.")
        if self.path.rstrip("/") not in ("/v1/chat/completions", "/chat/completions"):
            return self._error(404, "Not found")
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("content-length", "0"))) or "{}")
        except ValueError:
            return self._error(400, "The body isn't JSON.")
        msgs = body.get("messages") or []
        system = "\n\n".join(_text(m.get("content")) for m in msgs if m.get("role") in ("system", "developer"))
        chat = [{"role": m["role"], "content": _text(m.get("content"))} for m in msgs if m.get("role") in ("user", "assistant")]
        name = body.get("model") or "default"
        pid, _, model = ("", "", "") if name == "default" else name.partition("/")
        stream = bool(body.get("stream"))
        rid, created = "chatcmpl-" + uuid.uuid4().hex[:24], int(time.time())
        try:
            gen = core.chat(chat, pid, model, system=system)
            _, p = next(gen)
            used = f"{p['id']}/{p['model']}"
            if not stream:
                text = "".join(chunk for _, chunk in gen)
                return self._json(200, {"id": rid, "object": "chat.completion", "created": created, "model": used,
                                        "choices": [{"index": 0, "finish_reason": "stop",
                                                     "message": {"role": "assistant", "content": text}}]})
            self.send_response(200)
            self.send_header("content-type", "text/event-stream")
            self.send_header("cache-control", "no-cache")
            self.send_header("connection", "close")
            self.end_headers()
            self.close_connection = True

            def send(delta, finish=None):
                chunk = {"id": rid, "object": "chat.completion.chunk", "created": created, "model": used,
                         "choices": [{"index": 0, "delta": delta, "finish_reason": finish}]}
                self.wfile.write(b"data: " + json.dumps(chunk).encode() + b"\n\n")
                self.wfile.flush()

            send({"role": "assistant", "content": ""})
            try:
                for _, chunk in gen:
                    send({"content": chunk})
            except providers.ProviderError as e:
                self.wfile.write(b"data: " + json.dumps({"error": {"message": str(e)}}).encode() + b"\n\n")
            send({}, "stop")
            self.wfile.write(b"data: [DONE]\n\n")
            self.wfile.flush()
        except providers.ProviderError as e:
            self._error(502, str(e))
        except (BrokenPipeError, ConnectionResetError):
            pass


class UnixServer(socketserver.ThreadingMixIn, socketserver.UnixStreamServer):
    daemon_threads = True

    def get_request(self):
        conn, _ = self.socket.accept()
        return conn, ("local", 0)


def _activated_socket():
    """The socket systemd passed us (mpire-ai.socket), if any."""
    if os.environ.get("LISTEN_PID") == str(os.getpid()) and int(os.environ.get("LISTEN_FDS", "0")) >= 1:
        return socket.socket(fileno=3)
    return None


def serve() -> None:
    cfg = config.load()
    servers = []
    sock = _activated_socket()
    if sock is not None:
        srv = UnixServer(socket_path(), Handler, bind_and_activate=False)
        srv.socket.close()
        srv.socket = sock
    else:
        path = socket_path()
        if os.path.exists(path):
            os.unlink(path)
        old = os.umask(0o177)
        try:
            srv = UnixServer(path, Handler)
        finally:
            os.umask(old)
    servers.append(srv)
    if cfg["gateway"].get("tcp"):
        token()

        class TokenHandler(Handler):
            need_token = True
        tcp = ThreadingHTTPServer(("127.0.0.1", int(cfg["gateway"].get("port", 11500))), TokenHandler)
        tcp.daemon_threads = True
        servers.append(tcp)
    threads = [threading.Thread(target=s.serve_forever, daemon=True) for s in servers]
    for t in threads:
        t.start()
    try:
        while True:
            time.sleep(3600)
    except KeyboardInterrupt:
        pass
