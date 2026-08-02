#!/usr/bin/env python3
"""Generate the terrain tile textures (style guide §6).

Each surface is a 128x128 sheet of 4x4 distinct 32px tile variants, so the
visible repeat period is 4 world tiles. Grayscale only (hue comes from the
runtime palette tint), quantized to an 8-step value ladder, nearest-filtered
at runtime. Deterministic per-variant seeds.
"""
import random
from PIL import Image

N = 32          # texels per tile
GRID = 4        # variants per axis
LADDER = [36, 73, 109, 146, 182, 219, 237, 255]  # 8-step gray ladder


def q(v):
    return min(LADDER, key=lambda l: abs(l - v))


def gv(v):
    v = q(max(0, min(255, v)))
    return (v, v, v, 255)


def make_sheet(name, tile_fn):
    img = Image.new("RGBA", (N * GRID, N * GRID))
    for ty in range(GRID):
        for tx in range(GRID):
            rng = random.Random(hash((name, tx, ty)) & 0xFFFF)
            tile = tile_fn(rng)
            img.paste(tile, (tx * N, ty * N))
    img.save(f"assets/textures/{name}.png")
    print(name, img.size)


def grass(rng):
    t = Image.new("RGBA", (N, N))
    p = t.load()
    for y in range(N):
        for x in range(N):
            p[x, y] = gv(232 + rng.randint(-12, 8))
    for _ in range(rng.randint(55, 75)):     # blade strokes
        x, y = rng.randrange(N), rng.randrange(N)
        v = 150 + rng.randint(-20, 20)
        p[x, y] = gv(v)
        if y + 1 < N and rng.random() < 0.6:
            p[x, y + 1] = gv(v + 30)
    for _ in range(rng.randint(10, 18)):     # light tufts
        x, y = rng.randrange(N), rng.randrange(N)
        p[x, y] = gv(255)
    return t


def dirt(rng):
    t = Image.new("RGBA", (N, N))
    p = t.load()
    for y in range(N):
        for x in range(N):
            p[x, y] = gv(222 + rng.randint(-16, 10))
    for _ in range(rng.randint(40, 60)):     # gravel
        x, y = rng.randrange(N), rng.randrange(N)
        v = rng.choice([165, 182, 255])
        p[x, y] = gv(v)
        if rng.random() < 0.4:
            p[(x + 1) % N, y] = gv(v)
    return t


def rock(rng):
    t = Image.new("RGBA", (N, N))
    p = t.load()
    for y in range(N):
        for x in range(N):
            p[x, y] = gv(215 + rng.randint(-8, 8))

    def seam_h(y0):
        y = y0
        for x in range(N):
            p[x, y % N] = gv(120 + rng.randint(-10, 10))
            if rng.random() < 0.3:
                y += rng.choice([-1, 1])

    def seam_v(x0, y_from, y_to):
        x = x0
        for y in range(y_from, y_to):
            p[x % N, y % N] = gv(130 + rng.randint(-10, 10))
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
    for y in range(N):
        for x in range(N):
            if p[x, y][0] < 160 and p[x, (y + 1) % N][0] > 190:
                p[x, (y + 1) % N] = gv(246)
    return t


def brick(rng):
    t = Image.new("RGBA", (N, N))
    p = t.load()
    BH, BW = 8, 16
    for y in range(N):
        for x in range(N):
            p[x, y] = gv(218 + rng.randint(-10, 6))
    for row in range(N // BH):
        y = row * BH
        for x in range(N):
            p[x, y] = gv(128 + rng.randint(-8, 8))
        off = (row % 2) * (BW // 2)
        for cx in range(0, N, BW):
            for yy in range(y, min(y + BH, N)):
                p[(cx + off) % N, yy] = gv(132 + rng.randint(-8, 8))
        for x in range(N):
            if p[x, (y + 1) % N][0] > 160:
                p[x, (y + 1) % N] = gv(240)
    # occasional chipped brick
    for _ in range(rng.randint(1, 3)):
        x, y = rng.randrange(N), rng.randrange(N)
        p[x, y] = gv(170)
    return t


make_sheet("tile_grass", grass)
make_sheet("tile_dirt", dirt)
make_sheet("tile_rock", rock)
make_sheet("tile_brick", brick)
