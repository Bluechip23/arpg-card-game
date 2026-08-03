#!/usr/bin/env python3
"""Frame-strip sprites replacing the sewer GPU particles.

steam_strip: three 16x24 frames of a rising steam wisp, drawn in pale
2-tone pixels with dithered edges (SNES steam is a looping sprite, not an
alpha-blended particle cloud).
drip_strip: two 8x16 frames of a falling water dribble.
"""
import random
from PIL import Image

H = lambda s: tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
PALE = H("d9dec2")     # STEEL_5
PALE_SH = H("a8b5a8")  # STEEL_7
DRIP = H("637196")     # ~SKY_5
DRIP_HI = H("b6c5c5")  # STEEL_6

FW, FH = 16, 24
steam = Image.new("RGBA", (FW * 3, FH))
p = steam.load()
rng = random.Random(3)

# Each frame: 2-3 puff blobs stacked, drifting up and thinning per frame.
for f in range(3):
    ox = f * FW
    puffs = [(8, 18 - f * 5, 3), (6 + f, 11 - f * 4, 2)]
    if f < 2:
        puffs.append((10 - f, 5 + f, 2 - f))
    for (cx, cy, r) in puffs:
        for y in range(max(0, cy - r), min(FH, cy + r + 1)):
            for x in range(max(0, cx - r - 1), min(FW, cx + r + 2)):
                d2 = (x - cx) * (x - cx) + (y - cy) * (y - cy)
                if d2 <= r * r + 1:
                    if (x + y) % 2 == 0 or d2 <= (r - 1) * (r - 1):
                        p[ox + x, y] = PALE if (x - cx) - (y - cy) < 0 else PALE_SH

steam.save("assets/textures/props/steam_strip.png")
print("steam_strip", steam.size)

DW, DH = 8, 16
drip = Image.new("RGBA", (DW * 2, DH))
q = drip.load()
for f in range(2):
    ox = f * DW
    for (x, y0, ln) in [(3, 1 + f * 3, 3), (4, 8 + f * 2, 2), (3, 13 - f * 6, 2)]:
        for dy in range(ln):
            y = (y0 + dy) % DH
            q[ox + x, y] = DRIP
        q[ox + x, y0 % DH] = DRIP_HI

drip.save("assets/textures/props/drip_strip.png")
print("drip_strip", drip.size)
