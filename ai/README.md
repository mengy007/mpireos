# mpire-ai

MpireOS's built-in AI layer. It knows which AI the person chose (a cloud service, a model on this computer, or one on their network), keeps API keys encrypted, and talks to it. Mpire Desktop's assistant, universal search, and AI settings use it, and apps can use it through an OpenAI-compatible gateway. Design: [docs/ai.md](../docs/ai.md).

Standard library Python only; packaged as `mpire-ai` (`packages/mpire-ai`).

```sh
mpire-ai add anthropic && mpire-ai key set anthropic   # paste the key when asked
mpire-ai ask "how do I resize a partition?"
mpire-ai discover --network --add                      # use a model server on the LAN
mpire-ai local setup                                   # Ollama + a model sized for this computer
mpire-ai status
mpire-ai gateway on && eval "$(mpire-ai env)"          # point OpenAI clients at MpireOS
```

| File | What it does |
| --- | --- |
| `mpire_ai/config.py` | Providers and presets, `~/.config/mpire-ai/config.json` (no secrets) |
| `mpire_ai/keys.py` | Key storage: systemd-creds, then the keyring, then a 0600 file |
| `mpire_ai/providers.py` | Anthropic Messages API and OpenAI-compatible streaming, model lists |
| `mpire_ai/discovery.py` | Finds Ollama, LM Studio, llama.cpp, and vLLM here and on the LAN |
| `mpire_ai/gateway.py` | OpenAI-compatible endpoint for apps (unix socket, optional TCP with a token) |
| `mpire_ai/core.py` | Chat with the chosen provider; the state AI settings shows |
| `mpire_ai/cli.py` | The `mpire-ai` command, including `chat --json` for the desktop |

Tests run against a stand-in model server (also used by the CI boot test):

```sh
python3 -m unittest discover -s ai/tests
python3 ai/tests/mock_server.py 11434      # a fake Ollama to try the desktop with
```
