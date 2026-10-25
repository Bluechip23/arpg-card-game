#!/usr/bin/env python3
"""Cut the designer's Archer Rat out of its two sewer scenes.

Sources (assets/sprites/paintings/, .gdignore'd source art):
  archer_rat_standing.jpg — standing on its hind legs, four directions
    (back at the top, facing left, facing right drawing the bow, front with
    the bow). Used when it stands still (Idle).
  archer_rat_walking.jpg — on all fours, side views only (three face left,
    one faces right). Used while it moves (Walk); the scene has no front or
    back on all fours, so walking north / south shows the side walk too.

The rats stand on textured sewer floor, not a flat panel, so each one is
separated with OpenCV's GrabCut seeded by a box around it, then
box-filtered down DOWN x (the scenes' pixel blocks are ~4 source pixels:
the rat lands ~32 texels tall, a human's height in the game) with on/off
alpha, and packed bottom-centred into square cells in the Craftpix layout
SpriteEnemyFigure plays (rows front, back, left, right).

Output: assets/sprites/generated/sheets/archer_rat/Idle.png, Walk.png
Needs: pip install opencv-python-headless (a tool dependency, not the game's)
Run: python3 tools/cut_archer_rat.py
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import smooth_art  # noqa: E402  (the smooth, non-pixelated sheets)

SRC = "assets/sprites/paintings/archer_rat_%s.jpg"
OUT = "assets/sprites/generated/sheets/archer_rat"
DOWN = 4 * 0.5 / 0.9   # was 4, drawn x0.9: now the heroes' 64 texels a tile at BOARD_SCALE (2026-10-25)

# GrabCut boxes (x0, y0, x1, y1) around each rat in the 1408x768 scenes.
STANDING = {
    "back": (640, 135, 775, 275),
    "left": (325, 325, 478, 455),
    "right": (932, 318, 1090, 450),
    "front": (625, 510, 800, 645),
}
# All fours: which way each one faces.
WALKING = [
    ((628, 150, 795, 272), "left"),
    ((318, 325, 478, 448), "right"),
    ((935, 330, 1100, 448), "left"),
    ((628, 527, 800, 648), "left"),
]


def cut(img: np.ndarray, box) -> np.ndarray:
    """GrabCut seeded by colour: the floor is green-leaning (G above R) and
    the scene's red arrows are pure red; the rat is purple-grey fur, pink
    skin and brown leather (R at or above G). Strongly green or arrow-red
    pixels start as sure floor, rat-coloured ones as probable rat, and
    GrabCut settles the edges between them."""
    x0, y0, x1, y1 = box
    b, g, r = [img[..., i].astype(int) for i in range(3)]
    mask = np.full(img.shape[:2], cv2.GC_BGD, np.uint8)
    inside = np.zeros(img.shape[:2], bool)
    inside[y0:y1, x0:x1] = True
    mask[inside] = cv2.GC_PR_BGD
    ratlike = (r >= g + 2) | ((r + g + b) > 600)          # warm or near-white (feathers)
    green = g > r + 6
    arrow = (r > 170) & (g < 90) & (b < 90)
    mask[inside & ratlike] = cv2.GC_PR_FGD
    # Anchor: rat-coloured pixels in the box's central ellipse are surely
    # rat (left alone, GrabCut can settle on "it's all floor").
    yy, xx = np.mgrid[0:img.shape[0], 0:img.shape[1]]
    cx, cy = (x0 + x1) / 2.0, (y0 + y1) / 2.0
    core = ((xx - cx) / ((x1 - x0) * 0.28)) ** 2 + ((yy - cy) / ((y1 - y0) * 0.28)) ** 2 <= 1.0
    mask[core & ratlike & ~(green | arrow)] = cv2.GC_FGD
    mask[inside & (green | arrow)] = cv2.GC_BGD
    bgd = np.zeros((1, 65), np.float64)
    fgd = np.zeros((1, 65), np.float64)
    cv2.grabCut(img, mask, None, bgd, fgd, 10, cv2.GC_INIT_WITH_MASK)
    fg = np.where((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 1, 0).astype(np.uint8)
    # Tidy: open away specks, keep the pieces of real size (the bow or an
    # arrow can be its own piece), then fill holes inside the outline.
    fg = cv2.morphologyEx(fg, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
    n, labels, stats, _ = cv2.connectedComponentsWithStats(fg, 8)
    if n > 1:
        biggest = int(stats[1:, cv2.CC_STAT_AREA].max())
        keep = np.zeros_like(fg)
        for i in range(1, n):
            if stats[i, cv2.CC_STAT_AREA] >= biggest * 0.04:
                keep[labels == i] = 1
        fg = keep
    holes = fg.copy()
    ff = np.zeros((holes.shape[0] + 2, holes.shape[1] + 2), np.uint8)
    cv2.floodFill(holes, ff, (0, 0), 1)
    fg = fg | (1 - holes)
    # No green anywhere on the rat: a pale moss patch GrabCut kept goes.
    fg[(g > r + 2) & (g > b + 10)] = 0
    rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)[y0:y1, x0:x1]
    a = fg[y0:y1, x0:x1].astype(float)
    rgba = np.zeros((y1 - y0, x1 - x0, 4), float)
    rgba[..., :3] = rgb
    rgba[..., 3] = a
    return rgba


def downscale(rgba: np.ndarray) -> np.ndarray:
    if DOWN != int(DOWN):
        # Premultiplied box resample by a fractional factor, then on/off alpha.
        img = Image.fromarray(np.dstack([np.clip(rgba[..., :3], 0, 255),
                                         np.clip(rgba[..., 3:4] * 255, 0, 255)]).astype(np.uint8), "RGBA")
        size = (max(1, round(img.width / DOWN)), max(1, round(img.height / DOWN)))
        small = np.asarray(img.convert("RGBa").resize(size, Image.BOX).convert("RGBA")).copy()
        small[..., 3] = np.where(small[..., 3] >= 128, 255, 0)
        return small
    h, w, _ = rgba.shape
    h2, w2 = h // DOWN, w // DOWN
    a = rgba[:h2 * DOWN, :w2 * DOWN].reshape(h2, DOWN, w2, DOWN, 4)
    cover = a[..., 3].sum((1, 3))
    rgb = (a[..., :3] * a[..., 3:4]).sum((1, 3)) / np.maximum(cover, 1e-6)[..., None]
    out = np.zeros((h2, w2, 4), np.uint8)
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[..., 3] = np.where(cover / (DOWN * DOWN) >= 0.5, 255, 0)
    return out


def trim(fr: np.ndarray) -> np.ndarray:
    ys, xs = np.where(fr[..., 3] > 0)
    return fr[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def frame(img, box) -> np.ndarray:
    return trim(downscale(cut(img, box)))


def pack(rows, cell, cols, pick) -> Image.Image:
    s = np.zeros((cell * 4, cell * cols, 4), np.uint8)
    for ri, row in enumerate(rows):
        for ci in range(cols):
            f = pick(row, ci)
            fh, fw = f.shape[:2]
            y = ri * cell + cell - 1 - fh
            x = ci * cell + (cell - fw) // 2
            s[y:y + fh, x:x + fw] = f
    return Image.fromarray(s, "RGBA")


def soft(img, box) -> Image.Image:
    """The smooth version of a frame (smooth_art): DOWN lands on 64 texels a
    tile at BOARD_SCALE; this on SMOOTH_DENSITY."""
    return smooth_art.trim(smooth_art.resample(cut(img, box), DOWN * 64.0 / smooth_art.SMOOTH_DENSITY))


def main() -> None:
    stand = cv2.imread(SRC % "standing")
    walk = cv2.imread(SRC % "walking")
    _build(stand, walk, frame, lambda f: f[:, ::-1], OUT, pack)
    _build(stand, walk, soft, lambda f: f.transpose(Image.FLIP_LEFT_RIGHT),
           os.path.join(smooth_art.ROOT, "sheets", "archer_rat"), smooth_art.pack)


def _build(stand, walk, frame, flip, OUT, pack) -> None:
    size = lambda f: (f.shape[1], f.shape[0]) if hasattr(f, "shape") else f.size
    idle = {k: frame(stand, b) for k, b in STANDING.items()}
    left_walk = []
    for box, faces in WALKING:
        f = frame(walk, box)
        left_walk.append(f if faces == "left" else flip(f))
    right_walk = [flip(f) for f in left_walk]
    # F, B, L, R. On all fours there is only the side view: walking toward or
    # away from the camera uses the left-facing walk.
    idle_rows = [[idle["front"]], [idle["back"]], [idle["left"]], [idle["right"]]]
    walk_rows = [left_walk, left_walk, left_walk, right_walk]
    cell = max(max(size(f)) for row in idle_rows + walk_rows for f in row) + 2
    os.makedirs(OUT, exist_ok=True)
    pack(idle_rows, cell, 1, lambda row, ci: row[0]).save(os.path.join(OUT, "Idle.png"))
    n = len(left_walk)
    pack(walk_rows, cell, n, lambda row, ci: row[ci % len(row)]).save(os.path.join(OUT, "Walk.png"))
    print("archer_rat: cell %d px, %d walk frames -> %s" % (cell, n, OUT))


if __name__ == "__main__":
    main()
