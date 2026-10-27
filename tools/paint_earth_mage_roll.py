#!/usr/bin/env python3
"""Paint the Earth Mage's neck roll onto the views that lack it.

The designer's druid board (2026-10-27, earth_mage_druid_source.png) shows a
rolled brown branch lying round the back of his neck only in the front view
(its two ends come forward over the shoulders; it never crosses the throat).
The designer asked for it in every view, round the back of the neck and not
the front: across the nape in the back view, and from behind the neck down
over the near shoulder in each side view. Drawn here as a shaded rope in the
front roll's own palette (light top, darker underside, dark seams between the
coils, a dark rim), 8x supersampled and box-filtered down so it sits in the
painting. Writes earth_mage_druid_board.png, which tools/cut_pose_boards.py cuts.

Run: python3 tools/paint_earth_mage_roll.py
"""
import numpy as np
from PIL import Image

SRC = "assets/sprites/paintings/earth_mage_druid_source.png"
OUT = "assets/sprites/paintings/earth_mage_druid_board.png"
SS = 8           # supersampling
WIDTH = 6.4      # rope thickness in board pixels (the front's roll, its lumps included)
COIL = 4.6       # board pixels between coil seams

# The front roll's palette (sampled from the board).
RIM = np.array([0x2a, 0x1a, 0x14], float)
DARK = np.array([0x5b, 0x33, 0x25], float)
MID = np.array([0xa6, 0x5e, 0x44], float)
LIGHT = np.array([0xdc, 0x96, 0x6c], float)
SEAM = np.array([0x45, 0x26, 0x1c], float)

# Control points in board pixels, per view (the board is 560x280).
PATHS = {
    "back": [(197, 73), (207, 67.5), (220, 65.5), (233, 67.5), (243, 73)],
    "left": [(406.5, 59), (405, 66), (400, 72.5), (393.5, 76.5)],   # faces left
    "right": [(499, 59), (500.5, 66), (505.5, 72.5), (512, 76.5)],  # faces right
}


def _spline(pts, n=400):
    """Catmull-Rom through the control points, ends clamped."""
    p = [np.array(pts[0], float)] + [np.array(q, float) for q in pts] + [np.array(pts[-1], float)]
    out = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for t in np.linspace(0, 1, n // (len(p) - 3), endpoint=False):
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                              + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(p[-2])
    return np.array(out)


def rope_layer(size, pts):
    """An RGBA layer (board size) holding the rope along `pts`."""
    w, h = size
    curve = _spline(pts) * SS
    seg = np.diff(curve, axis=0)
    seglen = np.linalg.norm(seg, axis=1)
    arc = np.concatenate([[0], np.cumsum(seglen)])
    x0, y0 = curve.min(axis=0) - WIDTH * SS
    x1, y1 = curve.max(axis=0) + WIDTH * SS
    x0, y0 = int(max(0, x0)), int(max(0, y0))
    x1, y1 = int(min(w * SS, x1)), int(min(h * SS, y1))
    ys, xs = np.mgrid[y0:y1, x0:x1]
    P = np.stack([xs + 0.5, ys + 0.5], -1).reshape(-1, 2)
    best_d = np.full(len(P), np.inf)
    best_s = np.zeros(len(P))
    best_side = np.zeros(len(P))
    for i in range(len(seg)):
        a, v = curve[i], seg[i]
        L2 = max(seglen[i] ** 2, 1e-9)
        t = np.clip(((P - a) @ v) / L2, 0, 1)
        q = a + t[:, None] * v
        d = np.linalg.norm(P - q, axis=1)
        better = d < best_d
        best_d[better] = d[better]
        best_s[better] = arc[i] + t[better] * seglen[i]
        cross = v[0] * (P[:, 1] - a[1]) - v[1] * (P[:, 0] - a[0])
        best_side[better] = np.sign(cross[better])
    # Lumpy, not a machined rope: the radius swells and narrows coil by coil.
    r = WIDTH * SS / 2 * (0.86 + 0.14 * np.cos(2 * np.pi * best_s / (COIL * SS)))
    inside = best_d <= r
    u = np.clip(best_d / r, 0, 1)                    # 0 centre .. 1 edge
    # Light from above: the side of the rope facing up is lit.
    up = best_side * (1 if curve[-1, 0] >= curve[0, 0] else -1)  # +1 below the curve
    shade = 0.55 - 0.45 * up * u                     # 0.1 underside .. 1 top
    col = np.where(shade[:, None] > 0.66, MID + (LIGHT - MID) * ((shade[:, None] - 0.66) / 0.34),
                   DARK + (MID - DARK) * (shade[:, None] / 0.66))
    # Coil seams: slanted dark bands across the rope.
    phase = (best_s / SS + up * u * 1.2) / COIL
    seam = (phase - np.floor(phase)) < 0.14
    col = np.where(seam[:, None], SEAM, col)
    col = np.where((u > 0.84)[:, None], RIM, col)
    a = inside.astype(float)
    layer = np.zeros((h * SS, w * SS, 4))
    sub = np.concatenate([col * a[:, None], a[:, None] * 255], 1).reshape(y1 - y0, x1 - x0, 4)
    layer[y0:y1, x0:x1] = sub
    # Box down (premultiplied).
    small = layer.reshape(h, SS, w, SS, 4).mean(axis=(1, 3))
    return small


def main():
    board = np.asarray(Image.open(SRC).convert("RGB")).astype(float)
    h, w, _ = board.shape
    for name, pts in PATHS.items():
        lay = rope_layer((w, h), pts)
        alpha = lay[..., 3:4] / 255.0
        board = board * (1 - alpha) + lay[..., :3]
    Image.fromarray(np.clip(board, 0, 255).round().astype(np.uint8)).save(OUT)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
