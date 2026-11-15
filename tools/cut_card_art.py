#!/usr/bin/env python3
"""Cut the designer's painted card art out of its sources.

Sources: assets/sprites/paintings/card_art_*.webp / .jpg (.gdignore'd source art).

Boards (BOARDS): a row of square paintings, each in a thin black panel
border; the box is the painting just inside that border (measured: the black
columns and rows run to mean luminance < 12). Each is centre-cropped square
and shrunk to SIZE x SIZE.
  2026-11-15: Basic Attack (a sword through a target) and Block (a sword
  turned on a lion-crest shield).

Single paintings (SINGLES): one landscape painting per card, cropped to a
band about twice as wide as it is tall round the faces and the point of
impact (the box), then shrunk to WIDTH wide.
  2026-11-15: Berserker's Tithe, Momentous Slam, Fan of Knives, Down Town,
  Premeditated.
  The same day: Exacerbate Wounds, Blade Barrage, Exposed Artery, Heavy
  Swing, Oops.

Fitted paintings (FITTED): one object to be seen whole, fitted to the
window's height with its own ground carried out to the sides.

The card's art window is wider than it is tall (about 2.3:1 on the Attack
frame), so CardUI shows these "covered": scaled to the window's width and
cropped about the middle. The boxes below put the action in that middle.

Output: assets/textures/cards/art/<card_id>.png, which
scripts/ui/skill_icon_art.gd maps in CARD_PAINTINGS.
Run: python3 tools/cut_card_art.py   (Pillow)
"""
import os

from PIL import Image

SRC = "assets/sprites/paintings/%s"
OUT = "assets/textures/cards/art/%s.png"
SIZE = 384    # boards' squares: about four times the art window's width
WIDTH = 512   # singles' width: sharp on the hovered and close-up card

# board -> {card_id: (left, top, right, bottom)}
BOARDS = {
    "card_art_attack_block_board.webp": {
        "basic_attack": (9, 8, 873, 879),
        "block": (903, 8, 1768, 879),
    },
}

# card_id -> (source, (left, top, right, bottom))
SINGLES = {
    # The whole of the berserker's roaring head down to the bloodied blade.
    "berserkers_tithe": ("card_art_berserkers_tithe.webp", (0, 70, 1536, 800)),
    # Up high enough to keep the struck man's helmet; down to the charger's fist.
    "momentous_slam": ("card_art_momentous_slam.webp", (0, 0, 1448, 690)),
    # The thrower's face and all four knives.
    "fan_of_knives": ("card_art_fan_of_knives.webp", (0, 130, 1536, 860)),
    # The archer's draw, the castle and the rider thrown from his horse.
    "down_town": ("card_art_down_town.webp", (0, 120, 1536, 850)),
    # Both faces and the knife at the throat.
    "premeditated": ("card_art_premeditated.webp", (0, 80, 1536, 810)),
    # Both faces and the shuriken in the chest (the cut shin falls below).
    "exacerbate_wounds": ("card_art_exacerbate_wounds.webp", (0, 0, 1536, 730)),
    # Both faces, the knives in the chest and the thrower's hand.
    "blade_barrage": ("card_art_blade_barrage.webp", (0, 40, 1536, 770)),
    # The axeman's face and the kneeling man bleeding (the axe head is cut).
    "exposed_artery": ("card_art_exposed_artery.webp", (0, 60, 1536, 790)),
    # The roar, the hammer head and the shield buckling under it.
    "heavy_swing": ("card_art_heavy_swing.webp", (0, 90, 1536, 820)),
    # The punch thrown and the rake in the face; the tines are below.
    "oops": ("card_art_oops.jpg", (0, 0, 1000, 475)),
}

# card_id -> (source, box): a single object to be seen whole (a gem, a
# stone, a necklace). The box is fitted to the window's height, centred,
# and the sides carry the painting's own edge colour outward, darkening a
# little, so its dark ground runs on to the window's edges. 2026-11-15
# (no cards with these ids yet; the art waits for them).
FITTED = {
    "energy_gem": ("card_art_energy_gem.png", (0, 0, 230, 327)),
    "fumbilities": ("card_art_fumbilities.png", (0, 0, 322, 355)),
    "stone_patch": ("card_art_stone_patch.webp", (0, 100, 1448, 1000)),
    "life_from_resource": ("card_art_life_from_resource.webp", (0, 0, 1448, 960)),
    "lemon_drop": ("card_art_lemon_drop.webp", (0, 30, 1448, 1086)),
}
FIT_ASPECT = 2.3    # the Attack frame's art window, about the widest
FIT_FEATHER = 0.08  # the fitted picture's sides fade into the fill over this much of its width


def fitted(source, box):
    piece = Image.open(SRC % source).convert("RGB").crop(box)
    h = round(WIDTH / FIT_ASPECT)
    w_in = round(piece.width * h / piece.height)
    if w_in > WIDTH:   # already wider than the window: shrink to its width
        w_in, h_in = WIDTH, round(piece.height * WIDTH / piece.width)
    else:
        h_in = h
    inner = piece.resize((w_in, h_in), Image.LANCZOS)
    # The fill: each side carries the picture's own edge colour outward,
    # row by row (smoothed down the rows), darkening a little toward the
    # window's edges, so the seam matches and the ground runs on.
    import numpy as np
    a = np.asarray(inner).astype(np.float32)
    k = max(2, w_in // 40)
    left = a[:, :k].mean(axis=1)
    right = a[:, -k:].mean(axis=1)
    from scipy.ndimage import gaussian_filter1d
    left = gaussian_filter1d(left, h_in * 0.06, axis=0)
    right = gaussian_filter1d(right, h_in * 0.06, axis=0)
    x0 = (WIDTH - w_in) // 2
    canvas = np.zeros((h, WIDTH, 3), np.float32)
    top = (h - h_in) // 2
    for x in range(WIDTH):
        if x < x0 + w_in // 2:
            col, t = left, (x0 - x) / max(1, x0)
        else:
            col, t = right, (x - (x0 + w_in)) / max(1, WIDTH - x0 - w_in)
        dim = 1.0 - 0.35 * min(1.0, max(0.0, t))
        canvas[top:top + h_in, x] = col * dim
    back = Image.fromarray(canvas.clip(0, 255).astype(np.uint8))
    # The picture over it, its sides feathered in.
    mask = Image.new("L", (w_in, h_in), 255)
    fw = max(1, round(w_in * FIT_FEATHER))
    for x in range(fw):
        a = round(255 * (x + 1) / (fw + 1))
        for xx in (x, w_in - 1 - x):
            mask.paste(a, (xx, 0, xx + 1, h_in))
    back.paste(inner, ((WIDTH - w_in) // 2, (h - h_in) // 2), mask)
    return back


def main() -> None:
    os.makedirs(os.path.dirname(OUT % "x"), exist_ok=True)
    for board, cuts in BOARDS.items():
        src = Image.open(SRC % board).convert("RGB")
        for card_id, box in cuts.items():
            piece = src.crop(box)
            # A few pixels off square: centre-crop to the shorter side.
            side = min(piece.size)
            l = (piece.width - side) // 2
            t = (piece.height - side) // 2
            piece = piece.crop((l, t, l + side, t + side)).resize((SIZE, SIZE), Image.LANCZOS)
            piece.save(OUT % card_id, optimize=True)
            print("wrote", OUT % card_id)
    for card_id, (source, box) in SINGLES.items():
        piece = Image.open(SRC % source).convert("RGB").crop(box)
        h = round(piece.height * WIDTH / piece.width)
        piece.resize((WIDTH, h), Image.LANCZOS).save(OUT % card_id, optimize=True)
        print("wrote", OUT % card_id, (WIDTH, h))
    for card_id, (source, box) in FITTED.items():
        fitted(source, box).save(OUT % card_id, optimize=True)
        print("wrote", OUT % card_id, "(fitted)")


if __name__ == "__main__":
    main()
