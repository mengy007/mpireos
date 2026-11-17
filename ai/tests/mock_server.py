#!/usr/bin/env python3
"""A stand-in model server for tests and the CI boot test.

Speaks Ollama's /api/tags and the OpenAI-compatible /v1/models and
/v1/chat/completions (streaming or not), and answers every question with a
canned, streamed reply. Also /v1/messages in Anthropic's format, for testing
that path. Usage: mock_server.py [port] [host] [seconds between words]
"""
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MODEL = "mpire-test:3b"
DELAY = 0.0          # seconds between streamed words
REPLY = ("To take a screenshot on MpireOS, press **Print Screen**. Spectacle opens, and you can:\n\n"
         "1. Pick the whole screen, a window, or a region\n"
         "2. Click **Save** or **Copy to Clipboard**\n\n"
         "Screenshots are saved in `~/Pictures/Screenshots`.")


def words(text):
    out, buf = [], ""
    for ch in text:
        buf += ch
        if ch in " \n":
            out.append(buf)
            buf = ""
    return out + ([buf] if buf else [])


class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *a):
        pass

    def _json(self, obj, code=200):
        b = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path == "/api/tags":
            return self._json({"models": [{"name": MODEL, "model": MODEL}]})
        if self.path in ("/v1/models", "/models"):
            return self._json({"object": "list", "data": [{"id": MODEL, "object": "model"}]})
        self._json({"error": "not found"}, 404)

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers.get("content-length", 0))) or "{}")
        last = next((m["content"] for m in reversed(body.get("messages", [])) if m.get("role") == "user"), "")
        reply = REPLY if "screenshot" in str(last).lower() else f"You asked: {last}"
        if self.path == "/v1/messages":
            if self.headers.get("x-api-key") != "sk-test":
                return self._json({"type": "error", "error": {"type": "authentication_error", "message": "invalid x-api-key"}}, 401)
            self.send_response(200)
            self.send_header("content-type", "text/event-stream")
            self.send_header("connection", "close")
            self.end_headers()
            ev = lambda name, obj: self.wfile.write(f"event: {name}\ndata: {json.dumps(obj)}\n\n".encode())
            ev("message_start", {"type": "message_start", "message": {"id": "msg_1"}})
            ev("content_block_start", {"type": "content_block_start", "index": 0, "content_block": {"type": "text", "text": ""}})
            for w in words(reply):
                ev("content_block_delta", {"type": "content_block_delta", "index": 0, "delta": {"type": "text_delta", "text": w}})
            ev("message_delta", {"type": "message_delta", "delta": {"stop_reason": "end_turn"}})
            ev("message_stop", {"type": "message_stop"})
            return
        if self.path not in ("/v1/chat/completions", "/chat/completions"):
            return self._json({"error": "not found"}, 404)
        if not body.get("stream"):
            return self._json({"choices": [{"index": 0, "message": {"role": "assistant", "content": reply}}]})
        self.send_response(200)
        self.send_header("content-type", "text/event-stream")
        self.send_header("connection", "close")
        self.end_headers()
        for w in words(reply):
            chunk = {"choices": [{"index": 0, "delta": {"content": w}}]}
            self.wfile.write(b"data: " + json.dumps(chunk).encode() + b"\n\n")
            self.wfile.flush()
            time.sleep(DELAY)
        self.wfile.write(b"data: [DONE]\n\n")


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 11434
    host = sys.argv[2] if len(sys.argv) > 2 else "127.0.0.1"
    DELAY = float(sys.argv[3]) if len(sys.argv) > 3 else 0.0
    ThreadingHTTPServer((host, port), H).serve_forever()
