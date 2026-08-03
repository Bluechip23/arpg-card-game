#!/usr/bin/env python3
"""Cave spike billboards: stalagmite (floor, painted contact shadow) and
stalactite (ceiling, drawn tip-down). Neutral warm rock ramp, tinted by the
cave palette at runtime."""
import random
from PIL import Image

H = lambda s: tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
ROCK_HI = H("d9dec2")   # STEEL_5
ROCK = H("c6a891")      # SKIN_3
ROCK_SH = H("a78e51")   # LEATHER_6
ROCK_CORE = H("6b533e") # SKIN_4
SHADOW_A = (24, 24, 24, 97)
SHADOW_B = (24, 24, 24, 51)

W, HGT = 16, 24
rng = random.Random(5)


def spike(pointing_up: bool, shadow: bool) -> Image.Image:
    img = Image.new("RGBA", (W, HGT))
    p = img.load()
    base_y = HGT - 3 if pointing_up else 2
    tip_y = 1 if pointing_up else HGT - 2
    steps = abs(base_y - tip_y)
    for i in range(steps + 1):
        yy = base_y + (tip_y - base_y) * i // steps
        half = max(0, round(5.5 * (1.0 - i / steps)) )
        wob = rng.choice([-1, 0, 0, 1]) if half > 2 else 0
        for x in range(8 - half + wob, 8 + half + 1 + wob):
            if 0 <= x < W:
                if x < 8 - half // 2:
                    p[x, yy] = ROCK_HI       # lit left flank
                elif x > 8 + half // 2:
                    p[x, yy] = ROCK_SH       # shaded right flank
                else:
                    p[x, yy] = ROCK
        if 0 <= 8 + half + wob < W and half > 0:
            p[8 + half + wob, yy] = ROCK_CORE  # dark silhouette edge
    if shadow:
        for x in range(3, 13):
            p[x, HGT - 1] = SHADOW_B
        for x in range(4, 12):
            p[x, HGT - 2] = SHADOW_A
    return img


spike(True, True).save("assets/textures/props/stalagmite.png")
spike(False, False).save("assets/textures/props/stalactite.png")
print("stalagmite / stalactite", (W, HGT))
