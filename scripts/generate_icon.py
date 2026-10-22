#!/usr/bin/env python3
"""Draws Cozy Shopkeeper's original app icon (1024 × 1024) with Pillow.

    python3 scripts/generate_icon.py App/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
"""
import sys

from PIL import Image, ImageDraw, ImageFilter

S = 1024
SS = 2  # supersampling
W = S * SS


def hexc(h, a=255):
    return ((h >> 16) & 255, (h >> 8) & 255, h & 255, a)


def main(path):
    img = Image.new("RGBA", (W, W), hexc(0xF6E3C3))
    d = ImageDraw.Draw(img)

    # Warm sky gradient
    for y in range(W):
        t = y / W
        top, bottom = (0xA9, 0xCF, 0xE0), (0xFB, 0xE6, 0xC4)
        c = tuple(int(top[i] + (bottom[i] - top[i]) * min(1, t * 1.4)) for i in range(3))
        d.line([(0, y), (W, y)], fill=c + (255,))

    def r(x0, y0, x1, y1, fill, radius=0, outline=None, width=0):
        box = [x0 * SS, y0 * SS, x1 * SS, y1 * SS]
        d.rounded_rectangle(box, radius=radius * SS, fill=fill, outline=outline, width=width * SS)

    def e(x0, y0, x1, y1, fill):
        d.ellipse([x0 * SS, y0 * SS, x1 * SS, y1 * SS], fill=fill)

    # Ground
    r(0, 860, 1024, 1024, hexc(0xC9965F))
    r(0, 860, 1024, 878, hexc(0xA97A48))

    # Shadow
    shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.ellipse([150 * SS, 830 * SS, 874 * SS, 900 * SS], fill=(60, 40, 20, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(18 * SS))
    img.alpha_composite(shadow)
    d = ImageDraw.Draw(img)

    # Shop body
    r(190, 360, 834, 870, hexc(0x9CB38A), 26, hexc(0x5F7D4F), 10)
    # Sign board
    r(300, 238, 724, 340, hexc(0x8A6142), 22, hexc(0x5A3E2B), 8)
    # Coin on the sign
    e(477, 254, 547, 324, hexc(0xE9B949))
    e(490, 267, 534, 311, hexc(0xF7D77C))
    # Awning stripes with scallops
    stripes = 8
    x0, x1, top, bottom = 160, 864, 350, 470
    sw = (x1 - x0) / stripes
    for i in range(stripes):
        color = hexc(0xC96F4A) if i % 2 == 0 else hexc(0xFFF6E5)
        d.polygon([((x0 + i * sw) * SS, top * SS), ((x0 + (i + 1) * sw) * SS, top * SS),
                   ((x0 + (i + 1) * sw) * SS, bottom * SS), ((x0 + i * sw) * SS, bottom * SS)], fill=color)
        e(x0 + i * sw, bottom - sw / 2, x0 + (i + 1) * sw, bottom + sw / 2, color)
    r(150, 336, 874, 362, hexc(0xA4532F), 10)

    # Window with warm glow
    r(250, 540, 520, 790, hexc(0x8A6142), 24)
    r(268, 558, 502, 772, hexc(0xFFE3A3), 18)
    glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([260 * SS, 560 * SS, 510 * SS, 780 * SS], fill=(255, 220, 140, 120))
    glow = glow.filter(ImageFilter.GaussianBlur(20 * SS))
    img.alpha_composite(glow)
    d = ImageDraw.Draw(img)
    r(380, 558, 390, 772, hexc(0x8A6142))
    r(268, 660, 502, 670, hexc(0x8A6142))
    # Little goods in the window: a jar and a bun
    r(300, 690, 350, 760, hexc(0x5E9C9A), 10)
    r(296, 676, 354, 694, hexc(0x3F7372), 6)
    e(410, 700, 480, 760, hexc(0xE3A857))
    e(418, 700, 472, 730, hexc(0xF6D58E))
    # Flower box
    r(240, 790, 530, 822, hexc(0xC96F4A), 8)
    for i, cx in enumerate(range(270, 520, 50)):
        petal = hexc(0xFFFFFF) if i % 2 == 0 else hexc(0xF4C7D3)
        for dx, dy in [(-14, 0), (14, 0), (0, -14), (0, 14)]:
            e(cx + dx - 12, 780 + dy - 12, cx + dx + 12, 780 + dy + 12, petal)
        e(cx - 10, 770, cx + 10, 790, hexc(0xF2D27C))

    # Door
    r(590, 540, 770, 860, hexc(0x5E9C9A), 70, hexc(0x3F7372), 10)
    r(620, 590, 740, 700, hexc(0xFFE3A3), 50)
    e(728, 700, 752, 724, hexc(0xD4A84B))

    # Lantern beside the door
    r(782, 520, 812, 528, hexc(0x5A3E2B))
    r(786, 528, 808, 580, hexc(0xFFE9A8), 8, hexc(0xD4A84B), 4)

    out = img.resize((S, S), Image.LANCZOS).convert("RGB")
    out.save(path, "PNG")
    print("Icon written to", path)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "AppIcon.png")
