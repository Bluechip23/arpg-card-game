#!/usr/bin/env python3
"""Cut the designer's hero action boards (basic attack, basic block) into
the sheets SpriteFigure plays for them.

Sources (assets/sprites/paintings/, .gdignore'd): one board an action, its
frames on a ruled grid over the same dark glowing ground as the walk boards
(cut the same way: cut_hero_sprites.cut_opaque_cell). Unlike a walk, an
action moves the hero — Brad's smash leaps up and lands — so a frame is not
packed onto the cell's floor: every frame keeps where it sits in its cell,
measured from the row's first frame (the hero standing), whose feet set the
ground and whose middle the anchor. Dust and sparks round the figure are
kept (only specks under ACTION_KEEP_PX go).

Each sheet: square cells, ACTIONS[...]["frames"] columns, rows south, north,
east, west (a row the board does not draw is left empty, and SpriteFigure
falls back to its old motion facing that way). The anchor sits at the
cell's middle, the ground ACTION_FLOOR of the cell up from its bottom
(SpriteFigure.ACTION_FLOOR). Scaled like the hero's walk and still poses:
the standing front frame is HEIGHT texels crown to feet, WIDEN as wide; the
smooth twin is exactly twice the size.

Output: assets/sprites/generated/heroes/<hero>_<action>.png (+ smooth/)
Run: python3 tools/cut_hero_actions.py   (Pillow, numpy, opencv-python-headless)
"""
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import smooth_art  # noqa: E402
import cut_hero_sprites as hs  # noqa: E402

OUT = "assets/sprites/generated/heroes/%s_%s.png"
ACTION_FLOOR = 8        # the ground sits a 1/ACTION_FLOOR of the cell up from its bottom
ACTION_KEEP_PX = 25     # pieces smaller than this (source px) are specks, not dust
STREAK_CORE = 11        # "streaks": the body's core is what survives an opening this wide...
STREAK_KEEP = 9         # ...grown back this much...
STREAK_DARK = 120       # ...and outside it, pixels darker than this go
CELL_INSET = 4          # px kept clear of the grid lines
DARK_PIECE = 40         # "drop_dark": a piece whose 90th-percentile channel is under this goes

# Per hero and action: the board, its grid (column lines; each row's top and
# bottom line) and the facing each row draws; optionally "pockets": False
# and "haze": True, "narrow": px for cut_hero_sprites.cut_opaque_cell;
# "drop_dark": True drops unlit pieces (floor shadows); "close": px fills
# notches in the silhouette that narrow.
ACTIONS = {
    # 2026-10-31: Brad's jumping overhead smash — crouch, leap with both
    # fists raised, slam down in a burst of sparks and dust.
    ("brad", "attack"): {
        "src": "brad_attack_board.webp",
        "pockets": False,   # his dark pouches and trousers are near the ground's colour
        "narrow": 7,
        "cols": [117, 295, 471, 647, 827, 1002, 1179, 1356, 1528],
        "rows": [(53, 271), (271, 485), (485, 685), (685, 894)],
        "facings": ["south", "north", "west", "east"],
    },
    # 2026-10-31: Brad's block — stone encases him from the feet up ("The
    # Thing" style), the glowing feather showing through. No back view.
    ("brad", "block"): {
        "src": "brad_block_board.webp",
        "pockets": False,   # the dark cracks between his stones are the ground's colour
        "narrow": 7,
        "close": 5,
        "copy": {"north": "south"},
        "cols": [119, 274, 429, 586, 742, 898, 1055, 1211, 1367, 1525, 1682, 1839, 1992],
        "rows": [(53, 228), (235, 409), (416, 591)],
        "facings": ["south", "west", "east"],
    },
    # 2026-10-31: Jeremy's backwind bone blade — he winds back and a bone
    # blade sweeps out of his arm in a glowing arc.
    ("jeremy", "attack"): {
        "src": "jeremy_attack_board.webp",
        "close": 5,         # gaps between his dark trouser folds
        "cols": [115, 282, 460, 637, 812, 992, 1170, 1352, 1530],
        "rows": [(53, 269), (269, 482), (482, 682), (682, 893)],
        "facings": ["south", "north", "west", "east"],
    },
    # 2026-10-31: Jeremy's block — arms spread, a wall of bones and skulls
    # rises before him.
    ("jeremy", "block"): {
        "src": "jeremy_block_board.webp",
        "cols": [111, 287, 465, 642, 821, 998, 1177, 1355, 1531],
        "rows": [(50, 258), (258, 468), (468, 677), (677, 897)],
        "facings": ["south", "north", "west", "east"],
    },
    # 2026-10-31: Stephen's bear transformation swipe (revised) — his head
    # turns bear and the bear arm rakes across; he ends in the bear's head.
    ("stephen", "attack"): {
        "src": "stephen_attack_board.webp",
        "pockets": False,   # the back of his neck is as dark as the ground...
        "narrow": 7,        # ...and the fill reaches it through a slit
        "cols": [116, 293, 470, 649, 825, 1003, 1178, 1356, 1529],
        "rows": [(52, 266), (266, 481), (481, 684), (684, 902)],
        "facings": ["south", "north", "west", "east"],
    },
    # 2026-10-31: Stephen's defensive parry — two knives drawn and crossed
    # with a flash, then sheathed.
    ("stephen", "block"): {
        "src": "stephen_block_board.webp",
        "haze": True,       # the flash's dark glow
        "streaks": True,    # ...and its dim arcs
        "pockets": False,
        "narrow": 7,
        "cols": [115, 310, 519, 720, 924, 1130, 1333, 1530],
        "rows": [(52, 267), (267, 482), (482, 684), (684, 902)],
        "facings": ["south", "north", "west", "east"],
    },
    # 2026-10-31: Ryan's dual blade flurry — four alternating stabs. Its
    # cells are narrow; a stab's streak that crosses into the next cell is
    # cut at the line.
    ("ryan", "attack"): {
        "src": "ryan_attack_board.webp",
        "tol": 4,           # his near-black clothes sit close to the ground's colour
        "pockets": False,   # near-black clothes on a near-black ground: the
        "narrow": 7,        # shadows between his straps are the ground's colour
        "close": 7,
        "cols": [100, 202, 303, 405, 508, 610, 713, 815, 918, 1021, 1125, 1227, 1330, 1432, 1532],
        "rows": [(55, 270), (270, 481), (481, 684), (684, 894)],
        "facings": ["south", "north", "west", "east"],
    },
    # 2026-10-31: Ryan's block is a backflip (a full 360). Each row is its
    # own panel, a frame-number strip under it.
    ("ryan", "block"): {
        "src": "ryan_block_board.webp",
        "tol": 4,           # his near-black clothes sit close to the ground's colour
        "drop_dark": True,  # the shadow on the floor under the flip
        "narrow": 7,        # his near-black wraps: as for his flurry
        "close": 7,
        "cols": [99, 190, 283, 378, 469, 562, 655, 751, 847, 944, 1039, 1137, 1233, 1330, 1427, 1526],
        "rows": [(59, 247), (296, 483), (532, 715), (760, 946)],
        "facings": ["south", "north", "west", "east"],
    },
    # 2026-10-31: Cory's aerial shadow kick combo — a crouch, a leap, kicks
    # trailing violet shadow, a spinning kick, and he lands.
    ("cory", "attack"): {
        "src": "cory_attack_board.webp",
        "pockets": False,   # his robe's dark folds by the hood are the ground's colour
        "narrow": 7,        # and the fill reaches them through slits
        "cols": [108, 242, 381, 523, 662, 810, 947, 1094, 1230, 1393, 1528],
        "rows": [(52, 257), (257, 471), (471, 678), (678, 896)],
        "facings": ["south", "north", "west", "east"],
    },
    # 2026-10-31: Cory's energy field — a palm raised, a ring of blue force
    # flares before it and fades.
    ("cory", "block"): {
        "src": "cory_block_board.webp",
        "pockets": False,
        "glow": "blue",     # the field's light fades into what is behind it
        "cols": [115, 292, 470, 648, 825, 1002, 1179, 1356, 1532],
        "rows": [(52, 267), (267, 478), (478, 689), (689, 900)],
        "facings": ["south", "north", "west", "east"],
    },
}


def cut_cell(cell, pockets=True, haze=False, narrow=0, drop_dark=False, close=0, tol=None, haze_dark=None, glow=False, glow_edge=0, streaks=False, halo=False):
    """One cell's figure (and its dust) on transparency, cell-sized, plus
    the kept pixels' box."""
    import cv2
    rgba = hs.cut_opaque_cell(cell, pockets, haze, narrow, tol, haze_dark, glow, glow_edge)
    if halo:
        rgba = hs.strip_halo(rgba, *hs.HALO_STRIP["brad"])
    if streaks:
        # Thin dark strands off the body (a flash's dim arcs, Stephen's
        # parry): what is cut but outside the body's thick core, and dark,
        # goes. Blades are thin too, but bright.
        sol = (rgba[..., 3] > 0).astype(np.uint8)
        core = cv2.morphologyEx(sol, cv2.MORPH_OPEN, np.ones((STREAK_CORE, STREAK_CORE), np.uint8))
        nc, clab, cst, _ = cv2.connectedComponentsWithStats(core, connectivity=8)
        if nc > 1:
            core = (clab == 1 + int(np.argmax(cst[1:, 4]))).astype(np.uint8)
        core = cv2.dilate(core, np.ones((STREAK_KEEP, STREAK_KEEP), np.uint8)) > 0
        dark = cell[..., :3].max(axis=2) < STREAK_DARK
        rgba[(sol > 0) & ~core & dark] = 0
    solid = (rgba[..., 3] > 0).astype(np.uint8)
    if close:
        # Notches in the silhouette under `close` px across are the figure's
        # own dark seams (between Ryan's leg wraps), opened onto the ground.
        solid = cv2.morphologyEx(solid, cv2.MORPH_CLOSE, np.ones((close, close), np.uint8))
        rgba[..., 3] = np.maximum(rgba[..., 3], solid * 255)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(solid, connectivity=8)
    keep = np.zeros(solid.shape, bool)
    bright = cell[..., :3].max(axis=2)
    for k in range(1, n):
        if stats[k][4] < ACTION_KEEP_PX:
            continue
        piece = lab == k
        # A piece with nothing lit in it is a shadow on the floor, not the
        # hero or his effect (Ryan's backflip casts one under him).
        if drop_dark and np.percentile(bright[piece], 90) < DARK_PIECE:
            continue
        keep |= piece
    rgba[~keep] = 0
    ys, xs = np.nonzero(keep)
    return Image.fromarray(rgba, "RGBA"), (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)


def mass(f):
    """A cut frame's (height, filled texels): what the eye reads as its size."""
    a = f[..., 3] > 0
    ys = np.nonzero(a.any(axis=1))[0]
    return (ys[-1] - ys[0] + 1, int(a.sum())) if len(ys) else None


def still_size(hero, facing):
    """The hero's still pose that way, from his cut sheet (column 0)."""
    sheet = np.asarray(Image.open(hs.OUT % hero).convert("RGBA"))
    c = sheet.shape[0] // len(hs.ROWS)
    r = hs.ROWS.index(facing)
    return mass(sheet[r * c:(r + 1) * c, 0:c])


def match_scale(got, ref):
    """The factor (relative) that draws a frame of size `got` the height of
    `ref`."""
    # Height only (designer, 2026-11-01: balancing in the bulk left poses
    # "wider and shorter"): the standing frame stands as tall as the still.
    return float(got[0]) / ref[0]   # (factor divides: a larger scale is a smaller factor)


def build(hero, action, spec):
    board = np.asarray(Image.open(hs.SRC % spec["src"]).convert("RGB"))
    cols, i = spec["cols"], CELL_INSET
    cells = {}
    for (top, bottom), facing in zip(spec["rows"], spec["facings"]):
        for c in range(len(cols) - 1):
            cell = board[top + i:bottom - i + 1, cols[c] + i:cols[c + 1] - i + 1]
            cells[(facing, c)] = cut_cell(cell, spec.get("pockets", True), spec.get("haze", False),
                                          spec.get("narrow", 0), spec.get("drop_dark", False),
                                          spec.get("close", 0), spec.get("tol"), spec.get("haze_dark"),
                                          spec.get("glow", False), spec.get("glow_edge", 0),
                                          spec.get("streaks", False), spec.get("halo", False))
    n = len(cols) - 1
    # A facing the board does not draw, shown with another's frames ("copy":
    # {missing: drawn}; Brad's block from behind is his front, designer
    # 2026-10-31).
    facings = list(spec["facings"])
    for dst, src in spec.get("copy", {}).items():
        for c in range(n):
            cells[(dst, c)] = cells[(src, c)]
        facings.append(dst)
    # The hero's scale: his standing front (the south row's first frame).
    box = cells[("south", 0)][1]
    factor = (box[3] - box[1]) / float(hs.HEIGHT)
    # Each facing then matches the hero's own still pose that way (his
    # sheet's column 0), so nothing jumps when the action starts or ends:
    # the boards draw some poses bulkier or taller than his still sprite
    # (designer, 2026-10-31: "some of the models are much bigger").
    row_factor = {}
    for facing in facings:
        ref = still_size(hero, facing)
        got = mass(hs.resample(cells[(facing, 0)][0], factor))
        row_factor[facing] = factor * (match_scale(got, ref) if ref and got else 1.0)
    pix, soft, place = {}, {}, {}
    for (facing, c), (img, _) in cells.items():
        b0 = cells[(facing, 0)][1]
        anchor = ((b0[0] + b0[2]) / 2.0, float(b0[3]))   # the row's standing feet
        p = hs.resample(img, row_factor[facing])
        s = hs.soft_frame(img, row_factor[facing])
        sx, sy = p.shape[1] / float(img.width), p.shape[0] / float(img.height)
        pix[(facing, c)] = p
        soft[(facing, c)] = s
        place[(facing, c)] = (anchor[0] * sx, anchor[1] * sy)
    pix = {k: hs.vibrance(f) for k, f in pix.items()}
    pix = hs.tidy_palette(pix)
    # The cell: room for every frame round the anchor.
    need = 16
    for k, f in pix.items():
        ys, xs = np.nonzero(f[..., 3])
        if len(xs) == 0:
            continue
        ax, ay = place[k]
        side = max(ax - xs.min(), xs.max() + 1 - ax)
        need = max(need, 2 * side + 2, (ay - ys.min()) * ACTION_FLOOR / (ACTION_FLOOR - 1.0) + 2,
                   (ys.max() + 1 - ay) * ACTION_FLOOR + 2)
    C = int(np.ceil(need / 16.0) * 16)
    G = C - C // ACTION_FLOOR
    sheet = Image.new("RGBA", (C * n, C * len(hs.ROWS)))
    ssheet = Image.new("RGBA", (2 * C * n, 2 * C * len(hs.ROWS)))
    for r, facing in enumerate(hs.ROWS):
        for c in range(n):
            if (facing, c) not in pix:
                continue
            ax, ay = place[(facing, c)]
            f = Image.fromarray(pix[(facing, c)], "RGBA")
            s = soft[(facing, c)]
            kx, ky = s.width / float(f.width), s.height / float(f.height)
            # Each pasted cropped to what it draws (the cell round it can
            # reach past the sheet's cell).
            box = f.getbbox()
            sbox = s.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
            if box is None:
                continue
            sheet.alpha_composite(f.crop(box), (int(round(c * C + C / 2.0 - ax + box[0])),
                                                int(round(r * C + G - ay + box[1]))))
            ssheet.alpha_composite(s.crop(sbox), (int(round(2 * c * C + C - ax * kx + sbox[0])),
                                                  int(round(2 * r * C + 2 * G - ay * ky + sbox[1]))))
    out = OUT % (hero, action)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)
    sout = os.path.join(smooth_art.ROOT, "heroes", "%s_%s.png" % (hero, action))
    smooth_art.bleed(ssheet, 2).save(sout)
    print("%s %s: %d frames, cell %d, rows %s" % (hero, action, n, C, ", ".join(spec["facings"])))


def main():
    for (hero, action), spec in ACTIONS.items():
        build(hero, action, spec)


if __name__ == "__main__":
    main()
