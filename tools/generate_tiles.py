#!/usr/bin/env python3
"""Full-color terrain tile sheets (16-bit environment pass).

Each surface is a 128x128 sheet of 4x4 distinct 32px variants authored
directly in master-palette colors. Iteration goals: SNES ground reads as
gentle CLUMPED mottling (blobby patches a shade apart), never single-pixel
confetti; cliffs read as horizontal strata with lit course edges, never
vertical cracks. All accent colors are exact palette members so the
conform pass cannot shift them somewhere surprising. Deterministic
per-variant seeds.
"""
import random
from PIL import Image

N = 32
GRID = 4
H = lambda s: tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (255,)

# Exact master-palette members only.
GRASS_HI = H("9ad994")     # FOLIAGE_1
GRASS = H("389878")        # TEAL_3
GRASS_SH = H("32716c")     # TEAL_5
GRASS_CORE = H("205858")   # TEAL_6
DIRT_HI = H("d4ba7e")      # SKIN_2
DIRT = H("9f8156")         # LEATHER_7
DIRT_SH = H("815c21")      # LEATHER_10
DIRT_CORE = H("725436")    # LEATHER_12
ROCK_HI = H("d9dec2")      # STEEL_5
ROCK = H("c6a891")         # SKIN_3
ROCK_SH = H("a78e51")      # LEATHER_6
ROCK_CORE = H("6b533e")    # SKIN_4
COOL_HI = H("b6c5c5")      # STEEL_6
COOL = H("7c8989")         # STEEL_8
COOL_SH = H("63778f")      # SKY_5
COOL_CORE = H("374e6e")    # SKY_7
FLOWER_GOLD, FLOWER_ROSE, FLOWER_WHITE = H("f9dc3e"), H("f890d0"), H("f2fdff")
MOSS = H("389878")         # TEAL_3


def sheet(name, tile_fn):
    img = Image.new("RGBA", (N * GRID, N * GRID))
    for ty in range(GRID):
        for tx in range(GRID):
            rng = random.Random(hash((name, tx, ty)) & 0xFFFF)
            img.paste(tile_fn(rng), (tx * N, ty * N))
    img.save(f"assets/textures/{name}.png")
    print(name, img.size)


def blob(p, rng, cx, cy, r, c, keep=None):
    """Irregular filled patch: the unit of SNES ground mottling."""
    for _ in range(r * r * 3):
        x = cx + rng.randint(-r, r)
        y = cy + rng.randint(-r, r)
        if 0 <= x < N and 0 <= y < N:
            if keep is None or p[x, y] in keep:
                p[x, y] = c


def grass(rng):
    t = Image.new("RGBA", (N, N)); p = t.load()
    for y in range(N):
        for x in range(N):
            p[x, y] = GRASS
    # Broad soft mottling: a few darker patches, at most one shade apart.
    for _ in range(rng.randint(4, 6)):
        blob(p, rng, rng.randrange(N), rng.randrange(N), rng.randint(2, 4), GRASS_SH)
    # Tufts: short 2-3px angled strokes rooted in the dark patches.
    for _ in range(rng.randint(7, 10)):
        x, y = rng.randrange(1, N - 1), rng.randrange(N - 2)
        p[x, y] = GRASS_CORE
        p[x, y + 1] = GRASS_SH
        if rng.random() < 0.5:
            p[x + 1, y + 1] = GRASS_SH
    # Sparse lit tips, resting on a tuft so they read as blades not sparkle.
    for _ in range(rng.randint(3, 5)):
        x, y = rng.randrange(N), rng.randrange(1, N)
        if p[x, y - 1] in (GRASS_SH, GRASS_CORE):
            p[x, y - 1] = GRASS_HI
    if rng.random() < 0.10:                       # rare worn patch, kept dark so
        blob(p, rng, rng.randrange(8, 24), rng.randrange(8, 24), 2, DIRT_SH)
        # it never reads as bright litter repeating on the tile grid
    if rng.random() < 0.22:                       # a rare flower: bloom + stem
        x, y = rng.randrange(2, 30), rng.randrange(2, 29)
        p[x, y] = rng.choice([FLOWER_GOLD, FLOWER_ROSE, FLOWER_WHITE])
        p[x, y + 1] = GRASS_CORE
    return t


def grass_far(rng):
    """Backdrop-plane grass: mottle only — no flowers, tufts, or highlights.
    The out-of-bounds plane is tinted dark, where bright accents would pop
    into scattered noise specks."""
    t = Image.new("RGBA", (N, N)); p = t.load()
    for y in range(N):
        for x in range(N):
            p[x, y] = GRASS
    for _ in range(rng.randint(4, 6)):
        blob(p, rng, rng.randrange(N), rng.randrange(N), rng.randint(2, 4), GRASS_SH)
    for _ in range(rng.randint(2, 3)):
        blob(p, rng, rng.randrange(N), rng.randrange(N), 2, GRASS_CORE, keep=(GRASS_SH,))
    return t


def dirt(rng):
    t = Image.new("RGBA", (N, N)); p = t.load()
    for y in range(N):
        for x in range(N):
            p[x, y] = DIRT
    # Clumped tonal patches — packed earth, not static.
    for _ in range(rng.randint(4, 6)):
        blob(p, rng, rng.randrange(N), rng.randrange(N), rng.randint(2, 4), DIRT_SH)
    for _ in range(rng.randint(2, 3)):
        blob(p, rng, rng.randrange(N), rng.randrange(N), 2, DIRT_HI)
    # A few embedded stones: warm 2x1 pebbles with a shaded underside.
    for _ in range(rng.randint(2, 4)):
        x, y = rng.randrange(1, 30), rng.randrange(1, 30)
        p[x, y] = DIRT_HI
        p[x + 1, y] = DIRT_SH
        p[x, y + 1] = DIRT_CORE
    for _ in range(rng.randint(0, 2)):            # grass creeping in
        x, y = rng.randrange(N), rng.randrange(N)
        p[x, y] = GRASS_SH
    return t


def rock(rng):
    """Cliff faces: horizontal strata courses with lit edges and staggered
    vertical joints — Secret-of-Mana rock, not dried mud."""
    t = Image.new("RGBA", (N, N)); p = t.load()
    for y in range(N):
        for x in range(N):
            p[x, y] = ROCK
    # Horizontal course seams at wobbling heights.
    seams = [0, rng.randint(6, 8), rng.randint(13, 15), rng.randint(21, 24)]
    for y0 in seams:
        y = y0
        for x in range(N):
            p[x, y % N] = ROCK_CORE
            p[x, (y + 1) % N] = ROCK_HI           # sunlit top edge of the course
            if rng.random() < 0.22 and abs(y - y0) < 2:
                y += rng.choice([-1, 1])
    # Sparse short vertical joints: a subtle 1px notch, not a full plank line.
    for (a, b) in zip(seams, seams[1:] + [N]):
        for x0 in range(rng.randint(3, 8), N, rng.randint(11, 15)):
            top = a + 2
            bot = min(b, top + rng.randint(3, 5))
            for y in range(top, bot):
                p[x0 % N, y % N] = ROCK_SH
            p[x0 % N, top % N] = ROCK_CORE
    # Gentle tonal variation inside blocks (clumps, not grains).
    for _ in range(rng.randint(3, 5)):
        blob(p, rng, rng.randrange(N), rng.randrange(N), 2, ROCK_SH, keep=(ROCK,))
    # Moss: small clusters tucked along seams, not lone pixels.
    for _ in range(rng.randint(1, 2)):
        x, y = rng.randrange(1, 31), rng.randrange(1, 31)
        p[x, y] = MOSS
        p[x + 1, y] = MOSS
        if rng.random() < 0.5:
            p[x, y + 1] = GRASS_SH
    return t


def water(rng):
    """Flat 16-bit water: two-tone blue with sparse ripple dashes and a
    rare foam fleck. No specular, no emission — the SNES read comes from
    the painted ripples alone."""
    WATER = H("3e6794")       # SKY_4
    WATER_SH = H("374e6e")    # SKY_7
    RIPPLE = H("637196")      # near SKY_5, conformed at build time
    FOAM = H("b6c5c5")        # STEEL_6
    t = Image.new("RGBA", (N, N)); p = t.load()
    for y in range(N):
        for x in range(N):
            p[x, y] = WATER
    for _ in range(rng.randint(3, 5)):            # deeper patches
        blob(p, rng, rng.randrange(N), rng.randrange(N), rng.randint(2, 4), WATER_SH)
    for _ in range(rng.randint(5, 7)):            # horizontal ripple dashes
        x, y = rng.randrange(N - 4), rng.randrange(N)
        for dx in range(rng.randint(2, 4)):
            p[x + dx, y] = RIPPLE
    if rng.random() < 0.3:                        # rare foam fleck
        x, y = rng.randrange(1, 31), rng.randrange(1, 31)
        p[x, y] = FOAM
        p[x + 1, y] = RIPPLE
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
    for _ in range(rng.randint(2, 4)):            # algae/moss stains in clumps
        x, y = rng.randrange(1, 30), rng.randrange(1, 30)
        p[x, y] = MOSS
        p[x + 1, y] = MOSS
        if rng.random() < 0.5:
            p[x, min(31, y + 1)] = GRASS_CORE
    for _ in range(rng.randint(2, 4)):            # chipped faces
        x, y = rng.randrange(N), rng.randrange(N)
        p[x, y] = COOL_HI
    return t


sheet("tile_grass", grass)
sheet("tile_grass_far", grass_far)
sheet("tile_dirt", dirt)
sheet("tile_rock", rock)
sheet("tile_water", water)
sheet("tile_brick", brick)
