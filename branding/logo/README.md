# The MpireOS logo

The official MpireOS logo: a skyline "M" (two towers with lit windows, a stepped bar chart falling between them, and small windows below) beside the "MpireOS" wordmark.

All files here are vector SVG, drawn by [`branding/make-logo.py`](../make-logo.py) from the official artwork. Edit the script, not the SVGs, and run it again:

```sh
pip install fonttools
python3 branding/make-logo.py        # writes these files and the copies the components ship
python3 branding/make-boot-art.py    # re-renders the boot screens and PNG icons from them
```

## Files

| File | Use |
|---|---|
| `mpireos-logo.svg` | Full logo for dark backgrounds: white "Mpire", cyan "OS" (transparent) |
| `mpireos-logo-light.svg` | Full logo for light backgrounds: ink "Mpire", cyan "OS" (transparent) |
| `mpireos-logo-banner.svg` | Full logo on the official navy, with padding: social cards, slides, the website header |
| `mpireos-mark.svg` | The mark alone, cyan |
| `mpireos-mark-white.svg`, `mpireos-mark-navy.svg` | The mark alone, one color, for photos and colored backgrounds |
| `mpireos-mark-small.svg` | The mark for 24 px and below: the skyline without windows |
| `mpireos-icon.svg` | The OS icon (`mpireos` in the icon theme, os-release `LOGO`): cyan mark and "OS" badge on a rounded navy tile |
| `mpireos-icon-small.svg` | The OS icon for 24 px and below |
| `mpireos-icon-light.svg`, `mpireos-icon-cyan.svg`, `mpireos-icon-dark.svg` | The three square icon tiles from the official artwork: avatars, favicons, store listings |

## Colors

| | Hex |
|---|---|
| Cyan (mark, "OS") | `#00CBD7` |
| Navy (dark background) | `#062331` |
| Pale (light icon tile) | `#E2F6FD` |
| Ink ("Mpire" on light backgrounds) | `#0B1F25` |

The wordmark is set in Inter Black, converted to outlines, so the files need no font.

## Use

- Keep clear space around the logo of at least the width of one tower window column (about a tenth of the mark's height).
- Don't recolor the mark outside the variants above, stretch it, add effects, or set "MpireOS" in another font next to it.
- Below 24 px, use the `-small` files.

## Where it ships

- `mpire-branding` package: every SVG here in `/usr/share/mpireos/logo/`, the OS icon in the hicolor theme (PNG sizes and scalable), and the Plymouth, GRUB and BIOS boot menu artwork.
- `desktop/style/MpireOS/Style/images/`: the mark for `Mark` (top bar, login screen).
- `installer/qml/MpireSetup/images/`: the mark and light logo for Mpire Setup.
