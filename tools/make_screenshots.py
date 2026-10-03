#!/usr/bin/env python3
"""Adds marketing captions to raw gameplay stills from tools/showcase.gd (build/media -> store/screenshots)."""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "build/media")
DST = os.path.join(ROOT, "store/screenshots")
FONT = os.path.join(ROOT, "assets/fonts/LilitaOne-Regular.ttf")
NAVY = (11, 37, 69)

SHOTS = [
    ("v_07.png", "01_draw_routes.jpg", "Draw a route to the matching port"),
    ("v_11.png", "02_rush_hour.jpg", "Rush hour: keep every ship safe"),
    ("v_15.png", "03_calm_waters.jpg", "Slow the sea with Calm Waters"),
    ("l35_10.png", "04_ten_ships.jpg", "10 unique ships, from sailboats to submarines"),
    ("l25_10.png", "05_endless_levels.jpg", "Endless levels with new maps every time"),
    ("v_29.png", "06_harbor_clear.jpg", "Clear the harbor and earn 3 stars"),
]


def caption(img: Image.Image, text: str) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    band = Image.new("RGBA", (w, 220), (0, 0, 0, 0))
    d = ImageDraw.Draw(band)
    for y in range(220):
        d.line([(0, y), (w, y)], fill=(*NAVY, int(215 * (1 - y / 220) ** 1.3)))
    img.alpha_composite(band, (0, 0))
    d = ImageDraw.Draw(img)
    size = 92
    font = ImageFont.truetype(FONT, size)
    while d.textlength(text, font=font) > w - 160:
        size -= 4
        font = ImageFont.truetype(FONT, size)
    d.text((w / 2, 96), text, font=font, anchor="mm", fill="white", stroke_width=10, stroke_fill=NAVY)
    return img.convert("RGB")


def main():
    os.makedirs(DST, exist_ok=True)
    for src, dst, text in SHOTS:
        path = os.path.join(SRC, src)
        if not os.path.exists(path):
            print("missing", src)
            continue
        caption(Image.open(path), text).save(os.path.join(DST, dst), quality=92)
        print("wrote", dst)


if __name__ == "__main__":
    main()
