#!/usr/bin/env python3
"""Builds the Ship Traffic Control Sim logo set (vector text from Lilita One, no system fonts).

Outputs (SVG + PNG): assets/logo/emblem, logo_stacked, logo_horizontal, icon.svg,
store/icon_512.png, assets/icons/icon_192.png, icon_fg_432.png, icon_bg_432.png.
Usage: python3 tools/make_logo.py   (needs fonttools, cairosvg)
"""
import os
import math
import cairosvg
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

ROOT = os.path.join(os.path.dirname(__file__), "..")
FONT = TTFont(os.path.join(ROOT, "assets/fonts/LilitaOne-Regular.ttf"))
GLYPHS = FONT.getGlyphSet()
CMAP = FONT.getBestCmap()
UPM = FONT["head"].unitsPerEm

NAVY, CORAL, CORAL_DARK, TEAL, SAND, SUN = "#0b2545", "#ff7a59", "#d9563a", "#2ec4b6", "#fff3d9", "#ffd23f"


def text_paths(text, size, tracking=0.02):
    """Returns (path data list with x offsets, total width) for text at font size."""
    s = size / UPM
    x = 0.0
    parts = []
    for ch in text:
        name = CMAP.get(ord(ch))
        adv = FONT["hmtx"][name][0] if name else UPM * 0.3
        if name and ch != " ":
            pen = SVGPathPen(GLYPHS)
            GLYPHS[name].draw(pen)
            parts.append((x, pen.getCommands()))
        x += (adv + tracking * UPM) * s
    return parts, x - tracking * UPM * s


def text_svg(text, cx, baseline, size, fill, stroke, stroke_w, shadow=None, tracking=0.02):
    parts, width = text_paths(text, size, tracking)
    s = size / UPM
    x0 = cx - width / 2
    out = []
    layers = []
    if shadow:
        layers.append((shadow[0], shadow[0], stroke_w, shadow[1]))
    layers.append((stroke, stroke, stroke_w, 0))
    layers.append((fill, "none", 0, 0))
    for fill_c, stroke_c, sw, dy in layers:
        g = []
        for dx, d in parts:
            g.append(f'<path transform="translate({x0 + dx:.2f} {baseline + dy:.2f}) scale({s:.5f} {-s:.5f})" d="{d}"/>')
        stroke_attr = f'stroke="{stroke_c}" stroke-width="{sw / s:.1f}" stroke-linejoin="round"' if sw else ""
        out.append(f'<g fill="{fill_c}" {stroke_attr}>{"".join(g)}</g>')
    return "\n".join(out), width


def emblem(cx, cy, r):
    """Compass-ring badge: a cargo ship follows a dashed course to a glowing port marker."""
    k = r / 250.0
    ticks = []
    for i in range(32):
        a = i * math.tau / 32
        big = i % 8 == 0
        r0, r1 = (r * 0.885, r * 0.975) if big else (r * 0.91, r * 0.955)
        ticks.append(f'<line x1="{cx + math.sin(a) * r0:.1f}" y1="{cy - math.cos(a) * r0:.1f}" '
                     f'x2="{cx + math.sin(a) * r1:.1f}" y2="{cy - math.cos(a) * r1:.1f}" '
                     f'stroke="{NAVY}" stroke-width="{(9 if big else 5) * k:.1f}" stroke-linecap="round"/>')
    inner = r * 0.86
    ship_x, ship_y = cx - 0.36 * r, cy + 0.2 * r

    def p(x, y):
        return f"{ship_x + x * k:.1f} {ship_y + y * k:.1f}"
    ship = f'''
    <g stroke="{NAVY}" stroke-width="{9 * k:.1f}" stroke-linejoin="round" stroke-linecap="round">
      <path d="M {p(-118, 0)} L {p(118, 0)} L {p(92, 58)} L {p(-92, 58)} Z" fill="{CORAL}"/>
      <path d="M {p(-110, 22)} L {p(112, 22)}" stroke="{CORAL_DARK}" stroke-width="{7 * k:.1f}"/>
      <rect x="{ship_x - 96 * k:.1f}" y="{ship_y - 44 * k:.1f}" width="{52 * k:.1f}" height="{44 * k:.1f}" rx="{5 * k:.1f}" fill="{TEAL}"/>
      <rect x="{ship_x - 44 * k:.1f}" y="{ship_y - 44 * k:.1f}" width="{52 * k:.1f}" height="{44 * k:.1f}" rx="{5 * k:.1f}" fill="{SUN}"/>
      <rect x="{ship_x - 70 * k:.1f}" y="{ship_y - 86 * k:.1f}" width="{52 * k:.1f}" height="{42 * k:.1f}" rx="{5 * k:.1f}" fill="{CORAL}"/>
      <rect x="{ship_x + 22 * k:.1f}" y="{ship_y - 92 * k:.1f}" width="{72 * k:.1f}" height="{92 * k:.1f}" rx="{8 * k:.1f}" fill="{SAND}"/>
      <rect x="{ship_x + 36 * k:.1f}" y="{ship_y - 140 * k:.1f}" width="{26 * k:.1f}" height="{48 * k:.1f}" rx="{5 * k:.1f}" fill="{SUN}"/>
      <path d="M {p(34, -68)} L {p(82, -68)}" stroke="{NAVY}" stroke-width="{11 * k:.1f}"/>
    </g>'''
    # Dashed course from the ship's bow arcing over to the port, arrowhead aimed into the port.
    sx, sy = cx + 0.06 * r, cy - 0.12 * r
    qx, qy = cx + 0.24 * r, cy - 0.66 * r
    ex, ey = cx + 0.45 * r, cy - 0.36 * r
    route = (f'<path d="M {sx:.1f} {sy:.1f} Q {qx:.1f} {qy:.1f} {ex:.1f} {ey:.1f}" fill="none" stroke="#ffffff" '
             f'stroke-width="{14 * k:.1f}" stroke-linecap="round" stroke-dasharray="{1 * k:.1f} {30 * k:.1f}"/>')
    tx, ty = cx + 0.5 * r, cy + 0.02 * r          # port marker centre
    ang = math.degrees(math.atan2(ty - ey, tx - ex))
    ax, ay = ex + (tx - ex) * 0.22, ey + (ty - ey) * 0.22
    arrow = (f'<path d="M {ax - 24 * k:.1f} {ay - 28 * k:.1f} L {ax + 24 * k:.1f} {ay:.1f} L {ax - 24 * k:.1f} {ay + 28 * k:.1f} Z" '
             f'fill="{CORAL}" stroke="#ffffff" stroke-width="{8 * k:.1f}" stroke-linejoin="round" transform="rotate({ang:.1f} {ax:.1f} {ay:.1f})"/>')
    mx, my, mr = cx + 0.5 * r, cy + 0.02 * r, 0.2 * r
    marker = f'''
    <circle cx="{mx:.1f}" cy="{my:.1f}" r="{mr * 1.35:.1f}" fill="{SUN}" opacity="0.35"/>
    <circle cx="{mx:.1f}" cy="{my:.1f}" r="{mr:.1f}" fill="{SUN}" stroke="{NAVY}" stroke-width="{8 * k:.1f}"/>
    <g fill="none" stroke="{NAVY}" stroke-width="{7 * k:.1f}" stroke-linecap="round">
      <circle cx="{mx:.1f}" cy="{my - mr * 0.5:.1f}" r="{mr * 0.16:.1f}"/>
      <path d="M {mx:.1f} {my - mr * 0.34:.1f} V {my + mr * 0.62:.1f} M {mx - mr * 0.34:.1f} {my - mr * 0.12:.1f} H {mx + mr * 0.34:.1f} M {mx - mr * 0.56:.1f} {my + mr * 0.2:.1f} Q {mx:.1f} {my + mr * 0.95:.1f} {mx + mr * 0.56:.1f} {my + mr * 0.2:.1f}"/>
    </g>'''
    waves = []
    for i, (yy, op) in enumerate([(0.42, 0.28), (0.62, 0.3)]):
        y = cy + yy * r
        amp = 0.05 * r
        seg = 0.22 * r
        d = f"M {cx - r:.1f} {y:.1f}"
        x = cx - r
        while x < cx + r:
            d += f" q {seg / 2:.1f} {-amp:.1f} {seg:.1f} 0"
            x += seg
        d += f" V {cy + r:.1f} H {cx - r:.1f} Z"
        waves.append(f'<path d="{d}" fill="{NAVY}" opacity="{op}"/>')
    return f'''
  <defs>
    <linearGradient id="sea" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#5fe3d4"/><stop offset="0.55" stop-color="#1aa7c9"/><stop offset="1" stop-color="#0a5f8a"/>
    </linearGradient>
    <clipPath id="disc"><circle cx="{cx}" cy="{cy}" r="{inner:.1f}"/></clipPath>
  </defs>
  <circle cx="{cx}" cy="{cy + 14 * k:.1f}" r="{r * 1.04:.1f}" fill="{NAVY}" opacity="0.35"/>
  <circle cx="{cx}" cy="{cy}" r="{r * 1.04:.1f}" fill="{NAVY}"/>
  <circle cx="{cx}" cy="{cy}" r="{r:.1f}" fill="{SAND}"/>
  {"".join(ticks)}
  <circle cx="{cx}" cy="{cy}" r="{inner + 8 * k:.1f}" fill="{NAVY}"/>
  <g clip-path="url(#disc)">
    <circle cx="{cx}" cy="{cy}" r="{inner:.1f}" fill="url(#sea)"/>
    <circle cx="{cx - 0.45 * r:.1f}" cy="{cy - 0.45 * r:.1f}" r="{0.5 * r:.1f}" fill="#ffffff" opacity="0.12"/>
    {"".join(waves)}
    {route}{arrow}{marker}{ship}
  </g>'''


def ribbon(cx, cy, w, h):
    t = h * 0.55
    return f'''
  <g stroke="{NAVY}" stroke-width="10" stroke-linejoin="round">
    <path d="M {cx - w / 2 - t:.1f} {cy - h * 0.2:.1f} h {t * 1.4:.1f} v {h:.1f} h {-t * 1.4:.1f} l {t * 0.5:.1f} {-h / 2:.1f} Z" fill="{CORAL_DARK}"/>
    <path d="M {cx + w / 2 + t:.1f} {cy - h * 0.2:.1f} h {-t * 1.4:.1f} v {h:.1f} h {t * 1.4:.1f} l {-t * 0.5:.1f} {-h / 2:.1f} Z" fill="{CORAL_DARK}"/>
    <path d="M {cx - w / 2:.1f} {cy - h / 2:.1f} Q {cx:.1f} {cy - h / 2 - 22:.1f} {cx + w / 2:.1f} {cy - h / 2:.1f} V {cy + h / 2:.1f} Q {cx:.1f} {cy + h / 2 - 22:.1f} {cx - w / 2:.1f} {cy + h / 2:.1f} Z" fill="{CORAL}"/>
  </g>'''


def wordmark(cx, top, scale=1.0):
    t1, w1 = text_svg("SHIP TRAFFIC", cx, top + 150 * scale, 190 * scale, "#ffffff", NAVY, 26 * scale, (NAVY, 14 * scale), 0.01)
    rib_cy = top + 258 * scale
    _, w2 = text_paths("CONTROL SIM", 112 * scale, 0.03)
    rib = ribbon(cx, rib_cy, w2 + 90 * scale, 128 * scale)
    t2, _ = text_svg("CONTROL SIM", cx, rib_cy + 40 * scale, 112 * scale, "#ffffff", NAVY, 18 * scale, None, 0.03)
    return t1 + rib + t2, max(w1, w2 + 200 * scale)


def studio(cx, cy):
    """Gamecept Studios mark: coral badge with a G monogram and a play notch, plus wordmark."""
    b = 120
    parts, gw = text_paths("G", 190)
    sc = 190 / UPM
    g = "".join(f'<path transform="translate({cx - gw / 2 + dx:.1f} {cy + 66:.1f}) scale({sc:.5f} {-sc:.5f})" d="{d}"/>' for dx, d in parts)
    badge = f'''
  <rect x="{cx - b + 6}" y="{cy - b + 14}" width="{2 * b}" height="{2 * b}" rx="56" fill="#000000" opacity="0.25"/>
  <rect x="{cx - b}" y="{cy - b}" width="{2 * b}" height="{2 * b}" rx="56" fill="{CORAL}" stroke="#ffffff" stroke-width="10"/>
  <g fill="#ffffff">{g}</g>
  <path d="M {cx + 70} {cy - 88} l 30 18 l -30 18 z" fill="{SUN}" stroke="{NAVY}" stroke-width="6" stroke-linejoin="round"/>'''
    w1, _ = text_svg("GAMECEPT", cx, cy + 290, 150, "#ffffff", NAVY, 0, None, 0.04)
    w2, _ = text_svg("STUDIOS", cx, cy + 380, 62, TEAL, NAVY, 0, None, 0.42)
    return badge + w1 + w2


def svg(w, h, body, bg=""):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{bg}{body}</svg>'


def save(name, content, png_width=None):
    path = os.path.join(ROOT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if name.endswith(".svg"):
        open(path, "w").write(content)
    else:
        cairosvg.svg2png(bytestring=content.encode(), write_to=path, output_width=png_width)
    print("wrote", name)


def main():
    em = emblem(300, 300, 250)
    save("assets/logo/emblem.svg", svg(600, 620, em))
    save("assets/logo/emblem.png", svg(600, 620, em), 600)

    words, _ = wordmark(800, 600)
    stacked = svg(1600, 1020, emblem(800, 300, 250) + words)
    save("assets/logo/logo_stacked.svg", stacked)
    save("assets/logo/logo_stacked.png", stacked, 1600)

    hw, _ = wordmark(1320, 80, 1.0)
    horizontal = svg(2000, 580, emblem(330, 290, 235) + hw)
    save("assets/logo/logo_horizontal.svg", horizontal)
    save("assets/logo/logo_horizontal.png", horizontal, 1600)

    navy_bg = (f'<defs><linearGradient id="nb" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0b2545"/>'
               f'<stop offset="1" stop-color="#0e4a6e"/></linearGradient></defs><rect width="1920" height="1080" fill="url(#nb)"/>')
    save("assets/logo/gamecept_splash.png", svg(1920, 1080, studio(960, 410), navy_bg), 1920)
    save("assets/logo/gamecept_boot.png", svg(1000, 760, studio(500, 250)), 1000)

    sea_bg = (f'<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#36d1c4"/>'
              f'<stop offset="1" stop-color="#0a5f8a"/></linearGradient></defs><rect width="512" height="512" fill="url(#bg)"/>')
    icon = svg(512, 512, emblem(256, 256, 214), sea_bg)
    save("icon.svg", icon)
    save("store/icon_512.png", icon, 512)
    save("assets/icons/icon_192.png", icon, 192)
    save("assets/icons/icon_fg_432.png", svg(432, 432, emblem(216, 216, 132)), 432)
    save("assets/icons/icon_bg_432.png", svg(432, 432, "", sea_bg.replace('width="512" height="512"', 'width="432" height="432"')), 432)


if __name__ == "__main__":
    main()
