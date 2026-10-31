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
CELL_INSET = 4          # px kept clear of the grid lines

# Per hero and action: the board, its grid (column lines; each row's top and
# bottom line) and the facing each row draws.
ACTIONS = {
    # 2026-10-31: Brad's jumping overhead smash — crouch, leap with both
    # fists raised, slam down in a burst of sparks and dust.
    ("brad", "attack"): {
        "src": "brad_attack_board.webp",
        "cols": [117, 295, 471, 647, 827, 1002, 1179, 1356, 1528],
        "rows": [(53, 271), (271, 485), (485, 685), (685, 894)],
        "facings": ["south", "north", "west", "east"],
    },
    # 2026-10-31: Brad's block — stone encases him from the feet up ("The
    # Thing" style), the glowing feather showing through. No back view.
    ("brad", "block"): {
        "src": "brad_block_board.webp",
        "cols": [119, 274, 429, 586, 742, 898, 1055, 1211, 1367, 1525, 1682, 1839, 1992],
        "rows": [(53, 228), (235, 409), (416, 591)],
        "facings": ["south", "west", "east"],
    },
}


def cut_cell(cell):
    """One cell's figure (and its dust) on transparency, cell-sized, plus
    the kept pixels' box."""
    import cv2
    rgba = hs.cut_opaque_cell(cell)
    solid = (rgba[..., 3] > 0).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(solid, connectivity=8)
    keep = np.zeros(solid.shape, bool)
    for k in range(1, n):
        if stats[k][4] >= ACTION_KEEP_PX:
            keep |= lab == k
    rgba[~keep] = 0
    ys, xs = np.nonzero(keep)
    return Image.fromarray(rgba, "RGBA"), (xs.min(), ys.min(), xs.max() + 1, ys.max() + 1)


def build(hero, action, spec):
    board = np.asarray(Image.open(hs.SRC % spec["src"]).convert("RGB"))
    cols, i = spec["cols"], CELL_INSET
    cells = {}
    for (top, bottom), facing in zip(spec["rows"], spec["facings"]):
        for c in range(len(cols) - 1):
            cell = board[top + i:bottom - i + 1, cols[c] + i:cols[c + 1] - i + 1]
            cells[(facing, c)] = cut_cell(cell)
    n = len(cols) - 1
    # The hero's scale: his standing front (the south row's first frame).
    box = cells[("south", 0)][1]
    factor = (box[3] - box[1]) / float(hs.HEIGHT)
    pix, soft, place = {}, {}, {}
    for (facing, c), (img, _) in cells.items():
        b0 = cells[(facing, 0)][1]
        anchor = ((b0[0] + b0[2]) / 2.0, float(b0[3]))   # the row's standing feet
        p = hs.resample(img, factor)
        s = hs.soft_frame(img, factor)
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
