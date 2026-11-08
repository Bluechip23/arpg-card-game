#!/usr/bin/env python3
"""Cut the designer's hero action boards (basic attack, basic block, spell
card cast) into the sheets SpriteFigure plays for them.

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
STREAK_PIECE = 150      # ...every piece of it this big (a boot parted from its leg)...
STREAK_KEEP = 9         # ...grown back this much...
STREAK_DARK = 120       # ...and outside it, pixels darker than this go
CELL_INSET = 4          # px kept clear of the grid lines
FACE_REACH = 16         # "face": ground-dark px this close to the glowing eyes...
FACE_RAYS = 16          # ...with the figure met by this many rays of FACE_RAYS...
FACE_SHUT = 11
FACE_RAY_LEN = 24       # ...within this many px, are the face inside the hood
FACE_DARK = 45          # (and no channel brighter than this)
DARK_PIECE = 40         # "drop_dark": a piece whose 90th-percentile channel is under this goes
FADE_FULL = 200         # "fade": an effect's light is solid from this much over the ground (max channel)
FADE_DARK = 24          # ...and the plain ground shut in with it adds under this...
FADE_OPEN = 3           # ...in patches at least this wide

# Per hero and action: the board, its grid (column lines; each row's top and
# bottom line) and the facing each row draws; optionally "pockets": False
# and "haze": True, "narrow": px for cut_hero_sprites.cut_opaque_cell;
# "drop_dark": True drops unlit pieces (floor shadows); "close": px fills
# notches in the silhouette that narrow. "cols" may be a list a row (a
# board with no cell rules, cut in the gaps between its frames), and "dx"
# per facing a px a frame that the board sets the figure further right in
# its cell than the row's first (so he stays put). "fade": the hue(s) of
# an effect's light (fade_light) in "fade_frames", solid from "fade_full",
# only "fade_band" px deep when set.
ACTIONS = {
    # 2026-10-31: Brad's jumping overhead smash — crouch, leap with both
    # fists raised, slam down in a burst of sparks and dust.
    ("brad", "attack"): {
        "src": "brad_attack_board.webp",
        # The board draws him smaller from the crouch on: his head a tenth
        # smaller as he crouches, a fifth in the leap and the landing (front),
        # less in the back and side views. Scaled back frame by frame.
        "frame_scale": {
            "south": [1.0, 1.08, 1.10, 1.18, 1.18, 1.18, 1.20, 1.20],
            "north": [1.0, 1.04, 1.06, 1.10, 1.10, 1.10, 1.10, 1.10],
            "east": [1.0, 1.0, 1.04, 1.08, 1.08, 1.08, 1.09, 1.09],
            "west": [1.0, 1.0, 1.04, 1.08, 1.08, 1.08, 1.09, 1.09],
        },
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
        # His shirt and trousers are a few levels off the ground's black:
        # matched within 4 (as Ryan's), the ground clears and they stay
        # (designer, 2026-11-04: "parts of his body cropped out" facing
        # forward; the wider match and the armpit "grow" of 2026-11-02 ate
        # his shirt under the arm and his legs). The trapped-ground rule
        # still clears the gaps under his arms.
        "tol": 4,
        "pockets": False,   # the back of his neck is as dark as the ground...
        "narrow": 7,        # ...and the fill reaches it through a slit
        "squeeze": {"east": 0.90, "west": 0.90},   # his profiles drawn stockier than the still's
        "cols": [116, 293, 470, 649, 825, 1003, 1178, 1356, 1529],
        "rows": [(52, 266), (266, 481), (481, 684), (684, 902)],
        "facings": ["south", "north", "west", "east"],
    },
    # 2026-10-31: Stephen's defensive parry — two knives drawn and crossed
    # with a flash, then sheathed.
    ("stephen", "block"): {
        "src": "stephen_block_board.webp",
        "tol": 4,           # as his attack: his boots, legs and knife arm stay
        "haze": True,       # the flash's dark glow
        "streaks": True,    # ...and its dim arcs
        "squeeze": {"east": 0.85, "west": 0.85, "north": 0.90},   # his profiles and back drawn stockier than the still's
        "pockets": False,
        "narrow": 7,
        "cols": [115, 310, 519, 720, 924, 1130, 1333, 1530],
        "rows": [(52, 267), (267, 482), (482, 684), (684, 902)],
        "facings": ["south", "north", "west", "east"],
    },
    # 2026-11-02: Ryan's auto attack redrawn — four quick stabs, alternating
    # hands, twelve frames; front, back, left, right rows (number strips
    # between them).
    ("ryan", "attack"): {
        "src": "ryan_attack_board.webp",
        "tol": 4,           # his near-black clothes sit close to the ground's colour
        "pockets": False,   # near-black clothes on a near-black ground: the
        "narrow": 7,        # shadows between his straps are the ground's colour
        "close": 7,
        "cols": [109, 228, 343, 461, 579, 697, 816, 935, 1053, 1172, 1290, 1407, 1522],
        "rows": [(77, 288), (326, 529), (568, 757), (795, 984)],
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
    # 2026-11-02: Cory's aerial shadow kick combo, redrawn — a crouch, a
    # leap in a burst of dust, kicks trailing violet shadow, the spinning
    # kick (its cell drawn wider for the arc), and he lands.
    ("cory", "attack"): {
        "src": "cory_attack_board.webp",   # redrawn by the designer 2026-11-05
        # Below the waist he kicks on shadow legs as dark as the ground (2026-11-05:
        # "his body basically dissolves when he performs a kick"): a model matte
        # a cell (tools/make_mattes.py --hero cory_attack) keeps them solid.
        "matte": True,
        "pockets": False,   # his robe's dark folds by the hood are the ground's colour
        "narrow": 7,        # and the fill reaches them through slits
        "glow": "violet",   # the shadow smoke's faint haze fades out; its dark core stays solid
        "glow_frames": range(2, 9),   # the smoke is drawn from the leap to the last kick; he stands and lands without it (purple boots)
        "face": True,       # the face inside his hood is the ground's colour: kept round the eyes (fill_face)
        "cols": [113, 245, 373, 504, 637, 769, 903, 1036, 1176, 1308, 1440],
        "rows": [(58, 289), (289, 509), (509, 727), (727, 944)],
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

    # 2026-11-08: the spell card casts — every hero draws a glowing card
    # from his belt and casts it in his own effect; played for every Spell
    # card (SpriteFigure DRAWN_SPELL). The effects round the figure are the
    # spell's look and are kept whole.
    #
    # Brad: he flares up in orange fire swirls and thrusts the card out in
    # a burst (frame 7), settling in embers. His side rows turn round
    # mid-cast: the board's "Left" row faces left as he draws (1-5) but
    # thrusts the card out to the RIGHT (6-8), its "Right" row the other way
    # about. Mapped by the thrust, the cast's payoff, so the card goes toward
    # the target: "Left" plays facing east, "Right" facing west (and he
    # draws the card facing away, 1-5).
    ("brad", "cast"): {
        "src": "brad_cast_board.webp",
        "glow": "red",      # the fire's haze fades out (and the ground between its swirls clears)
        "glow_frames": range(4, 8),   # from the flare-up (frame 5) on
        "fade": "fire",     # the fire's haze, shut in between its rays and swirls, fades too
        "fade_frames": range(3, 8),   # from the card drawn (its glow) on
        "pockets": False,   # his dark pouches and trousers are near the ground's colour (as his smash)
        "narrow": 7,
        "cols": [131, 323, 514, 699, 885, 1072, 1259, 1465, 1658],
        "rows": [(82, 279), (288, 475), (483, 668), (677, 869)],
        "facings": ["south", "north", "east", "west"],
        # Each side row turns round mid-cast: "Left" faces left in 1-5 and
        # thrusts right in 6-8, "Right" the reverse. Rows are mapped by the
        # thrust (Left -> east) and frames 1-5 traded, so he faces his target
        # throughout (designer, 2026-11-08): east = Right 1-5 + Left 6-8,
        # west = Left 1-5 + Right 6-8.
        "splice": {"frames": range(0, 5), "swap": ("east", "west")},
    },
    # Jeremy: green-and-purple spirit swirls, ghostly purple skulls rise
    # behind him (5-7) and fade (8). No cell rules on the board. His side
    # rows face one way throughout ("Left" west, "Right" east), the card
    # held out before him; the skulls rise over his back.
    ("jeremy", "cast"): {
        "src": "jeremy_cast_board.webp",
        "close": 5,         # gaps between his dark trouser folds (as his attack)
        "fade": ("green", "violet"),   # the spirit smoke and the skulls' haze fade out
        "fade_frames": range(2, 8),
        "fade_full": 80,    # (only the dark haze: the skulls keep their shading)
        "cols": [[174, 356, 522, 702, 884, 1096, 1287, 1478, 1662],
                 [174, 357, 536, 726, 898, 1099, 1287, 1476, 1662],
                 [174, 349, 512, 687, 863, 1072, 1272, 1463, 1662],
                 [174, 351, 530, 721, 890, 1099, 1286, 1473, 1662]],
        # (his feet matched frame to frame: the skulls push him left on the
        # board from frame 6)
        "dx": {"south": [0, -2, 13, 12, 12, -26, -26, -29], "north": [0, -2, 0, -10, 1, -28, -26, -27],
               "west": [0, 5, 19, 22, 25, -4, -16, -17], "east": [0, 0, -1, -14, 2, -34, -36, -32]},
        "rows": [(111, 281), (286, 456), (462, 629), (634, 810)],
        "facings": ["south", "north", "west", "east"],
    },
    # Stephen: purple energy and a spectral bear (5-6), purple claw slashes
    # released (7). His side rows face one way throughout and release the
    # claws that way ("Left" west, "Right" east).
    ("stephen", "cast"): {
        "src": "stephen_cast_board.webp",
        "tol": 4,           # as his attack: his boots, legs and knife arm stay
        "fade": "violet",   # the energy, the bear and the claws are light
        "fade_frames": range(3, 7),
        "pockets": False,
        "narrow": 7,
        "cols": [110, 307, 506, 712, 910, 1122, 1329, 1572, 1764],
        "rows": [(89, 275), (279, 465), (469, 652), (657, 846)],
        "facings": ["south", "north", "west", "east"],
    },
    # Cory: a purple runic circle (5), a swirl (6), the card rises in a red
    # aura (7) and a grinning red shadow-face appears (8). No cell rules.
    # "Left" west, "Right" east, each facing its way to frame 7; frame 8 is
    # drawn alike in both rows: he faces right, the face to his left — before
    # him casting west (he has turned round), behind him casting east.
    ("cory", "cast"): {
        "src": "cory_cast_board.webp",
        "fade": ("violet", "red"),   # the runes and swirl, the red aura and the face are light
        "fade_frames": range(2, 8),
        "fade_band": 8,     # (their haze round him only: his robe takes their light)
        "drop_dark": True,  # the board's faint cell panels' edges
        "pockets": False,   # his robe's dark folds by the hood are the ground's colour
        "narrow": 7,
        "face": True,       # the face inside his hood (as his kick)
        "cols": [188, 390, 579, 779, 955, 1152, 1359, 1543, 1757],
        # (his feet matched frame to frame: the face pushes him right in frame 8)
        "dx": {"south": [0, -9, -6, -16, 1, -10, -14, -2], "north": [0, -7, -5, -16, 0, -10, -15, 1],
               "west": [0, -11, -7, -18, -1, -6, -12, 23], "east": [0, -10, -8, -19, -3, -11, -22, 18]},
        "rows": [(122, 307), (307, 487), (487, 657), (657, 841)],
        "facings": ["south", "north", "west", "east"],
    },
    # Ryan (the alchemist): the card becomes a purple flask set down in a
    # glowing ring (4-5), lifted in a swirl (6), thrown up in an arc (7),
    # bursting in a magenta starburst overhead (8). No cell rules (the
    # burst's top meets the row's rule on the board). "Left" west, "Right"
    # east; in frame 7 of each side row he looks back the other way as he
    # throws the flask up over his head.
    ("ryan", "cast"): {
        "src": "ryan_cast_board.webp",
        "tol": 4,           # his near-black clothes sit close to the ground's colour
        "fade": "violet",   # the ring, the swirl, the arc and the burst are light
        "fade_frames": range(2, 8),
        "fade_full": 80,    # (only the dark haze: the flask and the burst keep their shading)
        "drop_dark": True,  # the board's faint cell panels' edges
        "pockets": False,
        "narrow": 7,
        "close": 7,
        "cols": [192, 386, 581, 776, 970, 1164, 1359, 1554, 1748],   # (his frames sit at an even pitch)
        # (his feet matched frame to frame where they can be: side on, the
        # flask on the ground pushes him back from it, 4-7; front and back,
        # crouched over it and under the burst, he stands where the pitch has him)
        "dx": {"west": [0, 0, -4, 10, 19, -2, 3, 4], "east": [0, -5, -10, -21, -31, -26, -26, -15]},
        "rows": [(122, 307), (307, 487), (487, 657), (657, 841)],
        "facings": ["south", "north", "west", "east"],
    },
}


def fill_face(rgba, cell):
    """The face inside a hood (Cory's), painted as dark as the ground: in
    profile the hood opens to the side and the fill takes the face through
    the opening, leaving his eyes floating (designer, 2026-11-05). A dark
    pixel near the glowing eyes that the figure shuts in on most sides
    (FACE_SHUT of FACE_RAYS rays meet it within FACE_RAY_LEN) is the face;
    the ground in front of the hood is open on half its sides and stays."""
    import cv2
    rgb = cell[..., :3].astype(int)
    eye = (rgb[..., 2] >= 170) & (rgb[..., 1] >= 140) & (rgb[..., 0] <= 140) & (rgb[..., 2] - rgb[..., 0] >= 60)
    if eye.sum() < 3:
        return rgba
    disc = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * FACE_REACH + 1, 2 * FACE_REACH + 1))
    near = cv2.dilate(eye.astype(np.uint8), disc) > 0
    h, w = eye.shape
    angles = np.arange(FACE_RAYS) * (2 * np.pi / FACE_RAYS)
    for _ in range(3):
        solid = rgba[..., 3] > 0
        ys, xs = np.nonzero(near & ~solid & (rgb.max(axis=2) <= FACE_DARK))
        if len(ys) == 0:
            break
        hits = np.zeros(len(ys), int)
        for ang in angles:
            hit = np.zeros(len(ys), bool)
            for step in range(1, FACE_RAY_LEN + 1):
                px = np.round(xs + np.cos(ang) * step).astype(int)
                py = np.round(ys + np.sin(ang) * step).astype(int)
                inb = (px >= 0) & (px < w) & (py >= 0) & (py < h)
                hit |= inb & solid[np.clip(py, 0, h - 1), np.clip(px, 0, w - 1)]
            hits += hit
        shut = hits >= FACE_SHUT
        if not shut.any():
            break
        rgba[ys[shut], xs[shut], :3] = cell[ys[shut], xs[shut], :3]
        rgba[ys[shut], xs[shut], 3] = 255
    return rgba


def light_mask(rgb, hue):
    """The pixels painted as `hue` light on the dark ground (`hue`: a name,
    or a tuple of them)."""
    if isinstance(hue, (tuple, list)):
        m = np.zeros(rgb.shape[:2], bool)
        for one in hue:
            m |= light_mask(rgb, one)
        return m
    r, g, b = [rgb[..., i].astype(float) for i in range(3)]
    if hue == "violet":
        # Purple to magenta (Stephen's bear and claws, Cory's runes, Ryan's
        # flask and burst, Jeremy's skulls): red and blue both over green,
        # the blue at least 0.6 of the red (Cory's robe is a reddish mauve,
        # its blue barely over its green).
        rg, bg = r - g, b - g
        return (rg > 6) & (bg > 6) & (bg >= 0.6 * rg)
    if hue == "green":
        # Jeremy's spirit smoke: green leads (his robe is brown, his bones pale).
        return g - np.maximum(r, b) > 6
    if hue == "red":
        # Cory's shadow-face and aura: red leads, green and blue under 0.3
        # of it (his robe's mauve carries more of both).
        return (r - np.maximum(g, b) > 12) & (np.maximum(g, b) < 0.3 * r)
    if hue == "fire":
        # Orange to red: red leads, next to no blue (his red sleeves and the
        # brown leather carry as much blue as green; bright yellow-white
        # flame is solid anyway).
        return (r > 12) & (b < 0.1 * r) & (g < 0.65 * r)
    raise ValueError("no fade hue %r" % hue)


def fade_light(rgba, cell, hue, full, band=0):
    """An effect's light (Brad's fire: its swirls' haze, the glow round the
    burst) painted over the dark ground: the cut keeps it solid where the
    fill could not reach it (shut in between the rays and the swirls), a
    muddy dark-red block off the board. Every pixel of the effect's hue
    becomes see-through by how much light it adds over the ground (solid
    from `full` up), its colour unblended from the ground, so the haze
    fades into what it is drawn over and the bright flame stays."""
    rgb = cell[..., :3].astype(float)
    h, w = rgb.shape[:2]
    border = np.concatenate([rgb[:6].reshape(-1, 3), rgb[-6:].reshape(-1, 3),
                             rgb[:, :6].reshape(-1, 3), rgb[:, -6:].reshape(-1, 3)])
    ground = np.percentile(border, 25, axis=0)
    d = np.maximum(rgb - ground, 0)
    a = np.clip(d.max(axis=2) / float(full), 0.0, 1.0)
    on = light_mask(rgb, hue) & (rgba[..., 3] > 0) & (a < 1.0)
    if band:
        # Only the haze on the outside, `band` px deep: Cory's robe takes
        # the runes' violet light and his hood the aura's red, and deeper in
        # it is him (as his kick's smoke, GLOW_HAZE).
        import cv2
        k = np.ones((2 * band + 1, 2 * band + 1), np.uint8)
        on &= ~(cv2.erode((rgba[..., 3] > 0).astype(np.uint8), k) > 0)
    a_safe = np.maximum(a, 1e-3)[..., None]
    col = np.clip(ground + d / a_safe, 0, 255)
    out = rgba.copy()
    out[on, :3] = col[on].astype(np.uint8)
    out[on, 3] = np.minimum(out[on, 3], (a[on] * 255).astype(np.uint8))
    if band:
        return out   # (a hero as dark as the ground, Cory: his robe would go too)
    # The plain ground shut in with it (black specks between the burst's
    # rays): patches at least FADE_OPEN wide adding under FADE_DARK, open
    # onto what now shows through, go. (The figure's own dark outline is
    # thinner; his chain mail and trousers are lit more than that.)
    import cv2
    dark = (out[..., 3] == 255) & (d.max(axis=2) < FADE_DARK)
    dark = cv2.morphologyEx(dark.astype(np.uint8), cv2.MORPH_OPEN, np.ones((FADE_OPEN, FADE_OPEN), np.uint8))
    for _ in range(4):
        seen = cv2.dilate((out[..., 3] < 255).astype(np.uint8), np.ones((3, 3), np.uint8)) > 0
        n, lab = cv2.connectedComponents(dark, connectivity=4)
        hit = np.unique(lab[seen & (dark > 0)])
        hit = hit[hit > 0]
        if len(hit) == 0:
            break
        gone = np.isin(lab, hit)
        out[gone] = 0
        dark[gone] = 0
    return out


def cut_cell(cell, pockets=True, haze=False, narrow=0, drop_dark=False, close=0, tol=None, haze_dark=None, glow=False, glow_edge=0, streaks=False, halo=False,
             see_through=True, grow=False, face=False, matte=None, fade=None, fade_full=None, fade_band=0):
    """One cell's figure (and its dust) on transparency, cell-sized, plus
    the kept pixels' box. `matte` (a cell-sized bool mask from
    tools/make_mattes.py --hero): figure the colour rules cannot tell from
    the ground, kept solid in the board's own colour."""
    import cv2
    rgba = hs.cut_opaque_cell(cell, pockets, haze, narrow, tol, haze_dark, glow, glow_edge, see_through, grow)
    if face:
        rgba = fill_face(rgba, cell)
    if matte is not None:
        rgba[matte, :3] = cell[matte, :3]
        rgba[matte, 3] = 255
    if fade:
        rgba = fade_light(rgba, cell, fade, fade_full or FADE_FULL, fade_band)
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
            # Every thick piece is the body's: a boot the floor rules part
            # from the leg above it is a piece of its own (designer,
            # 2026-11-04: Stephen's parry "cropped out" from the front, his
            # boots gone), and an arc is too thin to leave one at all.
            core = np.isin(clab, 1 + np.nonzero(cst[1:, 4] >= STREAK_PIECE)[0]).astype(np.uint8)
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


def _cell_matte(spec, hero, action, facing, c, cell):
    """The cell's model matte when the board asks for one, else None."""
    if not spec.get("matte"):
        return None
    import make_mattes
    m = np.asarray(Image.open(make_mattes.hero_action_matte_path(hero, action, facing, c)).convert("L")) > 127
    if m.shape != cell.shape[:2]:
        raise ValueError("matte for %s %s %s %d is %s, cell %s" % (hero, action, facing, c, m.shape, cell.shape[:2]))
    # A piece on the cell's edge is the board's grid line or caption, not him.
    import cv2
    n, lab = cv2.connectedComponents(m.astype(np.uint8), connectivity=8)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    return m & ~np.isin(lab, edge[edge > 0])


def build(hero, action, spec):
    board = np.asarray(Image.open(hs.SRC % spec["src"]).convert("RGB"))
    i = CELL_INSET
    cells = {}
    for r, ((top, bottom), facing) in enumerate(zip(spec["rows"], spec["facings"])):
        # ("cols": one list for the board, or one a row where the board
        # rules no cells and the gaps between the frames wander.)
        cols = spec["cols"][r] if isinstance(spec["cols"][0], (list, tuple)) else spec["cols"]
        for c in range(len(cols) - 1):
            cell = board[top + i:bottom - i + 1, cols[c] + i:cols[c + 1] - i + 1]
            # ("glow_frames": the frames the glow is drawn in; the rest, a
            # standing pose or a landing with no smoke, are cut plain.)
            glow = spec.get("glow", False) if c in spec.get("glow_frames", range(c + 1)) else False
            cells[(facing, c)] = cut_cell(cell, spec.get("pockets", True), spec.get("haze", False),
                                          spec.get("narrow", 0), spec.get("drop_dark", False),
                                          spec.get("close", 0), spec.get("tol"), spec.get("haze_dark"),
                                          glow, spec.get("glow_edge", 0),
                                          spec.get("streaks", False), spec.get("halo", False),
                                          spec.get("see_through", True), spec.get("grow", False),
                                          spec.get("face", False), _cell_matte(spec, hero, action, facing, c, cell),
                                          spec.get("fade") if c in spec.get("fade_frames", range(c + 1)) else None,
                                          spec.get("fade_full"), spec.get("fade_band", 0))
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
    # A row the board draws stockier than the hero's still pose that way
    # (Stephen's profiles and back) stands his height and is drawn
    # narrower: "squeeze" (designer, 2026-11-04: the halfway scale of
    # 2026-11-02 left him "shorter and wider"). And a board that draws the
    # hero smaller as the action goes on (Brad's smash: his head a fifth
    # smaller in the leap and the landing than as he sets off — "Brad still
    # gets small when he performs his attack") has each frame scaled back,
    # about the row's standing feet: "frame_scale", per facing, a factor a
    # frame, judged by his head against his still pose.
    pix, soft, place = {}, {}, {}
    for (facing, c), (img, _) in cells.items():
        b0 = cells[(facing, 0)][1]
        anchor = ((b0[0] + b0[2]) / 2.0, float(b0[3]))   # the row's standing feet
        # ("dx": a board with no cell rules sets its frames down unevenly; px
        # a frame's figure sits further right in its cell than the row's
        # first, measured on the board, so he stays put.)
        anchor = (anchor[0] + spec.get("dx", {}).get(facing, [0] * n)[c], anchor[1])
        fs = spec.get("frame_scale", {}).get(facing)
        f = row_factor[facing] / (float(fs[c]) if fs else 1.0)
        sq = float(spec.get("squeeze", {}).get(facing, 1.0))
        p = hs.resample(img, f, sq)
        s = hs.soft_frame(img, f, sq)
        sx, sy = p.shape[1] / float(img.width), p.shape[0] / float(img.height)
        pix[(facing, c)] = p
        soft[(facing, c)] = s
        place[(facing, c)] = (anchor[0] * sx, anchor[1] * sy)
    # "splice": frames traded between two facings after each was scaled and
    # placed by its own board row. Brad's cast (designer, 2026-11-08): each
    # side row turns round mid-cast, so a side cast takes the drawing-the-card
    # frames of the row facing the target and the thrust of the other row
    # ({"frames": first frames to trade, "swap": (facing, facing)}).
    sp = spec.get("splice")
    if sp:
        a, b = sp["swap"]
        for c in sp["frames"]:
            for d in (pix, soft, place):
                d[(a, c)], d[(b, c)] = d[(b, c)], d[(a, c)]
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
    smooth_art.bleed(ssheet, smooth_art.SHEET_BLEED).save(sout)
    print("%s %s: %d frames, cell %d, rows %s" % (hero, action, n, C, ", ".join(spec["facings"])))


def main():
    # (Optionally only the boards named: python3 tools/cut_hero_actions.py brad:cast)
    only = {tuple(a.split(":")) for a in sys.argv[1:]}
    for (hero, action), spec in ACTIONS.items():
        if not only or (hero, action) in only:
            build(hero, action, spec)


if __name__ == "__main__":
    main()
