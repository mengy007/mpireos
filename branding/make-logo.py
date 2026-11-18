#!/usr/bin/env python3
"""Draws the official MpireOS logo as clean vector SVG.

The logo is a skyline "M": two towers with lit windows, a stepped bar chart
falling between them, and small windows below. The wordmark is "Mpire" in
white (or ink on light backgrounds) and "OS" in Mpire cyan. The geometry below
was traced from the official artwork Meng supplied (November 2026) and tidied
onto a regular grid; the wordmark is Inter Black, converted to outlines so the
SVGs need no font.

Writes branding/logo/*.svg (see branding/logo/README.md) and copies them to the
components that ship them (COPIES below). The outputs are
committed; run this again only after changing the logo:
    python3 branding/make-logo.py
Needs fontTools (pip install fonttools) and Inter (apt: fonts-inter, pacman: inter-font).
"""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "branding/logo"

# Official colors, sampled from the supplied artwork.
CYAN = "#00CBD7"
NAVY = "#062331"
PALE = "#E2F6FD"
WHITE = "#FFFFFF"
INK = "#0B1F25"   # design-system text color, for "Mpire" on light backgrounds

# ---------------------------------------------------------------- the mark
# Units: the mark is 354 x 354.
MARK_W, MARK_H = 354, 354


def _rect(x, y, w, h):
    return f"M{x:g} {y:g}h{w:g}v{h:g}h{-w:g}z"


def _poly(pts):
    return "M" + "L".join(f"{x:g} {y:g}" for x, y in pts) + "z"


ROWS = [75, 119.5, 164, 208.5, 253, 297.5]   # tower window rows (each 20 x 25)


def silhouette():
    """Everything solid, before the windows are cut out."""
    d = []
    # Left tower: stepped crown.
    d.append(_poly([(32, 0), (65, 0), (65, 25), (79, 25), (79, 50), (93, 50), (93, 354),
                    (0, 354), (0, 50), (17, 50), (17, 25), (32, 25)]))
    # Right tower: slanted crown.
    d.append(_poly([(276, 39), (347, 11), (347, 59), (353, 59), (353, 354), (260, 354),
                    (260, 59), (276, 59)]))

    # Bar chart falling between the towers: three bars on a sloped base.
    def base(x):                 # bottom edge
        return 245.5 - 0.3765 * (x - 101)

    def notch(x):                # floor of the gaps between bars
        return base(x) - 13

    d.append(_poly([(101, 101), (141, 101), (141, notch(141)), (152, notch(152)), (152, 137),
                    (194, 137), (194, notch(194)), (205, notch(205)), (205, 107), (217, 107),
                    (217, 90), (250, 90), (250, base(250)), (101, base(101))]))
    return "".join(d)


def street():
    d = []
    for x, ys in ((124, (274, 312)), (202, (235, 274, 312))):
        for y in ys:
            d.append(_rect(x, y, 26, 25))
    return "".join(d)


def tower_windows():
    return "".join(_rect(x, y, 20, 25) for y in ROWS for x in (18, 54, 278, 314))


def mark_paths(color, window_fill=None, small=False):
    """The mark as SVG elements: towers with window holes, the chart, street blocks.
    `small` is the version for 24 px and below, where windows would only blur:
    the solid skyline alone."""
    if small:
        return f'<path fill="{color}" d="{silhouette()}"/>'
    out = [f'<path fill="{color}" fill-rule="evenodd" d="{silhouette()}{tower_windows()}"/>',
           f'<path fill="{color}" d="{street()}"/>']
    if window_fill:
        out.append(f'<path fill="{window_fill}" d="{tower_windows()}"/>')
    return "\n  ".join(out)


# ---------------------------------------------------------------- type

def _font_path(style):
    for d in ("/usr/share/fonts/opentype/inter", "/usr/share/fonts/inter", "/usr/share/fonts/OTF",
              "/usr/share/fonts/TTF"):
        for ext in ("otf", "ttf"):
            p = Path(d) / f"Inter-{style}.{ext}"
            if p.exists():
                return p
    sys.exit(f"Inter {style} not found; install fonts-inter / inter-font")


_FONT = None


def text_path(text, x, baseline, cap_height, tracking=-0.02):
    """Outlines `text` in Inter Black. Returns (svg path data, advance width)."""
    global _FONT
    from fontTools.pens.svgPathPen import SVGPathPen
    from fontTools.pens.transformPen import TransformPen
    from fontTools.ttLib import TTFont
    if _FONT is None:
        _FONT = TTFont(_font_path("Black"))
    f = _FONT
    upm = f["head"].unitsPerEm
    scale = cap_height / f["OS/2"].sCapHeight
    cmap = f.getBestCmap()
    gs = f.getGlyphSet()
    pen = SVGPathPen(gs, ntos=lambda v: f"{round(v, 2):g}")
    cx = x
    for ch in text:
        name = cmap[ord(ch)]
        tp = TransformPen(pen, (scale, 0, 0, -scale, cx, baseline))
        gs[name].draw(tp)
        cx += (gs[name].width + tracking * upm) * scale
    return pen.getCommands(), cx - x - tracking * upm * scale


# ---------------------------------------------------------------- files

def svg(w, h, body, title):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:g} {h:g}" '
            f'width="{w:g}" height="{h:g}">\n  <title>{title}</title>\n  {body}\n</svg>\n')


def write(name, text):
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / name).write_text(text)
    print("wrote", (OUT / name).relative_to(REPO))


def lockup(word_color, mark_color=CYAN, os_color=CYAN, bg=None, pad=0):
    """Mark beside the wordmark, as in the official artwork."""
    cap = 171
    baseline = 302
    gap = 51
    mpire, w1 = text_path("Mpire", MARK_W + gap, baseline, cap)
    os_, w2 = text_path("OS", MARK_W + gap + w1 + cap * 0.02, baseline, cap)
    w = MARK_W + gap + w1 + cap * 0.02 + w2
    W, H = w + pad * 2, MARK_H + pad * 2
    body = []
    if bg:
        body.append(f'<rect width="{W:g}" height="{H:g}" fill="{bg}"/>')
    body.append(f'<g transform="translate({pad:g} {pad:g})">')
    body.append("  " + mark_paths(mark_color).replace("\n  ", "\n    "))
    body.append(f'  <path fill="{word_color}" d="{mpire}"/>')
    body.append(f'  <path fill="{os_color}" d="{os_}"/>')
    body.append("</g>")
    return svg(round(W, 1), H, "\n  ".join(body), "MpireOS")


def badge(color, knockout):
    """The small "OS" that sits on the right tower's foot in the icon variants."""
    d, w = text_path("OS", 296, 354, 78, tracking=0)
    halo = (f'<path fill="{knockout}" stroke="{knockout}" stroke-width="16" '
            f'stroke-linejoin="round" d="{d}"/>')
    return halo + f'\n  <path fill="{color}" d="{d}"/>', 300 + w


def icon(bg, mark_color, os_color, window_fill=None, radius=0, size=512, small=False):
    """Square app/distro icon: the mark with the "OS" badge, centered on a tile.
    The `small` icon (24 px and below) drops the badge and windows."""
    b, right = badge(os_color, bg)
    if small:
        b, right = "", MARK_W
    content_w, content_h = right + 8, MARK_H + 6
    s = size * 0.74 / max(content_w, content_h)
    tx = (size - content_w * s) / 2
    ty = (size - content_h * s) / 2
    body = [f'<rect width="{size}" height="{size}" rx="{radius:g}" fill="{bg}"/>',
            f'<g transform="translate({tx:.2f} {ty:.2f}) scale({s:.4f})">',
            "  " + mark_paths(mark_color, window_fill, small).replace("\n  ", "\n    "),
            "  " + b.replace("\n  ", "\n    "),
            "</g>"]
    return svg(size, size, "\n  ".join(body), "MpireOS")


def mark_only(color, window_fill=None, small=False):
    return svg(MARK_W, MARK_H, mark_paths(color, window_fill, small), "MpireOS")


# Copies that ship with each component, so none needs this directory at runtime.
COPIES = {
    "packages/mpire-branding/logo": None,   # all of them
    "desktop/style/MpireOS/Style/images": ["mpireos-mark.svg", "mpireos-mark-small.svg"],
    "installer/qml/MpireSetup/images": ["mpireos-mark.svg", "mpireos-mark-small.svg",
                                        "mpireos-logo-light.svg"],
    "desktop/kde/lookandfeel/contents/splash/images": ["mpireos-logo-light.svg"],
}


def copy_out():
    import shutil
    for dest, names in COPIES.items():
        d = REPO / dest
        d.mkdir(parents=True, exist_ok=True)
        for f in sorted(OUT.glob("*.svg")):
            if names is None or f.name in names:
                shutil.copy(f, d / f.name)
        print("copied to", dest)


def main():
    # The mark alone.
    write("mpireos-mark.svg", mark_only(CYAN))
    write("mpireos-mark-white.svg", mark_only(WHITE))
    write("mpireos-mark-navy.svg", mark_only(NAVY))
    write("mpireos-mark-small.svg", mark_only(CYAN, small=True))
    # Full logo: for dark backgrounds (transparent), light backgrounds, and the
    # official navy banner.
    write("mpireos-logo.svg", lockup(WHITE))
    write("mpireos-logo-light.svg", lockup(INK))
    write("mpireos-logo-banner.svg", lockup(WHITE, bg=NAVY, pad=110))
    # Icon tiles, as in the official artwork: light, cyan and dark.
    write("mpireos-icon-light.svg", icon(PALE, CYAN, CYAN, window_fill=NAVY))
    write("mpireos-icon-cyan.svg", icon(CYAN, WHITE, WHITE))
    write("mpireos-icon-dark.svg", icon(NAVY, WHITE, WHITE))
    # The OS / app icon: the dark tile with a cyan mark, rounded like other app icons.
    write("mpireos-icon.svg", icon(NAVY, CYAN, CYAN, radius=112))
    write("mpireos-icon-small.svg", icon(NAVY, CYAN, CYAN, radius=112, small=True))
    copy_out()


if __name__ == "__main__":
    main()
