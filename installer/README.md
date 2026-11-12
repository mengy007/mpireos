# Mpire Setup

The MpireOS installer: fully graphical, friendly, and asking only what it must. The design is in [docs/architecture.md](../docs/architecture.md#installer).

## Status

This is the **user interface only**. It runs against `MockInstaller.qml`, which pretends to detect a disk and simulates an install. Nothing touches a disk yet. The privileged backend comes next.

## The flow

1. **Welcome:** language (preselected), then Install or Try it first
2. **Disk:** erase the disk or install alongside the existing OS, plus an encryption switch
3. **Account:** name and password; username and computer name are suggested from the name
4. **Review:** everything in plain language, with Edit links for detected settings
5. **Installing:** progress and a short tour
6. **Done:** restart

## Layout

| Path | Contents |
|---|---|
| `qml/Main.qml` | Window, navigation, and footer buttons |
| `qml/pages/` | One file per screen |
| `qml/MpireSetup/` | Theme tokens, shared components, and the mock backend |
| `src/main.cpp` | The native app (Qt 6) |
| `tools/preview.py` | Run the UI with PySide6, or save screenshots of every screen |

## Running

Quick preview (no compiler needed):

```sh
pip install PySide6-Essentials
python3 installer/tools/preview.py
```

Native build (Qt 6.5+):

```sh
cmake -S installer -B build/installer && cmake --build build/installer
./build/installer/mpire-setup --windowed
```

## Screenshots

Rendered from the current QML with `tools/preview.py --shots`.

| | |
|---|---|
| ![Welcome](docs/screenshots/1-welcome.png) | ![Disk](docs/screenshots/2-disk.png) |
| ![Account](docs/screenshots/3-account.png) | ![Review](docs/screenshots/4-review.png) |
| ![Installing](docs/screenshots/5-installing.png) | ![Done](docs/screenshots/6-done.png) |
