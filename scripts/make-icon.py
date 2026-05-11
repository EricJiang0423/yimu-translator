#!/usr/bin/env python3
"""Generate 译幕's app icon + menubar template icon.

Design — "取景框 / 字幕": a viewfinder bracket frame (you draw a box over the
game text) wrapping two stacked subtitle bars. Pure geometry, black on near-white.
No gradients, no characters. ChatGPT-clean.
"""
import os
import subprocess
from PIL import Image, ImageDraw

PROJECT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RES = os.path.join(PROJECT, "Resources")

BG = (242, 241, 237, 255)     # warm near-white
INK = (17, 17, 17, 255)       # near-black
INK_T = (0, 0, 0, 255)        # pure black for template (OS tints it)


def rounded_rect(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def draw_mark(draw, S, ink, *, with_bars=True):
    """Draw the viewfinder + subtitle bars centered in an S×S canvas."""
    c = S / 2

    # ---- viewfinder corner brackets ----
    half = S * 0.300            # half-width of the implied frame square
    arm = S * 0.150             # length of each bracket arm
    w = S * 0.066               # stroke weight
    r = w / 2
    L, T, R, B = c - half, c - half, c + half, c + half

    def bracket(hx, hy):
        # hx, hy: -1 (left/top) or +1 (right/bottom)
        cx = R if hx > 0 else L
        cy = B if hy > 0 else T
        # horizontal arm
        x0, x1 = sorted((cx, cx + arm * (-1 if hx > 0 else 1)))
        rounded_rect(draw, (x0 - r, cy - r, x1 + r, cy + r), r, ink)
        # vertical arm
        y0, y1 = sorted((cy, cy + arm * (-1 if hy > 0 else 1)))
        rounded_rect(draw, (cx - r, y0 - r, cx + r, y1 + r), r, ink)

    for hx in (-1, 1):
        for hy in (-1, 1):
            bracket(hx, hy)

    # ---- subtitle bars ----
    if with_bars:
        bh = S * 0.060
        br = bh / 2
        gap = S * 0.052
        w1 = S * 0.300
        w2 = S * 0.190
        y_top = c - gap / 2 - bh
        y_bot = c + gap / 2
        rounded_rect(draw, (c - w1 / 2, y_top, c + w1 / 2, y_top + bh), br, ink)
        rounded_rect(draw, (c - w2 / 2, y_bot, c + w2 / 2, y_bot + bh), br, ink)


def make_app_icon(size=1024):
    """macOS Big Sur grid: 824pt squircle inside a 1024 canvas, corner r=185.4."""
    scale = size / 1024.0
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    pad = 100 * scale
    radius = 185.4 * scale
    rounded_rect(d, (pad, pad, size - pad, size - pad), radius, BG)

    # Render the mark on a transparent layer sized to the squircle, then paste.
    inner = int(size - 2 * pad)
    mark = Image.new("RGBA", (inner, inner), (0, 0, 0, 0))
    md = ImageDraw.Draw(mark)
    draw_mark(md, inner, INK)
    img.alpha_composite(mark, (int(pad), int(pad)))
    return img


def make_menubar(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # slight inset; brackets only — bars vanish at 16px
    inset = size * 0.06
    inner = int(size - 2 * inset)
    mark = Image.new("RGBA", (inner, inner), (0, 0, 0, 0))
    md = ImageDraw.Draw(mark)
    draw_mark(md, inner, INK_T, with_bars=(size >= 36))
    img.alpha_composite(mark, (int(inset), int(inset)))
    return img


def build_icns():
    base = make_app_icon(1024)
    iconset = os.path.join(PROJECT, ".build", "AppIcon.iconset")
    os.makedirs(iconset, exist_ok=True)
    specs = [
        (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
    ]
    for px, name in specs:
        # re-render small sizes from scratch for crisp edges instead of downscaling 1024
        img = make_app_icon(px) if px <= 256 else base.resize((px, px), Image.LANCZOS)
        img.save(os.path.join(iconset, name))
    out = os.path.join(RES, "AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", out], check=True)
    print("wrote", out)

    # preview
    base.resize((512, 512), Image.LANCZOS).save(os.path.join(PROJECT, ".build", "icon-preview.png"))

    make_menubar(16).save(os.path.join(RES, "menubar.png"))
    make_menubar(36).save(os.path.join(RES, "menubar@2x.png"))
    print("wrote menubar icons")


if __name__ == "__main__":
    build_icns()
