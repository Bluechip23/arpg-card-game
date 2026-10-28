#!/usr/bin/env python3
"""Assemble Stephen's pose board from the designer's two images (2026-10-28).

stephen_v2_source.png: the new Stephen — a fur-collared ranger with an axe
and bow on his back and a bear's arm for his left — four poses on black:
front (top left), back (top right), and two side views. The lower-left side
view faces right but shows the bear arm, which belongs on his left side
(designer: "the bear arm is not supposed to be there"); the lower-right one
faces left and shows it rightly. stephen_v2_right.png is the right-facing
view as it should be (his human right arm), drawn smaller.

This scales the right view to the board's side poses (by figure height, the
axe included) and sets it in place of the lower-left pose, feet on the same
line, so every pose is cut from one board at one scale. The board draws its
side poses ~16% larger than the front and back, so both side poses are then
brought to the front's height (he would grow every time he turned). Writes
stephen_v2_board.png, which tools/cut_hero_sprites.py cuts.

Run: python3 tools/build_stephen_board.py
"""
import numpy as np
from PIL import Image

SRC = "assets/sprites/paintings/stephen_v2_source.png"
RIGHT = "assets/sprites/paintings/stephen_v2_right.png"
OUT = "assets/sprites/paintings/stephen_v2_board.png"
LIT = 18                      # brighter than this (max channel) is figure, not the black
FRONT = (0, 0, 247, 284)          # the front pose: the height every pose matches
WRONG_SIDE = (0, 284, 247, 627)   # the lower-left pose (its bear arm on the wrong side)
OTHER_SIDE = (247, 284, 495, 627)  # the lower-right pose: the side poses' height


def bbox(a):
    ys, xs = np.nonzero(a.max(axis=2) > LIT)
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def main():
    board = np.asarray(Image.open(SRC).convert("RGB")).copy()
    x0, y0, x1, y1 = WRONG_SIDE
    wx0, wy0, wx1, wy1 = bbox(board[y0:y1, x0:x1])
    feet_y = y0 + wy1                     # the wrong pose's feet line
    centre_x = x0 + (wx0 + wx1) / 2.0
    ox0, oy0, ox1, oy1 = OTHER_SIDE
    sx0, sy0, sx1, sy1 = bbox(board[oy0:oy1, ox0:ox1])
    side_h = sy1 - sy0                    # the board's side-pose height
    right = np.asarray(Image.open(RIGHT).convert("RGB"))
    rx0, ry0, rx1, ry1 = bbox(right)
    fig = Image.fromarray(right[ry0:ry1, rx0:rx1])
    k = side_h / float(ry1 - ry0)
    fig = fig.resize((round(fig.width * k), round(fig.height * k)), Image.LANCZOS)
    board[y0:y1, x0:x1] = 0               # the wrong pose goes
    px = round(centre_x - fig.width / 2.0)
    py = feet_y - fig.height
    f = np.asarray(fig)
    board[py:py + f.shape[0], px:px + f.shape[1]] = f
    # Both side poses down to the front's height, feet and centre kept.
    fx0, fy0, fx1, fy1 = bbox(board[FRONT[1]:FRONT[3], FRONT[0]:FRONT[2]])
    front_h = fy1 - fy0
    for (x0, y0, x1, y1) in (WRONG_SIDE, OTHER_SIDE):
        bx0, by0, bx1, by1 = bbox(board[y0:y1, x0:x1])
        pose = Image.fromarray(board[y0 + by0:y0 + by1, x0 + bx0:x0 + bx1])
        k2 = front_h / float(by1 - by0)
        small = np.asarray(pose.resize((round(pose.width * k2), round(pose.height * k2)), Image.LANCZOS))
        cx = x0 + (bx0 + bx1) / 2.0
        feet = y0 + by1
        board[y0:y1, x0:x1] = 0
        qx = round(cx - small.shape[1] / 2.0)
        board[feet - small.shape[0]:feet, qx:qx + small.shape[1]] = small
        print("side pose at x%d: x%.3f to the front's %d px" % (x0, k2, front_h))
    Image.fromarray(board).save(OUT)
    print("right view x%.2f -> %dx%d at (%d, %d); wrote %s" % (k, fig.width, fig.height, px, py, OUT))


if __name__ == "__main__":
    main()
