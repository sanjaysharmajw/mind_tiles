"""Generates the launcher icon and splash images for Mind Tiles.

Draws a 2x2 cluster of yellow tiles with black star / heart / hexagon / X
symbols (matching the in-game vector symbols) on the night-purple brand
colour. Run:  python3 tool/generate_icons.py
then:        dart run flutter_launcher_icons && dart run flutter_native_splash:create
"""

import math
import os

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "images")
SS = 4  # supersampling factor

YELLOW_TOP = (255, 226, 112)
YELLOW = (255, 201, 40)
EDGE = (214, 146, 0)
INK = (28, 25, 23)
BG_TOP = (85, 48, 168)
BG_BOTTOM = (28, 16, 64)


def star(cx, cy, r_out, r_in, points=5):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = -math.pi / 2 + i * math.pi / points
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    return pts


def polygon(cx, cy, r, sides, rot):
    return [(cx + math.cos(rot + i * 2 * math.pi / sides) * r,
             cy + math.sin(rot + i * 2 * math.pi / sides) * r) for i in range(sides)]


def heart(x, y, s):
    # Sampled cubic heart in unit space, same control points as the game.
    segs = [
        ((0.5, 0.86), (0.5, 0.86), (0.07, 0.6), (0.07, 0.35)),
        ((0.07, 0.35), (0.07, 0.2), (0.18, 0.12), (0.3, 0.12)),
        ((0.3, 0.12), (0.4, 0.12), (0.47, 0.18), (0.5, 0.27)),
        ((0.5, 0.27), (0.53, 0.18), (0.6, 0.12), (0.7, 0.12)),
        ((0.7, 0.12), (0.82, 0.12), (0.93, 0.2), (0.93, 0.35)),
        ((0.93, 0.35), (0.93, 0.6), (0.5, 0.86), (0.5, 0.86)),
    ]
    pts = []
    for p0, p1, p2, p3 in segs:
        for i in range(24):
            t = i / 24
            mt = 1 - t
            px = mt**3 * p0[0] + 3 * mt * mt * t * p1[0] + 3 * mt * t * t * p2[0] + t**3 * p3[0]
            py = mt**3 * p0[1] + 3 * mt * mt * t * p1[1] + 3 * mt * t * t * p2[1] + t**3 * p3[1]
            pts.append((x + px * s, y + py * s))
    return pts


def draw_tile(img, x, y, size, symbol):
    d = ImageDraw.Draw(img)
    r = int(size * 0.2)
    edge = int(size * 0.07)
    # shadow
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [x, y + edge * 1.8, x + size, y + size + edge * 0.8], r, fill=(0, 0, 0, 110))
    shadow = shadow.filter(ImageFilter.GaussianBlur(size * 0.04))
    img.alpha_composite(shadow)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([x, y + edge, x + size, y + size], r, fill=EDGE)
    # gradient face
    face = Image.new("RGBA", (size, size - edge), (0, 0, 0, 0))
    grad = Image.new("RGBA", face.size)
    gd = ImageDraw.Draw(grad)
    for row in range(face.size[1]):
        t = row / max(1, face.size[1] - 1)
        c = tuple(int(YELLOW_TOP[i] * (1 - t) + YELLOW[i] * t) for i in range(3)) + (255,)
        gd.line([(0, row), (size, row)], fill=c)
    mask = Image.new("L", face.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size - 1, size - edge - 1], r, fill=255)
    face.paste(grad, (0, 0), mask)
    img.alpha_composite(face, (int(x), int(y)))
    d = ImageDraw.Draw(img)
    # symbol in an inset box
    inset = size * 0.2
    sx, sy, ss = x + inset, y + inset - edge / 2, size - inset * 2
    if symbol == "star":
        d.polygon(star(sx + ss * 0.5, sy + ss * 0.53, ss * 0.46, ss * 0.19), fill=INK)
    elif symbol == "heart":
        d.polygon(heart(sx, sy, ss), fill=INK)
    elif symbol == "hex":
        d.polygon(polygon(sx + ss / 2, sy + ss / 2, ss * 0.42, 6, math.pi / 6), fill=INK)
    elif symbol == "x":
        w = int(ss * 0.15)
        a, b = ss * 0.22, ss * 0.78
        for (x1, y1, x2, y2) in [(a, a, b, b), (b, a, a, b)]:
            d.line([(sx + x1, sy + y1), (sx + x2, sy + y2)], fill=INK, width=w)
            for (px, py) in [(x1, y1), (x2, y2)]:
                d.ellipse([sx + px - w / 2, sy + py - w / 2, sx + px + w / 2, sy + py + w / 2], fill=INK)


def tiles_cluster(img, cx, cy, tile):
    gap = tile * 0.12
    total = tile * 2 + gap
    x0, y0 = cx - total / 2, cy - total / 2
    for i, sym in enumerate(["star", "heart", "hex", "x"]):
        col, row = i % 2, i // 2
        draw_tile(img, int(x0 + col * (tile + gap)), int(y0 + row * (tile + gap)), int(tile), sym)


def background(size):
    img = Image.new("RGBA", (size, size))
    d = ImageDraw.Draw(img)
    for row in range(size):
        t = row / (size - 1)
        c = tuple(int(BG_TOP[i] * (1 - t) + BG_BOTTOM[i] * t) for i in range(3)) + (255,)
        d.line([(0, row), (size, row)], fill=c)
    return img


def save(img, name, final):
    img = img.resize((final, final), Image.LANCZOS)
    path = os.path.join(OUT, name)
    img.save(path)
    print("wrote", path)


def main():
    os.makedirs(OUT, exist_ok=True)
    big = 1024 * SS
    # Full icon (iOS + legacy Android).
    icon = background(big)
    tiles_cluster(icon, big / 2, big / 2, big * 0.33)
    save(icon, "app_icon.png", 1024)
    # Adaptive foreground: content inside the central 66% safe zone.
    fg = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    tiles_cluster(fg, big / 2, big / 2, big * 0.2)
    save(fg, "app_icon_foreground.png", 1024)
    # Splash logo (transparent).
    sp = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    tiles_cluster(sp, big / 2, big / 2, big * 0.3)
    save(sp, "splash_logo.png", 768)
    # Android 12 splash icon: must fit in a circle of 2/3 the canvas.
    sp12 = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    tiles_cluster(sp12, big / 2, big / 2, big * 0.2)
    save(sp12, "splash_logo_android12.png", 1152)
    notification_icons()


def notification_icons():
    """White-on-transparent status-bar icons (Android requires monochrome):
    a rounded tile with a star cut out of it."""
    res = os.path.join(os.path.dirname(__file__), "..", "android", "app", "src", "main", "res")
    for folder, px in [("mdpi", 24), ("hdpi", 36), ("xhdpi", 48), ("xxhdpi", 72), ("xxxhdpi", 96)]:
        big = px * 8
        img = Image.new("L", (big, big), 0)
        d = ImageDraw.Draw(img)
        pad = big * 0.08
        d.rounded_rectangle([pad, pad, big - pad, big - pad], big * 0.2, fill=255)
        d.polygon(star(big / 2, big * 0.53, big * 0.32, big * 0.13), fill=0)
        alpha = img.resize((px, px), Image.LANCZOS)
        out = Image.new("RGBA", (px, px), (255, 255, 255, 0))
        out.putalpha(alpha)
        path = os.path.join(res, f"drawable-{folder}", "ic_stat_notify.png")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        out.save(path)
        print("wrote", path)


if __name__ == "__main__":
    main()
