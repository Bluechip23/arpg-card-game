#!/usr/bin/env python3
"""Build-time palette enforcement (Phase 3 of the style restructure).

Rewrites OUR generated color assets so every opaque pixel is an exact member
of the master palette (resources/palette/master_palette.gpl), matching in a
perceptual (CIE-Lab) space rather than raw RGB. Purchased reference packs are
never touched. Grayscale tile textures (assets/textures/tile_*.png) are
value-quantized to <= 8 gray steps instead (their hue comes from runtime
palette tints, so chroma-matching them would be wrong).

Usage:  python3 tools/conform_palette.py [--check]
  --check  report only; do not rewrite files.
"""
import sys, glob, math
from PIL import Image

PALETTE_GPL = "resources/palette/master_palette.gpl"
COLOR_TARGETS = [
    "assets/ui/*.png",
    "assets/items/mythic/*.png",
    "assets/sprites/generated/monsters/*.png",
    "assets/textures/tile_*.png",
    "assets/textures/props/*.png",
]
# tile_fog matches the (off-palette) WorldEnvironment backdrop color with
# sub-step dither shades; conforming it would collapse the dither.
EXCLUDE = ["assets/textures/tile_fog.png"]
GRAY_TARGETS = []
GRAY_STEPS = 8


def load_palette():
    cols = []
    for line in open(PALETTE_GPL):
        parts = line.split()
        if len(parts) >= 3 and parts[0].isdigit():
            cols.append(tuple(int(v) for v in parts[:3]))
    return cols


def rgb_to_lab(c):
    def f(t):
        return t ** (1 / 3) if t > 0.008856 else 7.787 * t + 16 / 116
    r, g, b = [v / 255.0 for v in c]
    r = ((r + 0.055) / 1.055) ** 2.4 if r > 0.04045 else r / 12.92
    g = ((g + 0.055) / 1.055) ** 2.4 if g > 0.04045 else g / 12.92
    b = ((b + 0.055) / 1.055) ** 2.4 if b > 0.04045 else b / 12.92
    x = (r * 0.4124 + g * 0.3576 + b * 0.1805) / 0.95047
    y = r * 0.2126 + g * 0.7152 + b * 0.0722
    z = (r * 0.0193 + g * 0.1192 + b * 0.9505) / 1.08883
    fx, fy, fz = f(x), f(y), f(z)
    return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))


def conform_color(path, pal_rgb, pal_lab, check):
    im = Image.open(path).convert("RGBA")
    px = im.load()
    before, after = set(), set()
    cache = {}
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            before.add((r, g, b))
            key = (r, g, b)
            if key not in cache:
                lab = rgb_to_lab(key)
                best, bd = 0, 1e18
                for i, pl in enumerate(pal_lab):
                    d = (lab[0] - pl[0]) ** 2 + (lab[1] - pl[1]) ** 2 + (lab[2] - pl[2]) ** 2
                    if d < bd:
                        bd, best = d, i
                cache[key] = pal_rgb[best]
            nr, ng, nb = cache[key]
            after.add((nr, ng, nb))
            if not check:
                px[x, y] = (nr, ng, nb, a)
    if not check:
        im.save(path)
    return len(before), len(after)


def conform_gray(path, check):
    im = Image.open(path).convert("RGBA")
    px = im.load()
    before, after = set(), set()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            before.add((r, g, b))
            v = round((r + g + b) / 3.0)
            q = min(255, round(v / (255 / (GRAY_STEPS - 1))) * round(255 / (GRAY_STEPS - 1)))
            after.add((q, q, q))
            if not check:
                px[x, y] = (q, q, q, a)
    if not check:
        im.save(path)
    return len(before), len(after)


def main():
    check = "--check" in sys.argv
    pal = load_palette()
    pal_lab = [rgb_to_lab(c) for c in pal]
    print(f"master palette: {len(pal)} colors | mode: {'CHECK' if check else 'REWRITE'}")
    rows = []
    for pattern in COLOR_TARGETS:
        for p in sorted(glob.glob(pattern)):
            if p in EXCLUDE:
                continue
            b, a = conform_color(p, pal, pal_lab, check)
            rows.append((p, b, a, "palette"))
    for pattern in GRAY_TARGETS:
        for p in sorted(glob.glob(pattern)):
            b, a = conform_gray(p, check)
            rows.append((p, b, a, f"gray<={GRAY_STEPS}"))
    print(f"{'file':60s} {'before':>6s} {'after':>6s}  rule")
    bad = 0
    for p, b, a, rule in rows:
        limit = 16 if rule == "palette" else GRAY_STEPS
        flag = "" if a <= limit else "  OVER-BUDGET"
        if flag:
            bad += 1
        print(f"{p:60s} {b:6d} {a:6d}  {rule}{flag}")
    print(f"{len(rows)} files, {bad} over budget")
    return 1 if (check and bad) else 0


if __name__ == "__main__":
    sys.exit(main())
