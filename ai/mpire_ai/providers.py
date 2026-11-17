"""Talks to AI providers: streams chat replies and lists models.

Two wire protocols cover everything MpireOS offers:
  anthropic  the Claude Messages API (api.anthropic.com)
  openai     OpenAI-compatible chat completions, which OpenAI, Gemini,
             OpenRouter, Ollama, LM Studio, llama.cpp and vLLM all speak.
"""
import json
import socket
import urllib.error
import urllib.request

ANTHROPIC_VERSION = "2026-10-21"
# Claude models that accept server-side fallbacks when a safety classifier
# declines a request (the reply then comes from a fallback model instead).
FALLBACK_MODELS = ("claude-fable-5-2", "claude-fable-5-1", "claude-opus-5-5", "claude-opus-5", "claude-sonnet-5-5")
USER_AGENT = "mpire-ai/0.1 (MpireOS)"


class ProviderError(Exception):
    """A failure worth showing to the person, in plain words."""


def _headers(provider: dict, key: str | None) -> dict:
    h = {"content-type": "application/json", "user-agent": USER_AGENT}
    if provider["kind"] == "anthropic":
        h["anthropic-version"] = ANTHROPIC_VERSION
        if key:
            h["x-api-key"] = key
    elif key:
        h["authorization"] = f"Bearer {key}"
    return h


def _explain(provider: dict, err: Exception) -> ProviderError:
    name = provider.get("name") or provider.get("url")
    if isinstance(err, urllib.error.HTTPError):
        detail = ""
        try:
            body = json.loads(err.read().decode("utf-8", "replace") or "{}")
            e = body.get("error", body)
            detail = e.get("message", "") if isinstance(e, dict) else str(e)
        except (ValueError, OSError, AttributeError):
            pass
        if err.code in (401, 403):
            return ProviderError(f"{name} didn't accept the API key. Check it in AI settings.")
        if err.code == 404:
            return ProviderError(f"{name} doesn't know that model{': ' + detail if detail else '.'}")
        if err.code == 429:
            return ProviderError(f"{name} is busy or you've reached your usage limit. Try again in a moment.")
        if err.code >= 500:
            return ProviderError(f"{name} is having trouble right now ({err.code}). Try again in a moment.")
        return ProviderError(f"{name} said: {detail or err.reason} ({err.code})")
    if isinstance(err, urllib.error.URLError):
        reason = err.reason
        if isinstance(reason, (ConnectionRefusedError, socket.timeout, TimeoutError)) or "refused" in str(reason):
            return ProviderError(f"Can't reach {name} at {provider['url']}. Is it running?")
        return ProviderError(f"Can't reach {name}: {reason}")
    if isinstance(err, (socket.timeout, TimeoutError)):
        return ProviderError(f"{name} took too long to answer.")
    return ProviderError(f"{name}: {err}")


def _open(provider, key, method, path, body=None, timeout=30):
    url = provider["url"].rstrip("/") + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers=_headers(provider, key))
    try:
        return urllib.request.urlopen(req, timeout=timeout)
    except (urllib.error.URLError, OSError) as e:
        raise _explain(provider, e) from None


def _sse(resp):
    """Yields (event, data) pairs from a server-sent events stream."""
    event, data = "", []
    for raw in resp:
        line = raw.decode("utf-8", "replace").rstrip("\r\n")
        if not line:
            if data:
                yield event, "\n".join(data)
            event, data = "", []
        elif line.startswith(":"):
            continue
        elif line.startswith("event:"):
            event = line[6:].strip()
        elif line.startswith("data:"):
            data.append(line[5:].lstrip())
    if data:
        yield event, "\n".join(data)


def list_models(provider: dict, key: str | None, timeout=10) -> list[str]:
    path = "/v1/models" if provider["kind"] == "anthropic" else "/models"
    with _open(provider, key, "GET", path, timeout=timeout) as r:
        body = json.load(r)
    return [m["id"] for m in body.get("data", []) if isinstance(m, dict) and m.get("id")]


def pick_model(models: list[str]) -> str:
    """A sensible default when the person hasn't chosen a model."""
    if not models:
        return ""
    # Prefer chat models over embeddings, speech, images and moderation.
    skip = ("embed", "whisper", "tts", "dall-e", "moderation", "image", "audio", "realtime", "transcribe", "search")
    chat = [m for m in models if not any(s in m.lower() for s in skip)] or models
    return chat[0]


def stream_chat(provider: dict, key: str | None, messages: list[dict], system: str = "", model: str = ""):
    """Yields the reply's text as it arrives. Raises ProviderError."""
    model = model or provider.get("model", "")
    if not model:
        raise ProviderError(f"Choose a model for {provider.get('name', 'this provider')} in AI settings.")
    msgs = [{"role": m["role"], "content": m["content"]} for m in messages
            if m.get("role") in ("user", "assistant") and m.get("content")]
    try:
        if provider["kind"] == "anthropic":
            yield from _anthropic(provider, key, msgs, system, model)
        else:
            yield from _openai(provider, key, msgs, system, model)
    except ProviderError:
        raise
    except (urllib.error.URLError, OSError) as e:
        raise _explain(provider, e) from None


def _anthropic(provider, key, msgs, system, model):
    if not key:
        raise ProviderError(f"Add your {provider.get('name', 'Anthropic')} API key in AI settings.")
    body = {"model": model, "max_tokens": 64000, "stream": True, "messages": msgs}
    if system:
        body["system"] = system
    headers_extra = {}
    if model in FALLBACK_MODELS:
        body["fallbacks"] = "default"
        headers_extra["anthropic-beta"] = "server-side-fallback-2026-07-01"
    url = provider["url"].rstrip("/") + "/v1/messages"
    req = urllib.request.Request(url, data=json.dumps(body).encode(), method="POST",
                                 headers={**_headers(provider, key), **headers_extra})
    try:
        resp = urllib.request.urlopen(req, timeout=120)
    except (urllib.error.URLError, OSError) as e:
        raise _explain(provider, e) from None
    with resp:
        for event, data in _sse(resp):
            try:
                obj = json.loads(data)
            except ValueError:
                continue
            kind = obj.get("type", event)
            if kind == "content_block_delta" and obj.get("delta", {}).get("type") == "text_delta":
                yield obj["delta"].get("text", "")
            elif kind == "message_delta" and obj.get("delta", {}).get("stop_reason") == "refusal":
                raise ProviderError("The model declined to answer this.")
            elif kind == "error":
                raise ProviderError(f"{provider.get('name')}: {obj.get('error', {}).get('message', 'error')}")


def _openai(provider, key, msgs, system, model):
    if system:
        msgs = [{"role": "system", "content": system}] + msgs
    body = {"model": model, "stream": True, "messages": msgs}
    with _open(provider, key, "POST", "/chat/completions", body, timeout=300) as resp:
        for _event, data in _sse(resp):
            if data.strip() == "[DONE]":
                return
            try:
                obj = json.loads(data)
            except ValueError:
                continue
            if obj.get("error"):
                e = obj["error"]
                raise ProviderError(f"{provider.get('name')}: {e.get('message', e) if isinstance(e, dict) else e}")
            for choice in obj.get("choices") or []:
                text = (choice.get("delta") or {}).get("content")
                if text:
                    yield text
