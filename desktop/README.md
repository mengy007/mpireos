# Mpire Desktop

MpireOS's own desktop environment. See [docs/architecture.md](../docs/architecture.md#desktop-mpire-desktop) for how it fits together and [docs/design-system.md](../docs/design-system.md) for the look.

## Status: running on the ISO

Mpire Desktop is what you see after booting MpireOS:

- **`mpire-shell`** (`src/`) draws the desktop, the top bar, and the dock as Wayland layer-shell surfaces. For now it runs inside the Plasma session in place of `plasmashell` (a systemd drop-in, `session/mpire-shell.conf`), so KWin, KRunner, and the Plasma apps keep working underneath.
- **The login screen** (`greeter/`) is the SDDM theme `mpireos`, selected by `session/30-mpire-theme.conf`.
- Both are in the `mpire-desktop` package (`packages/mpire-desktop`), which also installs the shared `MpireOS.Style` QML module.

What works: the clock and date, greeting, Today calendar, focus timer, battery level (hidden on desktops), and launching from the dock (apps, Files, Settings), the top bar (search, network, settings), and "Find your flow" (KRunner, also Alt+Space).

Not yet: notifications, a window list and running-app indicators in the dock, the active app's name and menus in the top bar, media controls (MPRIS), multiple monitors (the shell uses the primary screen), and wallpaper choice.

| Path | Contents |
|---|---|
| `style/MpireOS/Style/` | Shared design tokens (`Theme`), icons, text styles, cards, backdrop, the MpireOS mark |
| `shell/` | Top bar, dock, app icons, widgets, and `Desktop.qml` (the whole desktop as one scene, for previews) |
| `shell/surfaces/` | What `mpire-shell` actually shows: background, top bar, dock |
| `src/` | `mpire-shell` (C++, Qt 6, LayerShellQt) |
| `greeter/` | The login screen, as an SDDM theme |
| `session/` | How the shell and login screen are switched on |
| `tools/preview.py` | Render any scene without a compositor |

## Previewing

```sh
pip install PySide6-Essentials
python3 desktop/tools/preview.py desktop
python3 desktop/tools/preview.py greeter --fake-sddm --shot login.png --time 2026-11-12T10:53
python3 desktop/tools/preview.py shell-dock --size 600x72
```

| Desktop | Login screen |
|---|---|
| ![Desktop](docs/screenshots/desktop.png) | ![Login](docs/screenshots/login.png) |

The offscreen renderer used for these screenshots does not draw drop shadows; on real hardware cards, the dock, and the login card have soft teal-tinted shadows.
