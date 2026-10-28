#!/usr/bin/env python3
"""Cut the five hero portraits for the Choose Your Character screen.

Source: assets/sprites/paintings/character_portraits.png (.gdignore'd source
art, 2026-10-23): a 1307x232 strip of the heroes as busts on a dark glow, left
to right Jeremy, Cory, Ryan, Brad, Stephen — the portraits the designer chose
for the select screen (they replace the ones first cut from the screen's
mock-up board, character_select_board.webp).

Each bust is found as a run of bright columns, and cut as a box of the
screen's portrait shape (CharacterRow.PORTRAIT_BOX, 96:100) centred on it, as
tall as the strip (padded with the strip's black where the box runs past its
edge). Saved at OUT_SIZE — twice the box — with a sharp resample; the screen
shrinks it smoothly (mipmaps), so the portraits keep their detail.

Brad's portrait also gets the embroidered golden-white feather the designer
asked for on his breastplate (2026-10-24), matching his in-game sprite
(tools/cut_hero_sprites.py FEATHER_ART). No pack has it: it is drawn here
(stitch_feather) at four times the portrait's size and shrunk onto it — a
slim feather lying across the plate with its tip raised 20 degrees, a white
lit vane, a pale-gold shaded vane, gold thread barbs and outline, the quill
running out down to the left, and a faint halo.

Output: assets/sprites/portraits/<hero>.png
Run: python3 tools/cut_character_portraits.py   (Pillow, numpy)
"""
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SRC = "assets/sprites/paintings/character_portraits.png"
OUT = "assets/sprites/portraits/%s.png"
HEROES = ["jeremy", "cory", "ryan", "brad", "stephen"]   # left to right on the strip
ASPECT = 96.0 / 100.0                                     # the select screen's portrait box
OUT_SIZE = (192, 200)
BRIGHT = 60        # a column with a few pixels brighter than this belongs to a bust
MIN_GAP = 8        # columns between busts

# A hero whose portrait comes from his own board instead of the strip:
# hero -> (source, box). The box keeps the select screen's 96:100 shape and
# frames the bust like the strip's (crown to belt). 2026-10-28: Stephen's,
# Ryan's and Brad's new front poses replaced theirs on the strip.
OVERRIDES = {
    "stephen": ("assets/sprites/paintings/stephen_v2_board.png", (33, -6, 241, 211)),
    "ryan": ("assets/sprites/paintings/ryan_v2_board.webp", (366, -4, 654, 296)),
    "brad": ("assets/sprites/paintings/brad_v2_board.webp", (350, -4, 670, 329)),   # his feather is painted on
}

# hero -> (centre x, centre y, length, lean in degrees) on the OUT_SIZE
# portrait: centred on the middle seam of Brad's breastplate, lying across
# it with the tip raised 20 degrees, up and to the right (designer).
FEATHER = {"brad": (93, 98, 40, 70)}
SS = 4             # the feather is drawn this many times larger, then shrunk
THREAD = (196, 160, 88)        # gold thread: outline and barbs
LIT = (255, 254, 246)          # the lit vane
SHADE = (240, 226, 182)        # the shaded vane
QUILL = (246, 234, 198)
HALO = (255, 246, 214)


def stitch_feather(img, cx, cy, length, lean):
    """Draw the feather onto img (RGB) centred at (cx, cy), `length` pixels
    tip to quill end, leaning `lean` degrees clockwise from upright."""
    n = 48
    L = length * SS
    # The feather upright, in its own frame: tip at y = -L/2, quill end at
    # +L/2, the vane over the top 78%, the quill bowed slightly.
    def quill_x(t):                       # t: 0 tip .. 1 quill end
        return 0.05 * L * math.sin(math.pi * t)
    def y_at(t):
        return -L / 2 + t * L
    vane_end = 0.78
    left, right, spine = [], [], []
    for i in range(n + 1):
        t = vane_end * i / n
        span = math.sin(math.pi * t / vane_end) ** 0.75
        q = quill_x(t)
        left.append((q - 0.13 * L * span, y_at(t)))
        right.append((q + 0.17 * L * span, y_at(t)))
        spine.append((q, y_at(t)))
    a = math.radians(lean)
    def place(pt):
        x, y = pt
        return (cx * SS + x * math.cos(a) - y * math.sin(a), cy * SS + x * math.sin(a) + y * math.cos(a))
    W, H = img.width * SS, img.height * SS
    art = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(art)
    thread_w = max(1, int(0.022 * L))
    lit = [place(p) for p in left] + [place(p) for p in reversed(spine)]
    shade = [place(p) for p in spine] + [place(p) for p in reversed(right)]
    d.polygon(lit, fill=LIT + (255,))
    d.polygon(shade, fill=SHADE + (255,))
    # The split in the lit vane, a third of the way down.
    k = int(n * 0.36)
    notch = [place(spine[k]), place(left[k - 2]), place(left[k + 3]), place(spine[k + 2])]
    d.polygon(notch, fill=(0, 0, 0, 0))
    # Embroidered barbs: thread stitches running out and up from the quill.
    for i in range(3, n - 2, 3):
        for side, pts in ((-1, left), (1, right)):
            if side < 0 and k - 2 <= i <= k + 3:
                continue
            j = max(0, i - 3)
            d.line([place(spine[i]), place((pts[j][0] * 0.92 + spine[i][0] * 0.08, pts[j][1]))],
                   fill=THREAD + (150,), width=max(1, thread_w // 2))
    d.line([place(p) for p in left] + [place(p) for p in reversed(right)] + [place(left[0])],
           fill=THREAD + (255,), width=thread_w, joint="curve")
    # The quill, from the tip down past the vane.
    stem = [place((quill_x(t), y_at(t))) for t in [i / 30.0 for i in range(31)]]
    d.line(stem, fill=QUILL + (255,), width=thread_w + 1, joint="curve")
    small = art.resize(img.size, Image.LANCZOS)
    # A faint halo where the thread meets the plate.
    halo_mask = small.split()[3].filter(ImageFilter.GaussianBlur(3))
    halo = Image.new("RGB", img.size, HALO)
    out = Image.composite(halo, img, halo_mask.point(lambda v: int(v * 0.45)))
    out.paste(small, (0, 0), small)
    return out


def main() -> None:
    img = Image.open(SRC).convert("RGB")
    lum = np.asarray(img).max(axis=2)
    cols = np.nonzero((lum > BRIGHT).sum(axis=0) > 3)[0]
    runs, start = [], cols[0]
    for a, b in zip(cols, cols[1:]):
        if b > a + MIN_GAP:
            runs.append((start, a))
            start = b
    runs.append((start, cols[-1]))
    assert len(runs) == len(HEROES), runs
    h = img.height
    w = int(round(h * ASPECT))
    for hero, (x0, x1) in zip(HEROES, runs):
        if hero in OVERRIDES:
            src, ob = OVERRIDES[hero]
            Image.open(src).convert("RGB").crop(ob).resize(OUT_SIZE, Image.LANCZOS).save(OUT % hero)
            print("%-8s from %s %s" % (hero, src, ob))
            continue
        cx = (x0 + x1) // 2
        box = (cx - w // 2, 0, cx - w // 2 + w, h)
        canvas = Image.new("RGB", (w, h))
        canvas.paste(img.crop((max(0, box[0]), 0, min(img.width, box[2]), h)), (max(0, -box[0]), 0))
        portrait = canvas.resize(OUT_SIZE, Image.LANCZOS)
        if hero in FEATHER:
            portrait = stitch_feather(portrait, *FEATHER[hero])
        portrait.save(OUT % hero)
        print("%-8s bust %d-%d -> box %s" % (hero, x0, x1, box))


if __name__ == "__main__":
    main()
