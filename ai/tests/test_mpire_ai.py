"""Tests for mpire-ai against the stand-in model server.

    python3 -m unittest discover -s ai/tests
"""
import json
import os
import socket
import subprocess
import sys
import tempfile
import threading
import time
import unittest
import urllib.request
from http.server import ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE))

import mock_server  # noqa: E402
from mpire_ai import config, core, discovery, gateway, keys, providers  # noqa: E402


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


class MpireAiTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.port = free_port()
        cls.server = ThreadingHTTPServer(("127.0.0.1", cls.port), mock_server.H)
        threading.Thread(target=cls.server.serve_forever, daemon=True).start()
        cls.url = f"http://127.0.0.1:{cls.port}"

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        for var in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_RUNTIME_DIR"):
            os.environ[var] = os.path.join(self.tmp.name, var)
            os.makedirs(os.environ[var], mode=0o700)
        os.environ["MPIRE_AI_KEY_BACKENDS"] = "file"
        os.environ.pop("ANTHROPIC_API_KEY", None)

    def tearDown(self):
        self.tmp.cleanup()

    def add(self, **p):
        cfg = config.load()
        out = config.add(cfg, p)
        config.save(cfg)
        return out

    def test_openai_compatible_stream_and_model_pick(self):
        self.add(name="Ollama", url=self.url + "/v1", where="network", server="ollama")
        chunks = list(core.chat([{"role": "user", "content": "screenshot?"}]))
        self.assertEqual(chunks[0][0], "meta")
        self.assertEqual(chunks[0][1]["model"], mock_server.MODEL)
        self.assertEqual("".join(c for k, c in chunks if k == "text"), mock_server.REPLY)
        self.assertEqual(config.load()["providers"][0]["model"], mock_server.MODEL)   # remembered

    def test_anthropic_needs_and_uses_key(self):
        p = self.add(**config.from_preset("anthropic", url=self.url))
        with self.assertRaises(providers.ProviderError):
            list(core.chat([{"role": "user", "content": "hi"}]))
        keys.store(p["id"], "sk-test\n")
        self.assertEqual(keys.lookup(p["id"])[0], "sk-test")
        self.assertEqual(oct(os.stat(keys._dir() / "anthropic.key").st_mode & 0o777), "0o600")
        text = "".join(c for k, c in core.chat([{"role": "user", "content": "hi"}]) if k == "text")
        self.assertEqual(text, "You asked: hi")
        keys.store(p["id"], "wrong")
        with self.assertRaisesRegex(providers.ProviderError, "didn't accept the API key"):
            list(core.chat([{"role": "user", "content": "hi"}]))
        self.assertNotIn("sk-test", config.config_path().read_text())

    def test_env_key_fallback(self):
        self.add(**config.from_preset("anthropic", url=self.url))
        os.environ["ANTHROPIC_API_KEY"] = "sk-test"
        self.assertEqual(core.status()["providers"][0]["keyStorage"], "env")
        self.assertTrue(list(core.chat([{"role": "user", "content": "hi"}])))

    def test_unreachable_is_explained(self):
        self.add(name="Gone", url=f"http://127.0.0.1:{free_port()}/v1", where="network", model="x")
        with self.assertRaisesRegex(providers.ProviderError, "Can't reach Gone"):
            list(core.chat([{"role": "user", "content": "hi"}]))

    def test_identify_server(self):
        found = discovery.identify("127.0.0.1", self.port)
        self.assertEqual(found["server"], "ollama")
        self.assertEqual(found["models"], [mock_server.MODEL])
        self.assertIsNone(discovery.identify("127.0.0.1", free_port()))

    def test_gateway_over_unix_socket(self):
        self.add(name="Ollama", url=self.url + "/v1", where="local")
        threading.Thread(target=gateway.serve, daemon=True).start()
        path = gateway.socket_path()
        for _ in range(50):
            if os.path.exists(path):
                break
            time.sleep(0.05)
        self.assertEqual(oct(os.stat(path).st_mode & 0o777), "0o600")
        out = subprocess.run(["curl", "-s", "--unix-socket", path, "http://x/v1/chat/completions", "-d",
                              json.dumps({"model": "default", "messages": [{"role": "user", "content": "yo"}]})],
                             capture_output=True, text=True, timeout=10).stdout
        self.assertEqual(json.loads(out)["choices"][0]["message"]["content"], "You asked: yo")

    def test_cli_chat_json_lines(self):
        self.add(name="Ollama", url=self.url + "/v1", where="local")
        out = subprocess.run([sys.executable, str(HERE.parent / "mpire-ai"), "chat", "--json"],
                             input=json.dumps({"messages": [{"role": "user", "content": "yo"}]}),
                             capture_output=True, text=True, timeout=20, env=os.environ).stdout
        lines = [json.loads(line) for line in out.splitlines()]
        self.assertIn("provider", lines[0])
        self.assertEqual("".join(x.get("delta", "") for x in lines), "You asked: yo")
        self.assertTrue(lines[-1]["done"])


if __name__ == "__main__":
    unittest.main()
