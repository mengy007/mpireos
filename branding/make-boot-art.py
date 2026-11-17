#!/usr/bin/env python3
"""Draws MpireOS's boot artwork from the design system (docs/design-system.md).

Writes:
  packages/mpire-branding/icons/<size>/apps/mpireos.png  the OS logo icon (+ scalable SVG)
  packages/mpire-branding/plymouth/mpireos/*.png   boot splash, spinner, password field
  packages/mpire-branding/grub/mpireos/*.png       GRUB theme background, logo, menu pieces
  packages/mpire-branding/grub/mpireos/*.pf2       GRUB fonts (Inter), if grub-mkfont exists
  iso/syslinux/splash.png                          BIOS boot menu background (640x480)

The outputs are committed, so building the ISO or packages never needs this script.
The logo itself comes from branding/logo/*.svg (branding/make-logo.py).
Run it again after changing the palette or the logo:
    python3 branding/make-boot-art.py
Needs Pillow, CairoSVG (pip install cairosvg) and the Inter font
(apt: fonts-inter, pacman: inter-font).
"""
import io
import math
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

REPO = Path(__file__).resolve().parent.parent
PLY = REPO / "packages/mpire-branding/plymouth/mpireos"
GRUB = REPO / "packages/mpire-branding/grub/mpireos"
SYSLINUX = REPO / "iso/syslinux"
ICONS = REPO / "packages/mpire-branding/icons"
LOGO = REPO / "branding/logo"

# Palette (desktop/style/MpireOS/Style/Theme.qml; accent follows the logo cyan).
BACKDROP = "#E4EDEF"
BACKDROP_HI = "#F4F8F9"
ACCENT = "#00B4C1"
ACCENT_STRONG = "#0096A3"   # selected boot entries: white text needs the deeper cyan
ACCENT_DEEP = "#054F5C"
INK = "#0B1F25"
TEXT2 = "#4F5D6B"
TEXT3 = "#8B95A3"
BORDER = "#E6EAEF"
SHADOW = "#0B3A44"

FONT_DIRS = ["/usr/share/fonts/opentype/inter", "/usr/share/fonts/inter", "/usr/share/fonts/OTF",
             "/usr/share/fonts/TTF"]


def font_file(style):
    for d in FONT_DIRS:
        for ext in ("otf", "ttf"):
            p = Path(d) / f"Inter-{style}.{ext}"
            if p.exists():
                return str(p)
    sys.exit(f"Inter {style} not found; install fonts-inter / inter-font")


def font(style, size):
    return ImageFont.truetype(font_file(style), size)


def rgb(hexcolor, alpha=255):
    h = hexcolor.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), alpha)


def mix(a, b, t):
    a, b = rgb(a), rgb(b)
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def save(img, path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    print("wrote", path.relative_to(REPO))


# ---------------------------------------------------------------- shapes

def render_svg(name, width=None, height=None):
    """Rasterizes one of the logo SVGs in branding/logo (drawn by make-logo.py)."""
    import cairosvg
    png = cairosvg.svg2png(url=str(LOGO / name), output_width=width, output_height=height)
    return Image.open(io.BytesIO(png)).convert("RGBA")


def soft_shadow(size, radius, blur, alpha, ss=1):
    """A blurred rounded-rect shadow image for an element of `size`."""
    w, h = size
    pad = blur * 3
    img = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle([pad, pad, pad + w, pad + h], radius=radius,
                                          fill=rgb(SHADOW, alpha))
    return img.filter(ImageFilter.GaussianBlur(blur)), pad


def backdrop(w, h):
    """desktop/style/MpireOS/Style/Backdrop.qml: pale teal-gray with broad, soft light sweeps."""
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    for x in range(w):
        d.line([(x, 0), (x, h)], fill=mix(BACKDROP_HI, BACKDROP, x / (w - 1)))
    # Rings drawn into one alpha mask (white light over the gradient), supersampled.
    ss = 2
    mask = Image.new("L", (w * ss, h * ss), 0)
    for x, y, s, bw, o in [(0.42, -0.55, 1.35, 0.10, 0.55), (0.60, -0.10, 1.15, 0.06, 0.45),
                           (-0.35, 0.45, 1.05, 0.08, 0.45), (0.25, 0.62, 0.90, 0.05, 0.30)]:
        size = w * s * ss
        x0, y0 = w * x * ss, h * y * ss
        ring = Image.new("L", mask.size, 0)
        ImageDraw.Draw(ring).ellipse([x0, y0, x0 + size, y0 + size], outline=round(255 * o * 0.6),
                                     width=round(size * bw))
        mask = ImageChops.lighter(mask, ring)
    mask = mask.resize((w, h), Image.LANCZOS).filter(ImageFilter.GaussianBlur(w / 400))
    layer = Image.new("RGBA", (w, h), (255, 255, 255, 255))
    layer.putalpha(mask)
    return Image.alpha_composite(img, layer)


def text_size(fnt, text):
    l, t, r, b = fnt.getbbox(text)
    return r - l, b - t, l, t


def lockup(height):
    """The official logo, mark beside the wordmark, for light backgrounds."""
    return render_svg("mpireos-logo-light.svg", height=height)


def spinner_frame(size, angle, stroke, ss=4):
    """A teal arc with a fading tail on a faint track, rotated to `angle` degrees."""
    s = size * ss
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    st = stroke * ss
    box = [st / 2, st / 2, s - st / 2, s - st / 2]
    d.ellipse(box, outline=rgb(ACCENT, 38), width=round(st))
    sweep, steps = 270, 90
    for i in range(steps):
        a0 = angle + sweep * i / steps
        a1 = angle + sweep * (i + 1.6) / steps
        t = (i + 1) / steps
        d.arc(box, a0, a1, fill=rgb(ACCENT, round(255 * t ** 1.6)), width=round(st))
    # Round cap at the head.
    head = math.radians(angle + sweep)
    r = (s - st) / 2
    cx, cy = s / 2 + r * math.cos(head), s / 2 + r * math.sin(head)
    d.ellipse([cx - st / 2, cy - st / 2, cx + st / 2, cy + st / 2], fill=rgb(ACCENT))
    return img.resize((size, size), Image.LANCZOS)


def rounded(size, radius, fill, outline=None, width=1, ss=4):
    w, h = size
    img = Image.new("RGBA", (w * ss, h * ss), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle([0, 0, w * ss - 1, h * ss - 1], radius=radius * ss, fill=fill,
                                          outline=outline, width=width * ss if outline else 0)
    return img.resize((w, h), Image.LANCZOS)


def lock_icon(size, color, ss=4):
    s = size * ss
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    w = s * 0.09
    d.rounded_rectangle([s * 0.2, s * 0.45, s * 0.8, s * 0.88], radius=s * 0.1, fill=rgb(color))
    d.arc([s * 0.32, s * 0.12, s * 0.68, s * 0.62], 180, 360, fill=rgb(color), width=round(w))
    d.line([(s * 0.32 + w / 2, s * 0.37), (s * 0.32 + w / 2, s * 0.47)], fill=rgb(color), width=round(w))
    d.line([(s * 0.68 - w / 2, s * 0.37), (s * 0.68 - w / 2, s * 0.47)], fill=rgb(color), width=round(w))
    return img.resize((size, size), Image.LANCZOS)


def nine_slice(img, prefix, outdir, corner):
    """Cuts img into GRUB's styled-box pieces: prefix + nw n ne w c e sw s se."""
    w, h = img.size
    c = corner
    boxes = {"nw": (0, 0, c, c), "n": (c, 0, w - c, c), "ne": (w - c, 0, w, c),
             "w": (0, c, c, h - c), "c": (c, c, w - c, h - c), "e": (w - c, c, w, h - c),
             "sw": (0, h - c, c, h), "s": (c, h - c, w - c, h), "se": (w - c, h - c, w, h)}
    for name, box in boxes.items():
        save(img.crop(box), outdir / f"{prefix}{name}.png")


# ---------------------------------------------------------------- outputs

def icons():
    """The OS logo icon (os-release LOGO=mpireos), for About pages. 24 px and
    below use the simplified icon, where windows and the badge would blur."""
    for size in (16, 24, 32, 48, 64, 128, 256):
        name = "mpireos-icon-small.svg" if size <= 24 else "mpireos-icon.svg"
        save(render_svg(name, size, size), ICONS / f"{size}x{size}/apps/mpireos.png")
    dest = ICONS / "scalable/apps/mpireos.svg"
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy(LOGO / "mpireos-icon.svg", dest)
    print("wrote", dest.relative_to(REPO))


def plymouth():
    save(backdrop(1920, 1080).convert("RGB"), PLY / "background.png")
    save(lockup(72), PLY / "logo.png")
    save(lockup(144), PLY / "logo@2x.png")
    for i in range(36):
        save(spinner_frame(36, i * 10 - 90, 3.5), PLY / f"spinner-{i:02d}.png")
        save(spinner_frame(72, i * 10 - 90, 7), PLY / f"spinner-{i:02d}@2x.png")
    # Password field: white pill with a hairline border and a soft shadow.
    for scale, suffix in ((1, ""), (2, "@2x")):
        fw, fh = 300 * scale, 46 * scale
        shadow, pad = soft_shadow((fw, fh), fh / 2, 6 * scale, 30)
        field = Image.new("RGBA", shadow.size, (0, 0, 0, 0))
        field.alpha_composite(shadow, (0, 3 * scale))
        field.alpha_composite(rounded((fw, fh), fh // 2, rgb("#FFFFFF"), rgb(ACCENT), 2 * scale), (pad, pad))
        save(field, PLY / f"field{suffix}.png")
        b = 10 * scale
        save(rounded((b, b), b // 2, rgb(INK)), PLY / f"bullet{suffix}.png")
        save(lock_icon(20 * scale, TEXT2), PLY / f"lock{suffix}.png")


def grub():
    save(backdrop(1920, 1080).convert("RGB"), GRUB / "background.png")
    save(lockup(50), GRUB / "logo.png")
    # Menu card: white, rounded 20px, hairline border. Corner pieces carry the radius.
    card = rounded((120, 120), 16, rgb("#FFFFFF", 235), rgb(BORDER), 1)
    nine_slice(card, "menu_", GRUB, 18)
    # Selected entry: a teal pill (accent -> slightly deeper).
    # Its corner pieces are drawn around the entry's own box, so keep them small.
    sel = rounded((40, 24), 7, rgb(ACCENT_STRONG))
    nine_slice(sel, "select_", GRUB, 6)
    # Scrollbar thumb and track.
    # Terminal box (for the GRUB command line and "Loading" messages).
    nine_slice(rounded((60, 60), 14, rgb("#FFFFFF", 245), rgb(BORDER), 1), "terminal_box_", GRUB, 16)

    mkfont = shutil.which("grub-mkfont")
    if not mkfont:
        print("grub-mkfont not found: GRUB fonts not regenerated")
        return
    for style, size in (("Regular", 14), ("Regular", 16), ("SemiBold", 16), ("Regular", 12)):
        out = GRUB / f"inter-{style.lower()}-{size}.pf2"
        subprocess.run([mkfont, "-s", str(size), "-n", "Inter" if style == "Regular" else f"Inter {style}", "-o", str(out),
                        # Latin, punctuation, arrows: enough for the menu and hints.
                        "-r", "0x20-0x7E,0xA0-0x17F,0x2010-0x2027,0x2190-0x2193,0x2318-0x2318,0x23CE-0x23CE",
                        font_file(style)], check=True, stderr=subprocess.DEVNULL)
        print("wrote", out.relative_to(REPO))


def syslinux():
    """640x480 background for vesamenu.c32 (the BIOS boot menu). The menu text is
    drawn by syslinux on top, in the card area (see iso/syslinux/mpireos_head.cfg)."""
    w, h = 640, 480
    img = backdrop(w, h)
    logo = lockup(36)
    img.alpha_composite(logo, ((w - logo.width) // 2, 64))
    # Card behind the menu: its seven entries are text rows 10.5-17.5 (16px each,
    # vesamenu centers the 30 rows) and columns 14-67 (8px each).
    x0, y0, x1, y1 = 14 * 8 - 24, 168 - 22, 68 * 8 + 16, 168 + 7 * 16 + 22
    shadow, pad = soft_shadow((x1 - x0, y1 - y0), 18, 10, 26)
    img.alpha_composite(shadow, (x0 - pad, y0 - pad + 6))
    img.alpha_composite(rounded((x1 - x0, y1 - y0), 18, rgb("#FFFFFF"), rgb(BORDER), 1), (x0, y0))
    save(img.convert("RGB"), SYSLINUX / "splash.png")


if __name__ == "__main__":
    icons()
    plymouth()
    grub()
    syslinux()
