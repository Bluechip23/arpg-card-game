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
    # The Defense cards (2026-10-30): a grey stone wall veined with blue
    # lightning, blue banners over the dots, shields at the corners, a
    # knight behind his shield catching arrows in the rules box's corner and
    # a skirmish below the text. Rules text is white on the stone. The wall
    # is broader than the others: the card rectangle is set so its art
    # window and type bar fall where the other boards' do.
    "defensive": {
        "src": "assets/sprites/paintings/card_defensive_board.webp",
        "card": (30, 103, 1014, 1480),
        "dots": [(443, 156), (513, 156), (582, 156)],
        "dot_r": 24,
        "bands": [
            (402, 128, 625, 183),
            (318, 200, 738, 292),
            (140, 780, 390, 842),
            (632, 780, 914, 842),
        ],
        "art": (276, 330, 772, 752),
        "art_keep": [],
        "logo_ring": ((520, 800), 101),
        "logo_boxes": [(428, 690, 614, 742), (494, 645, 548, 945)],
        "text": (140, 930, 510, 1080),
        "text_light": True,
        # This board's hourglass runs blue sand; the designer's hourglass is
        # the Instant card's brass one with gold sand (2026-10-30), set over
        # it: its crop's corner here, scaled to cover it cap to cap.
        "hourglass": {"at": (832, 60), "scale": 1.013},
        "numbers": [(88, 140, 202, 226), (884, 136, 946, 218)],
    },
    # The Utility cards (2026-10-30): deep green scale-work in a gilt frame
    # wound with ivy, emerald points, a potion medallion at the foot, a pack,
    # scroll, compass and potions in the rules box's corner. It has no type
    # bar and no logo: the art window runs taller and the game sets the logo
    # where the window meets the rules box (designer: "add the TO logo in
    # the middle"). Its green drop and hourglass are covered by the standard
    # ones. Rules text is white on the green.
    "utility": {
        "src": "assets/sprites/paintings/card_utility_board.webp",
        "card": (35, 67, 1008, 1429),
        "dots": [(442, 159), (513, 159), (582, 159)],
        "dot_r": 24,
        "bands": [
            (398, 122, 630, 194),
            (380, 206, 690, 309),
        ],
        "art": (176, 342, 870, 879),
        "art_keep": [],
        "text": (140, 995, 530, 1150),
        "text_light": True,
        # The white text's dark glow will not inpaint cleanly; the green
        # scale-work is even, so clean panel is laid over it: its top half
        # from above the text, its bottom half from below (clear of the
        # rocks at the picture's foot). (box, dy)
        "text_patch": [((140, 995, 530, 1073), -78), ((140, 1073, 530, 1150), 78)],
        "drop": {"at": (52, 28), "scale": 1.08},
        "hourglass": {"at": (816, 52), "scale": 1.059},
        "numbers": [(88, 172, 206, 252), (872, 132, 932, 214)],
    },
    # The Attack cards (2026-10-30): blood-red iron with steel spikes, a
    # bloodied great-axe down the left side, a war-painted berserker roaring
    # in the rules box's corner, a sword in a rock at the foot. Its middle
    # emblem (crossed swords in a ring) is painted out for the game's logo
    # and its blood drop and red-sand hourglass covered by the standard
    # ones (designer). The board is taller than the card's shape: its art
    # window's middle rows are squeezed (squeeze: y0, y1, new height) —
    # everything below them moves up 243 rows. Rules text white.
    "attack": {
        "src": "assets/sprites/paintings/card_attack_board.webp",
        "card": (63, 85, 898, 1497),
        "dots": [(429, 196), (505, 196), (583, 196)],
        "dot_r": 28,
        "bands": [
            (385, 160, 632, 234),
            (380, 250, 692, 338),
            (170, 930, 362, 1005),
            (598, 930, 842, 1005),
        ],
        "art": (268, 378, 764, 898),
        "art_keep": [],
        "logo_ring": ((485, 952), 100),
        "logo_boxes": [(462, 826, 508, 870), (462, 1030, 508, 1080)],
        "text": (165, 1078, 485, 1222),
        "text_light": True,
        "drop": {"at": (64, 61), "scale": 1.0},
        "hourglass": {"at": (717, 82), "scale": 1.12},
        "numbers": [(96, 192, 207, 270), (776, 168, 836, 254)],
        "squeeze": (420, 860, 197),
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


# The standard drop and hourglass (designer, 2026-10-30): the Instant
# card's, cut by GrabCut / their traced outline (tools/cut_card_badges.py),
# set over a board that paints its own.
BADGE_SRC = "assets/sprites/paintings/card_instant_board.webp"


def paste_badge(rgb, kind, spec):
    from cut_card_badges import DROP_BOX, HOURGLASS_BOX, drop_mask, hourglass_mask
    board = np.asarray(Image.open(BADGE_SRC).convert("RGB"))
    x0, y0, x1, y1 = HOURGLASS_BOX if kind == "hourglass" else DROP_BOX
    crop = board[y0:y1, x0:x1].copy()
    mask = (hourglass_mask(crop) if kind == "hourglass" else drop_mask(crop)).astype(np.float32)
    k = spec["scale"]
    size = (round(crop.shape[1] * k), round(crop.shape[0] * k))
    crop = np.asarray(Image.fromarray(crop).resize(size, Image.LANCZOS)).astype(np.float32)
    a = cv2.GaussianBlur(cv2.resize(mask, size, interpolation=cv2.INTER_LINEAR), (0, 0), 0.8)[..., None]
    ax, ay = spec["at"]
    out = rgb.astype(np.float32)
    region = out[ay:ay + size[1], ax:ax + size[0]]
    out[ay:ay + size[1], ax:ax + size[0]] = region * (1 - a) + crop * a
    return out.clip(0, 255).astype(np.uint8)


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

    # The logo, across the window's foot, the type bar and the rules box
    # (a board without one gets the game's own on the spot it is given).
    if "logo_ring" in cfg:
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

    for (x0, y0, x1, y1), dy in cfg.get("text_patch", []):
        # Lay clean panel from dy away over this part of the text box,
        # feathered at the box's outer edge.
        src_px = rgb.astype(np.float32)
        out = src_px.copy()
        m = np.zeros(shape, np.float32)
        X0, Y0, X1, Y1 = cfg["text"]
        m[Y0:Y1, X0:X1] = 1.0
        m = np.clip(cv2.GaussianBlur(m, (0, 0), 6) * m * 2.0, 0, 1)[..., None]
        out[y0:y1, x0:x1] = src_px[y0:y1, x0:x1] * (1 - m[y0:y1, x0:x1]) + src_px[y0 + dy:y1 + dy, x0:x1] * m[y0:y1, x0:x1]
        rgb = out.clip(0, 255).astype(np.uint8)

    # The rules text: dark ink on the parchment (or white on the stone).
    if cfg.get("text_light"):
        ink = rgb.min(axis=2) > 150
    else:
        ink = rgb.max(axis=2) < 95
    tx = box_mask(shape, cfg["text"]) & ink
    # (White text carries a soft dark shadow: take a wider rim with it.)
    tx = nd.binary_dilation(tx, iterations=8 if cfg.get("text_light") else 4) & box_mask(shape, cfg["text"])
    rgb = cv2.inpaint(rgb, tx.astype(np.uint8) * 255, 7, cv2.INPAINT_TELEA)

    for kind in ("drop", "hourglass"):
        if kind in cfg:
            rgb = paste_badge(rgb, kind, cfg[kind])

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


def squeeze_rows(rgba, y0, y1, new_h):
    """A board taller than the card's shape: rows y0..y1 (plain panel by
    then — the art window, its art painted out) resampled to new_h, the
    rest untouched, so nothing with a face is squashed."""
    band = cv2.resize(rgba[y0:y1], (rgba.shape[1], new_h), interpolation=cv2.INTER_AREA)
    return np.concatenate([rgba[:y0], band, rgba[y1:]], axis=0)


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
        if "squeeze" in cfg:
            rgba = squeeze_rows(rgba, *cfg["squeeze"])
        out = shrink(rgba, k)
        out.save(os.path.join(OUT_DIR, "frame_%s.png" % name))
        print("frame_%s: %dx%d (card at %s on the board, x%.4f)" % (name, out.width, out.height, cfg["card"], k))
        if first:
            cut_dots(cfg, k)
            first = False


if __name__ == "__main__":
    main()
