#!/usr/bin/env python3
"""Store screenshots: raw gameplay stills (tools/showcase.gd, build/media) framed under a caption band.

Output: store/screenshots/*.jpg, 1920x1080 (16:9), ready for Google Play phone screenshots.
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "build/media")
DST = os.path.join(ROOT, "store/screenshots")
FONT = os.path.join(ROOT, "assets/fonts/LilitaOne-Regular.ttf")
W, H = 1920, 1080
TOP, BOTTOM = (11, 37, 69), (14, 104, 140)
CORAL = (255, 122, 89)

SHOTS = [
    ("v_07.png", "01_draw_routes.jpg", "Draw a route to the matching port"),
    ("v_19.png", "02_rush_hour.jpg", "Rush hour: keep every ship safe"),
    ("v_15.png", "03_calm_waters.jpg", "Slow the sea with Calm Waters"),
    ("l20_10.png", "04_unique_ships.jpg", "10 unique ships, from sailboats to submarines"),
    ("l30_10.png", "05_endless_levels.jpg", "Endless levels with new maps every time"),
    ("v_29.png", "06_harbor_clear.jpg", "Clear the harbor and earn 3 stars"),
]


def background() -> Image.Image:
    bg = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(bg)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=tuple(int(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return bg.convert("RGBA")


def compose(shot: Image.Image, text: str) -> Image.Image:
    canvas = background()
    d = ImageDraw.Draw(canvas)
    size = 86
    font = ImageFont.truetype(FONT, size)
    while d.textlength(text, font=font) > W - 200:
        size -= 4
        font = ImageFont.truetype(FONT, size)
    d.text((W / 2, 88), text, font=font, anchor="mm", fill="white")
    tw = d.textlength(text, font=font)
    d.rounded_rectangle((W / 2 - tw * 0.18, 140, W / 2 + tw * 0.18, 150), radius=5, fill=CORAL)

    fw, fh = 1552, 873
    frame = shot.convert("RGB").resize((fw, fh), Image.LANCZOS).convert("RGBA")
    x, y = (W - fw) // 2, 180
    mask = Image.new("L", (fw, fh), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, fw - 1, fh - 1), radius=30, fill=255)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x - 4, y + 10, x + fw + 4, y + fh + 18), radius=36, fill=(0, 10, 25, 150))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)))
    ImageDraw.Draw(canvas).rounded_rectangle((x - 7, y - 7, x + fw + 7, y + fh + 7), radius=36, fill="white")
    canvas.paste(frame, (x, y), mask)
    return canvas.convert("RGB")


def main():
    os.makedirs(DST, exist_ok=True)
    for f in os.listdir(DST):
        if f.endswith(".jpg"):
            os.remove(os.path.join(DST, f))
    for src, dst, text in SHOTS:
        path = os.path.join(SRC, src)
        if not os.path.exists(path):
            print("missing", src)
            continue
        compose(Image.open(path), text).save(os.path.join(DST, dst), quality=93)
        print("wrote", dst)


if __name__ == "__main__":
    main()
