#!/usr/bin/env python3
"""Generate the card cost badge icons: assets/ui/mana_drop.png and
assets/ui/sand_timer.png (32x40 each).

Drawn at full 1px resolution (the originals were 2x2 chunky blocks) so the
badges read cleanly at hand-card size: a glossy teardrop for mana and a
wood-capped hourglass with flowing sand for tempo.
"""
from PIL import Image
import math
import os

W, H = 32, 40
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "ui")


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(len(a)))


def mana_drop():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()

    OUTLINE = (43, 37, 64, 255)
    TOP = (167, 182, 242)
    BOT = (72, 80, 168)
    GLINT = (242, 253, 255, 255)
    SHADE = (58, 63, 133)

    cx, cy, r = 15.5, 25.5, 10.0   # bowl circle
    tip = (15.5, 2.5)

    def inside(x, y):
        # Bowl.
        if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
            return True
        # Tangent wedge from the tip down to the bowl.
        if tip[1] <= y < cy:
            t = (y - tip[1]) / (cy - tip[1])
            hw = min(t * (r + 2.0) * 0.72, r)
            return abs(x - tip[0]) <= hw
        return False

    for y in range(H):
        for x in range(W):
            if not inside(x + 0.5, y + 0.5):
                continue
            t = max(0.0, min(1.0, (y - 3.0) / 32.0))
            col = lerp(TOP, BOT, t)
            # Lower-right inner shade.
            if (x - (cx + 3.2)) ** 2 + (y - (cy + 2.6)) ** 2 <= r * r and x > cx:
                col = lerp(col, SHADE, 0.65)
            # Rim light along the lower-left inner edge.
            d_edge = r - math.dist((x + 0.5, y + 0.5), (cx, cy))
            if 0.0 <= d_edge <= 1.6 and x < cx and y > cy:
                col = lerp(col, TOP, 0.55)
            px[x, y] = (col[0], col[1], col[2], 255)

    # Specular glint: elongated blob upper-left of the bowl plus a dot.
    for y in range(H):
        for x in range(W):
            if px[x, y][3] == 0:
                continue
            if ((x - 11.0) / 2.2) ** 2 + ((y - 19.5) / 4.2) ** 2 <= 1.0:
                px[x, y] = GLINT
    if px[13, 27][3]:
        px[13, 27] = GLINT

    # 1px outline around every filled pixel.
    base = img.copy().load()
    for y in range(H):
        for x in range(W):
            if base[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and base[nx, ny][3]:
                    px[x, y] = OUTLINE
                    break
    return img


def sand_timer():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()

    OUTLINE = (26, 21, 15, 255)
    WOOD = (138, 90, 40)
    WOOD_HI = (176, 123, 60)
    WOOD_LO = (94, 58, 22)
    GLASS_WALL = (127, 168, 201, 255)
    GLASS_BG = (39, 64, 79)
    GLASS_HI = (78, 116, 142)
    SAND = (224, 180, 94)
    SAND_HI = (240, 205, 132)
    SAND_LO = (185, 138, 56)

    # Wooden caps (rows 2-6 and 33-37), rounded ends.
    for rows, flip in (((2, 6), False), ((33, 37), True)):
        for y in range(rows[0], rows[1] + 1):
            for x in range(3, 29):
                if (x in (3, 28)) and y in (rows[0], rows[1]):
                    continue  # rounded corners
                i = (y - rows[0]) if not flip else (rows[1] - y)
                col = (WOOD_HI, WOOD, WOOD, WOOD_LO, WOOD_LO)[i]
                px[x, y] = (col[0], col[1], col[2], 255)

    # Glass bulbs: half-width per row, from the caps to a 2px neck.
    top0, neck0, neck1, bot1 = 7, 19, 21, 32
    def half_w(y):
        if y < neck0:
            t = (y - top0) / float(neck0 - top0)
            return 10.5 - 8.5 * (t ** 1.25)
        if y <= neck1:
            return 2.0
        t = (y - neck1) / float(bot1 - neck1)
        return 2.0 + 8.5 * (t ** 0.8)

    for y in range(top0, bot1 + 1):
        hw = half_w(y)
        x0 = int(round(15.5 - hw))
        x1 = int(round(15.5 + hw))
        for x in range(x0, x1 + 1):
            if x in (x0, x1):
                px[x, y] = GLASS_WALL
            else:
                px[x, y] = (GLASS_BG[0], GLASS_BG[1], GLASS_BG[2], 255)

    # Upper sand: fills the lower half of the top bulb, dished meniscus.
    for y in range(12, neck0 + 1):
        hw = half_w(y) - 1.0
        dish = 1 if y == 12 else 0
        x0 = int(round(15.5 - hw)) + dish
        x1 = int(round(15.5 + hw)) - dish
        for x in range(x0, x1 + 1):
            col = SAND_LO if y >= neck0 - 1 else SAND
            if y == 12:
                col = SAND_HI
            px[x, y] = (col[0], col[1], col[2], 255)

    # Falling stream through the neck.
    for y in range(neck0, 31):
        for x in (15, 16):
            px[x, y] = (SAND[0], SAND[1], SAND[2], 255)

    # Lower mound.
    for y in range(27, bot1 + 1):
        t = (y - 27) / float(bot1 - 27)
        hw = min(half_w(y) - 1.0, 1.5 + t * 8.0)
        x0 = int(round(15.5 - hw))
        x1 = int(round(15.5 + hw))
        for x in range(x0, x1 + 1):
            col = SAND_HI if y == 27 or (y == 28 and abs(x - 15.5) < 3) else SAND
            if y >= bot1 - 1:
                col = SAND_LO
            px[x, y] = (col[0], col[1], col[2], 255)

    # Glass sheen down the upper-left wall.
    for y in range(9, 13):
        hw = half_w(y)
        x = int(round(15.5 - hw)) + 1
        if px[x, y][:3] == GLASS_BG:
            px[x, y] = (GLASS_HI[0], GLASS_HI[1], GLASS_HI[2], 255)

    # 1px outline around the whole silhouette.
    base = img.copy().load()
    for y in range(H):
        for x in range(W):
            if base[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and base[nx, ny][3]:
                    px[x, y] = OUTLINE
                    break
    return img


def main():
    mana_drop().save(os.path.join(OUT_DIR, "mana_drop.png"))
    sand_timer().save(os.path.join(OUT_DIR, "sand_timer.png"))
    print("wrote mana_drop.png and sand_timer.png")


if __name__ == "__main__":
    main()
