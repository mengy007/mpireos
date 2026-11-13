# Mpire Desktop

MpireOS's own desktop environment. See [docs/architecture.md](../docs/architecture.md#desktop-mpire-desktop) for how it fits together and [docs/design-system.md](../docs/design-system.md) for the look.

## Status: first visual prototype

The components below are real QML, built on the shared style module, and render the desktop and login screen as designed. They are not yet a running shell: the next step is wiring them to live data (clock, network, battery, notifications, media players) and splitting the desktop scene into layer-shell surfaces.

| Path | Contents |
|---|---|
| `style/MpireOS/Style/` | Shared design tokens (`Theme`), icons, text styles, cards, backdrop. Used by the desktop, its apps, and Mpire Setup. |
| `shell/` | Top bar, dock, app icons, MpireOS mark, and the desktop scene |
| `shell/widgets/` | Today, A moment of focus, Now playing |
| `greeter/` | `mpire-greeter`, the login screen, packaged as an SDDM theme |
| `tools/preview.py` | Render any scene without a compositor |

## Previewing

```sh
pip install PySide6-Essentials
python3 desktop/tools/preview.py desktop
python3 desktop/tools/preview.py greeter --shot login.png --time 2026-11-12T10:53
```

| Desktop | Login screen |
|---|---|
| ![Desktop](docs/screenshots/desktop.png) | ![Login](docs/screenshots/login.png) |

The offscreen renderer used for these screenshots does not draw drop shadows; on real hardware cards, the dock, and the login card have soft violet shadows.
