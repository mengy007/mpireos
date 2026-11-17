# AI in MpireOS

MpireOS has AI built in, the way it has search or notifications built in: one assistant for the whole desktop, and one AI setting for the whole system. The person chooses where their AI runs, and everything else follows that choice.

- **Cloud**: Anthropic, OpenAI, Google Gemini, OpenRouter, or any OpenAI-compatible service, with the person's own API key.
- **This computer**: a model running locally with Ollama, LM Studio, llama.cpp, or vLLM. `mpire-ai local setup` installs Ollama and downloads a model sized for the computer's memory.
- **Your network**: a model server on another computer at home or work (a desktop with a big GPU, a home server), found by searching the local network or added by address.

## What the person sees

| Where | What it does |
| --- | --- |
| Assistant (Meta+A, or the sparkle in the top bar) | A conversation panel on the right of the screen. Replies stream in and render Markdown, with Copy. Shows which AI is answering. |
| Universal search (Meta+Space) | Every search offers "Ask AI". A query that reads like a question ("how do I…?", "write…", "explain…", or one ending in `?`) puts it first, so Meta+Space, type, Enter opens the answer in the assistant. |
| AI settings (search "AI", the assistant's gear, or `mpire-shell --show ai-settings`) | Lists the AIs set up, which one answers, and each one's model. Adds a cloud service (paste a key), a model on this computer, or one on the network ("Find on My Network", or type an address). Turns on the endpoint for apps. |

When nothing is set up, the assistant offers the three choices instead of an empty chat.

## How it's built

```
 Mpire Desktop (mpire-shell)            other apps and coding tools
   assistant · search · AI settings       (anything that speaks the OpenAI API)
            │                                      │
            │ mpire-ai chat --json            mpire-ai gateway
            │ (JSON lines over stdio)         unix socket, or 127.0.0.1:11500 with a token
            ▼                                      ▼
 ┌────────────────────────── mpire-ai ──────────────────────────┐
 │ config: ~/.config/mpire-ai/config.json (no secrets)          │
 │ keys: systemd-creds (encrypted to this computer, TPM when    │
 │       present) → Secret Service keyring → 0600 file          │
 │ discovery: local ports, LAN /24 scan, mDNS                   │
 │ providers: Anthropic Messages API · OpenAI-compatible        │
 └──────────────────────────────────────────────────────────────┘
        │                     │                        │
   api.anthropic.com    Ollama on 127.0.0.1     Ollama on 192.168.1.40
   api.openai.com …     LM Studio, llama.cpp    (another computer)
```

- **`mpire-ai`** (`ai/`, package `mpire-ai`) is the provider layer: Python, standard library only. It is the only thing that reads API keys. Two wire protocols cover every provider: Anthropic's Messages API and OpenAI-compatible chat completions (which OpenAI, Gemini, OpenRouter, Ollama, LM Studio, llama.cpp, and vLLM all speak).
- **The desktop** (`desktop/src/ai.*`, `shell/panels/Assistant.qml`, `AiSettings.qml`) runs `mpire-ai` and reads its JSON. A key typed in AI settings goes to `mpire-ai key set` over stdin and is never kept by the shell or put on a command line.
- **The gateway** (`mpire-ai serve`, started by `mpire-ai.socket` on first use) gives apps one OpenAI-compatible endpoint for whichever AI the person chose. Model `default` is the chosen AI; `<provider id>` or `<provider id>/<model>` picks another. On the unix socket (`$XDG_RUNTIME_DIR/mpire-ai.sock`) only the person's own apps can connect. The TCP address is off by default; "Let apps use AI" turns it on, and it then requires the token in `~/.config/mpire-ai/gateway-token`. `mpire-ai env` prints `OPENAI_BASE_URL` and `OPENAI_API_KEY` exports for tools.

### Keys

Keys never go in `config.json`. `mpire-ai key set` tries, in order:

1. `systemd-creds encrypt --user`: encrypted with the machine's credential key (and its TPM 2.0 chip when it has one), scoped to the user, in `~/.local/share/mpire-ai/keys/<id>.cred`. A copied file can't be decrypted on another computer, and nothing prompts for a password.
2. The Secret Service keyring (KWallet or GNOME Keyring) through `secret-tool`, if `libsecret` is installed.
3. A file only the user can read (0600), as a last resort.

It checks the key decrypts before trusting it with the only copy. An exported `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, or `OPENROUTER_API_KEY` is used when nothing is stored.

### Finding models

- **This computer**: the default ports of Ollama (11434), LM Studio (1234), llama.cpp (8080), and vLLM (8000) on 127.0.0.1. Settings looks when its "This computer" tab opens.
- **The network**: only when the person asks ("Find on My Network" or `mpire-ai discover --network`). Every address in the computer's own private subnets (at most a /24 each) on those ports, plus servers announcing `_ollama._tcp` or `_openai._tcp` over mDNS when Avahi is installed. A port only counts if it answers with a list of models. Probes never go through a proxy. Ollama only listens on its own computer by default; the other computer needs `OLLAMA_HOST=0.0.0.0`.

### Claude defaults

The Anthropic preset uses `claude-opus-5-5`, API version `2026-10-21`, streaming, and server-side refusal fallbacks (`fallbacks: "default"`) on the models that support them. Thinking runs adaptively by default on current models; the assistant shows dots until the first words arrive.

## Compared with Omarchy

Omarchy (DHH's Arch setup) integrates AI through **coding agents**: launchers for Claude Code, Codex, OpenCode and many more, a default agent on a hotkey, an agents panel with subscription usage, local models through Podman recipes, and an Omarchy skill so agents can customize the system. It assumes the person lives in a terminal.

MpireOS starts from the **desktop**: a friendly assistant and search that work for anyone, one place to choose cloud, local, or network AI, keys kept encrypted by the system, and a gateway so apps share that choice. The agent ideas carry over well and are on the list below.

## Next

- Let the assistant act, with permission: open apps and settings, find files, explain an error from the journal (tools with a confirm step).
- Share this computer's local models with the network from AI settings, and announce them over mDNS (`_mpire-ai._tcp`) so other MpireOS computers find them instantly.
- A coding-agent launcher like Omarchy's (Claude Code, Codex, OpenCode) wired to the same provider choice, plus an MpireOS skill so agents know how to change the system safely.
- Keep conversations (opt-in), and pick a model per conversation.
- Usage and cost per provider in AI settings.
- Welcome app: offer the three choices on first run.
