#!/usr/bin/env python3
"""Regenerates the Android launcher icons (coral rounded square + white note).

Usage: python3 tool/make_icons.py
"""
from PIL import Image, ImageDraw

SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
CORAL = (217, 74, 43, 255)
SS = 8  # supersampling factor for smooth edges


def draw_icon(px: int) -> Image.Image:
    s = px * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * 0.22), fill=CORAL)
    white = (255, 255, 255, 255)
    # Note head, stem and flag, laid out on a 100-unit grid.
    u = s / 100.0
    d.ellipse([30 * u, 55 * u, 52 * u, 73 * u], fill=white)
    d.rectangle([48 * u, 24 * u, 54 * u, 65 * u], fill=white)
    d.polygon(
        [(54 * u, 24 * u), (72 * u, 32 * u), (72 * u, 44 * u), (54 * u, 36 * u)],
        fill=white,
    )
    return img.resize((px, px), Image.LANCZOS)


for name, px in SIZES.items():
    path = f"android/app/src/main/res/mipmap-{name}/ic_launcher.png"
    draw_icon(px).save(path)
    print("wrote", path)
