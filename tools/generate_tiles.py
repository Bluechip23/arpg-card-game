#!/usr/bin/env python3
"""Full-color terrain tile sheets (16-bit environment pass).

Each surface is a 128x128 sheet of 4x4 distinct 32px variants authored
directly in master-palette colors (SNES-style multi-hue detail: flowers and
dirt in the grass, moss on rock and brick, pebbles in the soil). The runtime
tint is now a NEAR-WHITE theme cast (see dungeon_manager._add_multimesh), so
these colors survive on screen. Deterministic per-variant seeds.
"""
import random
from PIL import Image

N = 32
GRID = 4
H = lambda s: tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

GRASS_HI, GRASS, GRASS_SH, GRASS_CORE = H("9ad994"), H("389878"), H("206020"), H("205858")
DIRT_HI, DIRT, DIRT_SH = H("c6a891"), H("a78e51"), H("6b533e")
DIRT_CORE = H("452e5b")
ROCK_HI, ROCK, ROCK_SH, ROCK_CORE = H("d9dec2"), H("c6a891"), H("a78e51"), H("6b533e")
COOL_HI, COOL, COOL_SH, COOL_CORE = H("b6c5c5"), H("8898a0"), H("63778f"), H("3c5575")
FLOWER_GOLD, FLOWER_ROSE, FLOWER_WHITE = H("f9dc3e"), H("f890d0"), H("f2fdff")
MOSS = H("389878")


def sheet(name, tile_fn):
    img = Image.new("RGBA", (N * GRID, N * GRID))
    for ty in range(GRID):
        for tx in range(GRID):
            rng = random.Random(hash((name, tx, ty)) & 0xFFFF)
            img.paste(tile_fn(rng), (tx * N, ty * N))
    img.save(f"assets/textures/{name}.png")
    print(name, img.size)


def grass(rng):
    t = Image.new("RGBA", (N, N)); p = t.load()
    for y in range(N):
        for x in range(N):
            p[x, y] = GRASS
    for _ in range(rng.randint(40, 52)):          # blade strokes, clustered pairs
        x, y = rng.randrange(N), rng.randrange(N - 1)
        p[x, y] = GRASS_SH
        p[x, y + 1] = GRASS_SH
        if rng.random() < 0.3:
            p[x, y + 1] = GRASS_CORE
    for _ in range(rng.randint(6, 10)):           # sparse lit tips
        x, y = rng.randrange(N), rng.randrange(N)
        p[x, y] = GRASS_HI
    if rng.random() < 0.28:                       # occasional worn dirt patch
        cx, cy = rng.randrange(8, 24), rng.randrange(8, 24)
        for _ in range(rng.randint(8, 14)):
            x = min(N - 1, max(0, cx + rng.randint(-2, 2)))
            y = min(N - 1, max(0, cy + rng.randint(-1, 1)))
            p[x, y] = DIRT
    if rng.random() < 0.22:                       # a rare flower
        x, y = rng.randrange(2, 30), rng.randrange(2, 30)
        p[x, y] = rng.choice([FLOWER_GOLD, FLOWER_ROSE, FLOWER_WHITE])
    return t


def dirt(rng):
    t = Image.new("RGBA", (N, N)); p = t.load()
    for y in range(N):
        for x in range(N):
            p[x, y] = DIRT
    for _ in range(rng.randint(40, 60)):
        x, y = rng.randrange(N), rng.randrange(N)
        p[x, y] = rng.choice([DIRT_SH, DIRT_HI, DIRT_SH])
        if rng.random() < 0.35:
            p[(x + 1) % N, y] = DIRT_SH
    for _ in range(rng.randint(4, 8)):            # grey pebbles
        x, y = rng.randrange(1, 31), rng.randrange(1, 31)
        p[x, y] = COOL
        p[x + (1 if x < 31 else -1), y] = COOL_SH
    for _ in range(rng.randint(0, 3)):            # grass creeping in
        x, y = rng.randrange(N), rng.randrange(N)
        p[x, y] = GRASS_SH
    return t


def rock(rng):
    t = Image.new("RGBA", (N, N)); p = t.load()
    for y in range(N):
        for x in range(N):
            p[x, y] = ROCK
    def seam_h(y0):
        y = y0
        for x in range(N):
            p[x, y % N] = ROCK_CORE
            if rng.random() < 0.3:
                y += rng.choice([-1, 1])
    def seam_v(x0, a, b):
        x = x0
        for y in range(a, b):
            p[x % N, y % N] = ROCK_CORE
            if rng.random() < 0.3:
                x += rng.choice([-1, 1])
    rows = [0, rng.randint(9, 13), rng.randint(19, 23)]
    for r in rows:
        seam_h(r)
    for x0, a, b in [(rng.randint(4, 8), 0, rows[1]), (rng.randint(18, 22), 0, rows[1]),
                     (rng.randint(27, 30), 0, rows[1]), (rng.randint(1, 4), rows[1], rows[2]),
                     (rng.randint(12, 16), rows[1], rows[2]), (rng.randint(23, 27), rows[1], rows[2]),
                     (rng.randint(7, 11), rows[2], N), (rng.randint(16, 20), rows[2], N),
                     (rng.randint(27, 31), rows[2], N)]:
        seam_v(x0, a, b)
    for y in range(N):                            # top-lit stone edges
        for x in range(N):
            if p[x, y] == ROCK_CORE and p[x, (y + 1) % N] == ROCK:
                p[x, (y + 1) % N] = ROCK_HI
    for _ in range(rng.randint(2, 5)):            # moss in the cracks
        x, y = rng.randrange(N), rng.randrange(N)
        p[x, y] = MOSS
    for _ in range(rng.randint(6, 10)):           # grain
        x, y = rng.randrange(N), rng.randrange(N)
        if p[x, y] == ROCK:
            p[x, y] = ROCK_SH
    return t


def brick(rng):
    t = Image.new("RGBA", (N, N)); p = t.load()
    BH, BW = 8, 16
    for y in range(N):
        for x in range(N):
            p[x, y] = COOL_SH                     # damp stone bricks
    for row in range(N // BH):
        y = row * BH
        for x in range(N):
            p[x, y] = COOL_CORE
        off = (row % 2) * (BW // 2)
        for cx in range(0, N, BW):
            for yy in range(y, min(y + BH, N)):
                p[(cx + off) % N, yy] = COOL_CORE
        for x in range(N):
            if p[x, (y + 1) % N] == COOL_SH:
                p[x, (y + 1) % N] = COOL
    for _ in range(rng.randint(3, 7)):            # algae/moss stains
        x, y = rng.randrange(1, 31), rng.randrange(1, 31)
        p[x, y] = MOSS
        if rng.random() < 0.5:
            p[x, min(31, y + 1)] = GRASS_CORE
    for _ in range(rng.randint(2, 4)):            # chipped faces
        x, y = rng.randrange(N), rng.randrange(N)
        p[x, y] = COOL_HI
    return t


sheet("tile_grass", grass)
sheet("tile_dirt", dirt)
sheet("tile_rock", rock)
sheet("tile_brick", brick)
