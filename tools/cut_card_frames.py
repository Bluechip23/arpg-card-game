#!/usr/bin/env python3
"""Cut the designer's card frames (one board per card type) into blank
frames the card face draws behind its own text.

Each board is a whole painted card: the frame, with a sample card's name,
art, type line, rules text, tempo dots, costs and the game's logo on it.
Everything the game draws itself is painted out of it:
  - the name, the type-line words and the tempo dots — their whole band,
    row by row, blended across from the bar on either side of it (the bars
    are horizontal, so the band carries straight through);
  - the sample art — the art window filled row by row from its dark sides;
  - the logo — the same, across the window's foot, the type bar and the
    top of the rules box (the game draws its own logo over the spot);
  - the rules text and the cost numbers — inpainted from the parchment /
    the drop and hourglass round them (the drop and hourglass stay painted
    on the frame; the game writes the costs over them).
The board's black ground is cleared by a flood fill in from its edge.

Output, per type: assets/textures/cards/frame_<type>.png — the whole board
at CARD_SCALE texels a card pixel (mipmapped, shrunk smoothly in game) —
and, from the first board, dot_gold.png / dot_dark.png, the tempo dots.
CardUI.FRAMES says where on the card each frame sits (its card rect).
Run: python3 tools/cut_card_frames.py
"""
import os

import cv2
import numpy as np
from PIL import Image
from scipy import ndimage as nd

OUT_DIR = "assets/textures/cards"
CARD_W = 150          # the card face's width in game (CardUI.CARD_W)
CARD_SCALE = 2        # texels a card pixel in the saved frame

FRAMES = {
    "instant": {
        "src": "assets/sprites/paintings/card_instant_board.webp",
        # The card's own rectangle on the board (x0, y0, x1, y1): the gold
        # frame's outer edge. Feathers, drop and hourglass hang outside it.
        "card": (37, 105, 1006, 1460),
        "dots": [(445, 158), (515, 158), (583, 158)],
        "dot_r": 24,
        # Bands painted out whole, row by row: the dots' strip, the name,
        # and the type line's two words.
        "bands": [
            (402, 133, 628, 184),
            (250, 207, 588, 292),
            (125, 778, 312, 838),
            (632, 778, 922, 838),
        ],
        "art": (280, 332, 772, 754),
        # The frame's diamond ornament dips into the art's top-right corner.
        "art_keep": [(737, 318, 44)],
        # The logo: its ring (centre, radius), cross-guard and blade boxes.
        "logo_ring": ((519, 797), 101),
        "logo_boxes": [(428, 682, 614, 737), (494, 638, 548, 950)],
        "text": (138, 900, 515, 1075),
        "numbers": [(55, 140, 200, 240), (875, 145, 950, 240)],
    },
    # Every card with an upkeep (2026-10-30): dark amethyst-shot stone, a
    # violet vortex behind the drop, a mind-mage with glowing eyes in the
    # rules box's corner. Rules text is white on the stone.
    "maintain": {
        "src": "assets/sprites/paintings/card_maintain_board.webp",
        "card": (34, 105, 1008, 1467),
        "dots": [(442, 151), (513, 151), (583, 151)],
        "dot_r": 24,
        "bands": [
            (400, 126, 628, 177),
            (318, 200, 732, 290),
            (125, 778, 354, 840),
            (632, 778, 922, 840),
        ],
        "art": (280, 330, 772, 754),
        "art_keep": [(748, 316, 44)],
        "logo_ring": ((517, 790), 101),
        "logo_boxes": [(428, 680, 614, 735), (494, 638, 548, 945)],
        "text": (138, 935, 528, 1095),
        "text_light": True,
        "numbers": [(55, 120, 205, 235), (870, 115, 955, 235)],
    },
}


def row_fill(img, mask, pad=4):
    """Fill each row's masked runs by blending across from either side."""
    out = img.astype(np.float32).copy()
    h, w = mask.shape
    for y in range(h):
        xs = np.nonzero(mask[y])[0]
        if xs.size == 0:
            continue
        runs = np.split(xs, np.nonzero(np.diff(xs) > 1)[0] + 1)
        for run in runs:
            x0, x1 = run[0], run[-1]
            lx = slice(max(0, x0 - pad), x0)
            rx = slice(x1 + 1, min(w, x1 + 1 + pad))
            left = out[y, lx].mean(axis=0) if x0 > 0 else None
            right = out[y, rx].mean(axis=0) if x1 + 1 < w else None
            if left is None:
                left = right
            if right is None:
                right = left
            n = x1 - x0 + 1
            t = (np.arange(n) + 1) / (n + 1)
            out[y, x0:x1 + 1] = left[None, :] * (1 - t[:, None]) + right[None, :] * t[:, None]
    return out.clip(0, 255).astype(np.uint8)


def box_mask(shape, box):
    m = np.zeros(shape, bool)
    x0, y0, x1, y1 = box
    m[y0:y1, x0:x1] = True
    return m


def blank(cfg):
    rgb = np.asarray(Image.open(cfg["src"]).convert("RGB")).copy()
    shape = rgb.shape[:2]
    yy, xx = np.mgrid[0:shape[0], 0:shape[1]]

    # The sample art: the whole window, row by row from its dark sides ...
    src = rgb.copy()
    rgb = row_fill(rgb, box_mask(shape, cfg["art"]))
    # ... then the ornament put back: its pixels inside its diamond that are
    # not the art's reds.
    r_, g_ = src[..., 0].astype(int), src[..., 1].astype(int)
    red = (r_ > 90) & (r_ > g_ * 2)
    for cx, cy, r in cfg.get("art_keep", []):
        keep = ((np.abs(xx - cx) + np.abs(yy - cy)) <= r) & ~red
        keep = nd.binary_opening(keep, iterations=1)
        rgb[keep] = src[keep]

    # The logo, across the window's foot, the type bar and the rules box.
    (cx, cy), r = cfg["logo_ring"]
    logo = (xx - cx) ** 2 + (yy - cy) ** 2 <= r * r
    for b in cfg["logo_boxes"]:
        logo |= box_mask(shape, b)
    rgb = row_fill(rgb, logo)

    # The dots' strip, the name and the type-line words: whole bands.
    bands = np.zeros(shape, bool)
    for b in cfg["bands"]:
        bands |= box_mask(shape, b)
    rgb = row_fill(rgb, bands)

    # The rules text: dark ink on the parchment (or white on the stone).
    if cfg.get("text_light"):
        ink = rgb.min(axis=2) > 150
    else:
        ink = rgb.max(axis=2) < 95
    tx = box_mask(shape, cfg["text"]) & ink
    tx = nd.binary_dilation(tx, iterations=4) & box_mask(shape, cfg["text"])
    rgb = cv2.inpaint(rgb, tx.astype(np.uint8) * 255, 7, cv2.INPAINT_TELEA)

    # The cost numbers: white glyphs with a thick black rim.
    num = np.zeros(shape, bool)
    for b in cfg["numbers"]:
        white = (rgb.min(axis=2) > 200) & box_mask(shape, b)
        num |= nd.binary_dilation(white, iterations=13) & box_mask(shape, b)
    rgb = cv2.inpaint(rgb, num.astype(np.uint8) * 255, 9, cv2.INPAINT_TELEA)
    return rgb


def ground_alpha(src_rgb, card):
    """The board's black ground, flood-filled in from the edge; the card's
    own rectangle is all frame (its dark bars must not leak away)."""
    dark = src_rgb.max(axis=2) <= 34
    x0, y0, x1, y1 = card
    dark[y0 + 6:y1 - 6, x0 + 6:x1 - 6] = False
    lab, _ = nd.label(dark)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    fg = ~bg
    fg = nd.binary_opening(fg, iterations=1)
    a = cv2.GaussianBlur(fg.astype(np.float32), (0, 0), 1.5) * fg
    return np.maximum(a, nd.binary_erosion(fg, iterations=3))


def shrink(rgba, k):
    img = Image.fromarray(rgba, "RGBA")
    size = (round(img.width * k), round(img.height * k))
    return img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def cut_dots(cfg, k):
    src = np.asarray(Image.open(cfg["src"]).convert("RGB"))
    r = cfg["dot_r"]
    for name, (dx, dy) in (("dot_gold", cfg["dots"][0]), ("dot_dark", cfg["dots"][1])):
        crop = src[dy - r:dy + r + 1, dx - r:dx + r + 1]
        yy, xx = np.mgrid[-r:r + 1, -r:r + 1]
        a = np.clip(r - 1.5 - np.sqrt(xx ** 2 + yy ** 2) + 1.0, 0, 1)
        rgba = np.dstack([crop, (a * 255).astype(np.uint8)])
        shrink(rgba, k).save(os.path.join(OUT_DIR, name + ".png"))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    first = True
    for name, cfg in FRAMES.items():
        src = np.asarray(Image.open(cfg["src"]).convert("RGB"))
        x0, _, x1, _ = cfg["card"]
        k = CARD_W * CARD_SCALE / float(x1 - x0)
        rgb = blank(cfg)
        alpha = ground_alpha(src, cfg["card"])
        rgba = np.dstack([rgb, (alpha * 255).astype(np.uint8)])
        out = shrink(rgba, k)
        out.save(os.path.join(OUT_DIR, "frame_%s.png" % name))
        print("frame_%s: %dx%d (card at %s on the board, x%.4f)" % (name, out.width, out.height, cfg["card"], k))
        if first:
            cut_dots(cfg, k)
            first = False


if __name__ == "__main__":
    main()
