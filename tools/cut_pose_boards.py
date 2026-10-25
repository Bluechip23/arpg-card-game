#!/usr/bin/env python3
"""Cut the designer's four-direction pose boards into the game's sheets.

Sources (assets/sprites/paintings/, .gdignore'd source art), 2026-10-23:
  frankenstein_board.jpg — Frankensteins Monster (the "ITS ALIVE!!!!!"
    summon): Down, Up, Left, Right views standing on a stone floor. Both of
    its side views face right; the right one is used, the left is its mirror.
  giant_beaver_board.jpg — the Giant Beaver: four still poses up on its hind
    legs (Idle), four movement poses on all fours (Walk), on a checkerboard.
  wyvern_board.webp — the Wyvern: Down, Up, Left, Right, on a checkerboard.
  ring_wraith_board.jpg — the Ring Wraiths (The Precious): mounted, front,
    back and a right-facing side, on a grey checkerboard.
  djinn_board.jpg (2026-10-24) — the Djinn, a blue genie in gold cuffs and
    chains on the same icy cave: two right-facing views, one left, a
    three-quarter back, his front with arms crossed ("facing down") and his
    back ("facing up"); cut like the penguin (his saturated blue is far
    from the ice's grey-blue).
  fire_frost_mage_board.jpg (2026-10-24) — the Ice Mage (a hooded frost
    mage with an ice-crystal spear) and the Fire Mage (a masked ninja with
    burning fists) on a snowfield. Top row: each mage facing right, then
    the ice mage facing left and the fire mage nearly frontal (its left is
    the right view mirrored); bottom row: both from the front, then the
    ice mage's back, a stray fire-mage back holding the ice spear (unused)
    and the fire mage's back. Cut like the penguin, with a snow hint too.
  earth_shock_mage_board.jpg (2026-10-25) — the Earth Mage (a bald, tattooed
    monk with a vine-wrapped staff) and the Spark Mage, the shock mage (a
    blond brawler with lightning in his fists), on the same snowfield: each
    facing right, then each facing left; both from the front, then two
    earth-mage backs (the first is used) and the spark mage's back.
  air_mage_board.jpg (2026-10-25) — the Air Mage (silver-haired, purple and
    white robes, wind round her hands) in four panels on a dungeon wall and
    wooden floor: right, left, front ("facing down"), back ("facing up").
  sanguine_penguin_board.jpg (2026-10-24) — Sanguine the blood penguin
    (Nine Ruins of Sanguine's summon) in a Spartan helm: three right-facing
    views and one left-facing (the board labels the third "left"; it faces
    right), his back (labelled "facing down") and his front ("facing up").
    He stands on a dark icy cave: the sky is as dark as his back and the ice
    as pale as his belly, so no colour rule parts them — "grabcut" boards
    are cut with OpenCV's GrabCut from the pose's box, the enclosed holes it
    leaves (the helm's eye slit) filled, and the shadow-blue ice under his
    feet trimmed.
The checkerboards are painted in (the boards are flat JPEG/WebP, not
transparent), so the background is whatever is neutral and checker-bright,
flood-filled in from each pose's box; the art's dark outline stops the fill.
The stone floor is textured, but never darker than ~60 where the outline is
~0, so its fill runs through anything brighter than the outline. Enclosed
background pockets (between a wing and the body, under an arm) are cut too,
specks and the boards' labels are dropped (only pieces near the size of the
creature survive).

Each pose is shrunk by one factor per creature — chosen so the front Idle
stands its "tiles" tall at DENSITY texels a tile (twice the world's 32: the
heroes' fineness; the game draws these sheets at scale 32 / DENSITY) — box-
filtered with on/off alpha, and packed bottom-centred into square cells in
the Craftpix layout SpriteEnemyFigure plays (rows front, back, left, right).
These boards have one frame a direction: Idle is the still pose; Walk is the
movement pose where there is one (the beaver), else the still pose again
(the figure bobs it in step while it moves).

Output: assets/sprites/generated/sheets/<creature>/{Idle,Walk}.png
Run: python3 tools/cut_pose_boards.py [creature ...]   (Pillow, numpy)
"""
import os
import sys
from collections import deque

import numpy as np
from PIL import Image

try:
    import cv2   # only the GrabCut boards need it
except ImportError:
    cv2 = None

SRC = "assets/sprites/paintings/%s"
OUT = "assets/sprites/generated/sheets/%s"
ROWS = ["front", "back", "left", "right"]

# Per creature: board, how its background is told apart, the front Idle's
# height in texels, and a box (x0, y0, x1, y1) around each pose. A pose given
# as ("mirror", other) is the other pose flipped.
BOARDS = {
    "frankenstein": {
        "src": "frankenstein_board.jpg", "bg": "stone", "tiles": 1.75,
        "Idle": {
            "front": (0, 96, 360, 720),
            "back": (360, 96, 720, 720),
            "right": (1060, 96, 1408, 720),
            "left": ("mirror", "right"),
        },
    },
    "giant_beaver": {
        "src": "giant_beaver_board.jpg", "bg": "checker_light", "tiles": 1.3,
        "Idle": {
            "front": (40, 50, 300, 392),
            "back": (395, 50, 625, 392),
            "left": (725, 50, 1045, 392),
            "right": (1050, 50, 1380, 392),
        },
        "Walk": {
            "front": (80, 482, 290, 732),
            "back": (410, 482, 625, 732),
            "left": (690, 482, 1042, 730),
            "right": (1044, 482, 1400, 730),
        },
    },
    "wyvern": {
        "src": "wyvern_board.webp", "bg": "checker_light", "tiles": 1.9,
        "Idle": {
            "front": (40, 0, 300, 286),
            "back": (310, 0, 580, 286),
            "left": (585, 0, 870, 278),
            "right": (872, 0, 1160, 278),
        },
    },
    "sanguine_penguin": {
        "src": "sanguine_penguin_board.jpg", "bg": "grabcut", "tiles": 1.15,
        "Idle": {
            "front": (900, 395, 1210, 760),
            "back": (180, 395, 520, 760),
            "right": (60, 30, 345, 385),
            "left": (1090, 30, 1408, 385),
        },
        # Boxes (within each pose's box) that are surely him: his flippers
        # and black back, whose colours the sky and ice share and whose
        # outline the board leaves open in places (measured).
        "fg": {
            "front": [(45, 215, 70, 285), (245, 215, 265, 285), (75, 200, 95, 320)],
            "back": [(55, 230, 85, 290), (245, 230, 275, 290)],
            "right": [(212, 215, 235, 250), (55, 180, 95, 280)],
            "left": [(25, 215, 45, 255), (150, 180, 210, 290)],
        },
    },
    "djinn": {
        "src": "djinn_board.jpg", "bg": "grabcut", "tiles": 1.8,
        # GrabCut drops his thin ponytail and tail wisps against the sky; all
        # of him is a strong blue or purple and the sky and ice are near grey,
        # so the cut grows out into any pixel this saturated touching it.
        "sat_grow": 55,
        "Idle": {
            "front": (255, 400, 450, 750),
            "back": (940, 395, 1170, 750),
            "right": (60, 30, 300, 342),
            "left": (790, 30, 1015, 342),
        },
    },
    "ice_mage": {
        "src": "fire_frost_mage_board.jpg", "bg": "grabcut", "snow": True, "tiles": 1.6,
        "feet_trim": False,   # her boots are the floor shadow's pale blue-grey
        "Idle": {
            "front": (265, 405, 460, 748),
            "back": (760, 425, 935, 735),
            "right": (105, 40, 375, 372),
            "left": (725, 40, 990, 372),
        },
        # Her spear's thin shaft vanishes against the snow, leaving its
        # crystal head adrift: lines along head and shaft that are surely
        # her (x0, y0, x1, y1, width; measured).
        "fg": {
            "right": [(238, 24, 206, 84, 4), (206, 84, 147, 218, 3)],
            "left": [(22, 24, 64, 96, 4), (64, 96, 118, 220, 3)],
        },
    },
    "fire_mage": {
        "src": "fire_frost_mage_board.jpg", "bg": "grabcut", "snow": True, "tiles": 1.6,
        "Idle": {
            "front": (485, 420, 675, 722),
            "back": (1180, 420, 1370, 722),
            "right": (425, 50, 640, 372),
            "left": ("mirror", "right"),
        },
    },
    "earth_mage": {
        "src": "earth_shock_mage_board.jpg", "bg": "grabcut", "snow": True, "tiles": 1.6,
        "drop_ice": True,   # nothing on him is ice blue: the snow between arm and staff goes
        "Idle": {
            "front": (245, 430, 470, 748),
            "back": (755, 425, 948, 722),
            "right": (90, 55, 345, 372),
            "left": (760, 55, 1010, 372),
        },
        # His vine staff is thin against the sky and snow: its curled head
        # and its shaft, surely his (boxes; lines x0, y0, x1, y1, width).
        "fg": {
            "right": [(212, 10, 248, 52), (226, 52, 200, 298, 6)],
            "left": [(5, 10, 35, 52), (28, 55, 47, 295, 6)],
            "front": [(188, 8, 218, 55), (202, 60, 192, 305, 6)],
            "back": [(8, 16, 34, 55), (25, 55, 30, 277, 6)],
        },
    },
    "spark_mage": {
        "src": "earth_shock_mage_board.jpg", "bg": "grabcut", "snow": True, "tiles": 1.6,
        "bright_grow": 120,   # the lightning round his fists
        "Idle": {
            "front": (465, 415, 690, 722),
            "back": (1160, 400, 1390, 722),
            "right": (410, 55, 645, 372),
            "left": (1105, 55, 1375, 372),
        },
    },
    "air_mage": {
        "src": "air_mage_board.jpg", "bg": "grabcut", "tiles": 1.6,
        "Idle": {
            "front": (375, 425, 590, 748),
            "back": (840, 425, 1035, 748),
            "right": (405, 55, 570, 365),
            "left": (840, 55, 1005, 365),
        },
    },
    "ring_wraith": {
        "src": "ring_wraith_board.jpg", "bg": "checker_grey", "tiles": 1.95,
        "Idle": {
            "front": (0, 40, 392, 730),
            "back": (392, 40, 770, 730),
            "right": (770, 40, 1408, 730),
            "left": ("mirror", "right"),
        },
    },
}

# Texels per tile the boards are cut at (designer, 2026-10-24: err on the
# side of under-pixelating what we make): twice the world's 32, the heroes'
# own fineness — one texel a screen pixel at the default zoom. Each board
# gives its front Idle's height in tiles; SpriteEnemyFigure draws these
# sheets at scale 32 / DENSITY.
DENSITY = 64

GROW = 3           # px the stone board's outline is thickened by to close its pinholes
HOLE_MIN = 100      # enclosed background pockets this big (source px) are cut too
KEEP_SHARE = 0.04   # pieces smaller than this share of the biggest are dropped (specks, labels)
_N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))


def _background_like(rgb: np.ndarray, kind: str) -> np.ndarray:
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    if kind == "stone":
        return lum > 35
    if kind == "checker_light":     # white and light-grey squares (and faint white smears)
        return (sat < 16) & (lum > 150)
    if kind == "checker_grey":      # mid-grey (~127) and light-grey (~185) squares
        return (sat < 12) & (lum > 108)
    raise ValueError(kind)


def _flood(mask: np.ndarray, seeds) -> np.ndarray:
    h, w = mask.shape
    out = np.zeros_like(mask)
    q = deque()
    for y, x in seeds:
        if mask[y, x] and not out[y, x]:
            out[y, x] = True
            q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in _N4:
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not out[ny, nx]:
                out[ny, nx] = True
                q.append((ny, nx))
    return out


def _components(mask: np.ndarray):
    h, w = mask.shape
    seen = np.zeros_like(mask)
    comps = []
    for y, x in zip(*np.nonzero(mask)):
        if seen[y, x]:
            continue
        seen[y, x] = True
        comp, q = [], deque([(y, x)])
        while q:
            cy, cx = q.popleft()
            comp.append((cy, cx))
            for dy, dx in _N4:
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        comps.append(comp)
    return comps


def _grow(mask: np.ndarray, steps: int) -> np.ndarray:
    out = mask.copy()
    for _ in range(steps):
        g = out.copy()
        g[1:] |= out[:-1]
        g[:-1] |= out[1:]
        g[:, 1:] |= out[:, :-1]
        g[:, :-1] |= out[:, 1:]
        out = g
    return out


def _cut_stone(rgb: np.ndarray, floor_like: np.ndarray, edge) -> np.ndarray:
    """The stone floor around a figure. Its black outline has pinholes the
    floor would leak through, so the outline is thickened GROW px to close
    them and the green skin (far greener than the grey-green floor) walls
    the fill too; the floor-coloured fringe the thickening kept is peeled
    off afterwards."""
    lum = rgb.mean(axis=2)
    green = rgb[..., 1] - np.maximum(rgb[..., 0], rgb[..., 2])
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    wall = _grow(lum < 35, GROW) | (green > 14)
    floor = _flood(floor_like & ~wall, edge)
    floor_coloured = (lum > 55) & (green < 9) & (sat < 50) & ~(lum < 35)
    for _ in range(GROW + 1):
        near = _grow(floor, 1) & ~floor
        floor |= near & floor_coloured
    return floor


GRABCUT_ITER = 10
HOLE_FILL_MAX = 400     # enclosed pockets this small are always the creature's
GRABCUT_MARGIN = 8      # px inside the pose's box the GrabCut rectangle starts
FEET_BAND = 0.10        # the bottom share of the figure where floor shadow is trimmed


def _cut_grabcut(rgb: np.ndarray, fg_boxes=(), sat_grow=0, snow=False, feet_trim=True,
                 drop_ice=False, bright_grow=0) -> np.ndarray:
    """Background mask by GrabCut from the box, enclosed holes filled, and
    the ice's shadow under the feet (cool, unsaturated) trimmed."""
    if cv2 is None:
        raise SystemExit("opencv-python is needed for GrabCut boards")
    h, w, _ = rgb.shape
    bgr = np.ascontiguousarray(rgb[..., ::-1].astype(np.uint8))
    # A head start, so GrabCut's colour models begin on the right side: the
    # near-black, even sky (his feathers are a good deal lighter) and the
    # cool mid-grey ice start as probable background, the rest of the box
    # as probable creature, the margin as background.
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    # Only what joins up with the box's edge: his pale flippers are ice-
    # coloured too, but the outline closes them in.
    edge = [(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)] + \
           [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)]
    sky = _flood((lum < 26) & (sat < 22), edge)
    ice = _flood((rgb[..., 2] - rgb[..., 0] > 25) & (sat < 65) & (lum > 70) & (lum < 180), edge)
    if snow:   # bright snow fields: near-white, little colour
        ice |= _flood((lum > 185) & (sat < 60), edge)
    mask = np.full((h, w), cv2.GC_BGD, np.uint8)
    m = GRABCUT_MARGIN
    mask[m:h - m, m:w - m] = cv2.GC_PR_FGD
    mask[(sky | ice) & (mask == cv2.GC_PR_FGD)] = cv2.GC_PR_BGD
    for hint in fg_boxes:
        if len(hint) == 5:   # a line (x0, y0, x1, y1, width): a staff, a spear shaft
            cv2.line(mask, hint[0:2], hint[2:4], int(cv2.GC_FGD), hint[4])
        else:
            x0, y0, x1, y1 = hint
            mask[y0:y1, x0:x1] = cv2.GC_FGD
    bgd, fgd = np.zeros((1, 65)), np.zeros((1, 65))
    cv2.setRNGSeed(0)   # GrabCut seeds its colour models randomly: keep the cut repeatable
    cv2.grabCut(bgr, mask, None, bgd, fgd, GRABCUT_ITER, cv2.GC_INIT_WITH_MASK)
    fg = (mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD)
    if sat_grow:
        seeds = list(zip(*np.nonzero(fg)))
        fg |= _flood((sat >= sat_grow) | fg, seeds)
    if bright_grow:
        # Thin bright strands (lightning) against the dark sky: grow into
        # bright pixels touching the cut, never into the snow.
        # Only bright pixels close to the dark sky (a strand of lightning is
        # wrapped in it; a field of snow is not).
        near_sky = _grow((lum < 35) & (sat < 30), 4)
        seeds = list(zip(*np.nonzero(fg)))
        fg |= _flood(((lum >= bright_grow) & near_sky & ~ice) | fg, seeds)
    # Holes: background not reachable from the box's edge — filled when small
    # (the penguin's eye slit) or not background-coloured; a big pocket of
    # sky or snow boxed in by an arm and a staff stays background.
    looks_bg = (lum < 26) & (sat < 22) | (rgb[..., 2] - rgb[..., 0] > 25) & (sat < 65) & (lum > 70)
    if snow:
        looks_bg |= (lum > 185) & (sat < 60)
    for comp in _components(~fg & ~_flood(~fg, edge)):
        pts = tuple(np.array(comp).T)
        if len(comp) <= HOLE_FILL_MAX or looks_bg[pts].mean() < 0.5:
            fg[pts] = True
    if drop_ice:
        # A figure with nothing ice-coloured or near-black on it: any big
        # patch of snow blue or night sky GrabCut kept (seen between an arm
        # and a staff) is background.
        ice_like = (rgb[..., 2] - rgb[..., 0] > 25) & (sat < 65) & (lum > 35)   # shadowed snow too
        ice_like |= (lum < 30) & (sat < 25)                                       # and the night sky
        for comp in _components(fg & ice_like):
            if len(comp) > HOLE_FILL_MAX:
                fg[tuple(np.array(comp).T)] = False
    if feet_trim:
        ys = np.nonzero(fg.any(axis=1))[0]
        band = int(ys.max() - FEET_BAND * (ys.max() - ys.min()))
        cool = (rgb[..., 2] >= rgb[..., 0]) & (sat < 45) & (lum > 50)
        fg[band:] &= ~cool[band:]
    return ~fg


def cut(board: Image.Image, box, kind: str, fg_boxes=(), sat_grow=0, snow=False,
        feet_trim=True, drop_ice=False, bright_grow=0) -> Image.Image:
    """The creature in `box`, full size, on transparency, cropped to itself."""
    rgb = np.asarray(board.crop(box).convert("RGB")).astype(int)
    h, w, _ = rgb.shape
    edge = [(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)] + \
           [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)]
    bg_like = _background_like(rgb, kind) if kind != "grabcut" else None
    if kind == "grabcut":
        bg = _cut_grabcut(rgb, fg_boxes, sat_grow, snow, feet_trim, drop_ice, bright_grow)
    elif kind == "stone":
        bg = _cut_stone(rgb, bg_like, edge)
    else:
        bg = _flood(bg_like, edge)
        for comp in _components(bg_like & ~bg):
            if len(comp) >= HOLE_MIN:
                bg |= _flood(bg_like, comp)
    solid = ~bg
    comps = _components(solid)
    biggest = max(len(c) for c in comps)
    keep = np.zeros_like(solid)
    for comp in comps:
        if len(comp) >= biggest * KEEP_SHARE:
            keep[tuple(np.array(comp).T)] = True
    ys, xs = np.nonzero(keep)
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    alpha = np.where(keep, 255, 0).astype(np.uint8)
    rgba = np.dstack([rgb.astype(np.uint8), alpha])[y0:y1, x0:x1]
    return Image.fromarray(rgba, "RGBA")


def shrink(img: Image.Image, factor: float) -> Image.Image:
    """Box-filter down by `factor` (premultiplied), then on/off alpha."""
    size = (max(1, round(img.width / factor)), max(1, round(img.height / factor)))
    small = img.convert("RGBa").resize(size, Image.BOX).convert("RGBA")
    a = np.asarray(small).copy()
    a[..., 3] = np.where(a[..., 3] >= 128, 255, 0)
    return Image.fromarray(a, "RGBA")


def pack(frames: dict, cell: int) -> Image.Image:
    sheet = Image.new("RGBA", (cell, cell * 4))
    for r, d in enumerate(ROWS):
        f = frames[d]
        sheet.paste(f, ((cell - f.width) // 2, r * cell + cell - f.height), f)
    return sheet


def build(name: str, cfg: dict) -> None:
    board = Image.open(SRC % cfg["src"])
    full = {}
    for anim in ("Idle", "Walk"):
        if anim not in cfg:
            continue
        full[anim] = {}
        for d, box in cfg[anim].items():
            if box[0] != "mirror":
                full[anim][d] = cut(board, box, cfg["bg"], cfg.get("fg", {}).get(d, ()),
                                    cfg.get("sat_grow", 0), cfg.get("snow", False),
                                    cfg.get("feet_trim", True), cfg.get("drop_ice", False),
                                    cfg.get("bright_grow", 0))
        for d, box in cfg[anim].items():
            if box[0] == "mirror":
                full[anim][d] = full[anim][box[1]].transpose(Image.FLIP_LEFT_RIGHT)
    if "Walk" not in full:
        full["Walk"] = full["Idle"]
    factor = full["Idle"]["front"].height / float(round(cfg["tiles"] * DENSITY))
    small = {a: {d: shrink(f, factor) for d, f in fs.items()} for a, fs in full.items()}
    cell = max(max(f.width, f.height) for fs in small.values() for f in fs.values()) + 2
    os.makedirs(OUT % name, exist_ok=True)
    for anim, fs in small.items():
        pack(fs, cell).save(os.path.join(OUT % name, anim + ".png"))
    dims = ", ".join("%s %dx%d" % (d, f.width, f.height) for d, f in small["Idle"].items())
    print("%-13s ÷%.1f, %d-px cells: %s" % (name, factor, cell, dims))


def main() -> None:
    names = sys.argv[1:] or list(BOARDS)
    for n in names:
        build(n, BOARDS[n])


if __name__ == "__main__":
    main()
