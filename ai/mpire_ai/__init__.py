"""mpire-ai: MpireOS's built-in AI layer.

One place on the system that knows which AI the person uses (a cloud service,
a model running on this computer, or one elsewhere on their network), keeps
its API key safe, and talks to it. Mpire Desktop's assistant and search use
it through `mpire-ai chat --json`; other apps can use it through the
OpenAI-compatible gateway (`mpire-ai serve`). See docs/ai.md.

Standard library only, so it works on any MpireOS install.
"""

__version__ = "0.1.0"
