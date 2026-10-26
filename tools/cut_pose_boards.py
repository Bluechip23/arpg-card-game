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

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import smooth_art  # noqa: E402  (the smooth, non-pixelated sheets)

try:
    import cv2   # only the GrabCut boards need it
except ImportError:
    cv2 = None

SRC = "assets/sprites/paintings/%s"
OUT = "assets/sprites/generated/sheets/%s"
MATTES = "assets/sprites/paintings/mattes"   # model mattes (tools/make_mattes.py)
ROWS = ["front", "back", "left", "right"]

# Per creature: board, how its background is told apart, the front Idle's
# height in texels, and a box (x0, y0, x1, y1) around each pose. A pose given
# as ("mirror", other) is the other pose flipped.
BOARDS = {
    "frankenstein": {
        "matte": ("front", "back", "right"),   # the model matte (tools/make_mattes.py, 2026-10-25)
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
        "matte": ("front", "back", "right"),   # the model matte (tools/make_mattes.py, 2026-10-25)
        "src": "fire_frost_mage_board.jpg", "bg": "grabcut", "snow": True, "tiles": 1.6,
        "sky_tol": 12,   # his black hood against the black night sky
        "dark_regrow": 12,  # ...and the hood's top won back from the sky's colour model
        "warm_grow": 55,  # the headband's tails, his forearm wrap and flames
        "drop_blue": True,  # snow-hill pockets between arm and side
        # The headband's two tails, flying off the back of his hood.
        "fg": {"right": [(28, 38, 72, 45, 5), (30, 47, 62, 54, 4), (72, 45, 92, 50, 3)]},
        "Idle": {
            "front": (485, 420, 675, 722),
            "back": (1180, 420, 1370, 722),
            "right": (425, 50, 640, 372),
            "left": ("mirror", "right"),
        },
    },
    "earth_mage": {
        "matte": ("front", "left", "right"),   # the model matte (tools/make_mattes.py, 2026-10-25); its back merges the staff with the board's second back view, so GrabCut keeps that one
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
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py, 2026-10-25)
        "src": "earth_shock_mage_board.jpg", "bg": "grabcut", "snow": True, "tiles": 1.6,
        "bright_grow": 120,   # the lightning round his fists
        "Idle": {
            "front": (465, 415, 690, 722),
            "back": (1160, 400, 1390, 722),
            "right": (410, 55, 645, 372),
            "left": (1105, 55, 1375, 372),
        },
    },
    "ifrit": {
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py, 2026-10-25)
        # 2026-10-25: the Underworld's living-flame elite, horned and armoured,
        # on a dark brick wall and a plank floor.
        "src": "ifrit_board.jpg", "bg": "grabcut", "tiles": 2.0,
        "sky_tol": 12,   # the flat dark wall, walled in between legs, arms and tail
        "drop_ice": True,  # and its shadowed pockets (it has no near-black on it)
        "Idle": {
            "front": (285, 432, 670, 758),
            "back": (740, 432, 1125, 758),
            "right": (255, 58, 645, 375),
            "left": (765, 58, 1152, 375),
        },
    },
    "bull_worm": {
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py, 2026-10-25)
        # 2026-10-25: the Alaskan Bull Worm (Worms Armageddon), coiled, horned,
        # on the same wall and floor.
        "src": "bull_worm_board.jpg", "bg": "grabcut", "tiles": 1.2,
        "sky_tol": 12,
        "Idle": {
            "front": (262, 428, 696, 762),
            "back": (712, 428, 1152, 762),
            "right": (258, 58, 680, 375),
            "left": (725, 58, 1150, 375),
        },
        # The hooked tip of the left horn, seen from behind (dark on the dark wall).
        "fg": {"back": [(72, 100, 95, 128, 6), (95, 128, 118, 124, 6)]},
    },
    "inflamed_minotaur": {
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py, 2026-10-25)
        # 2026-10-25: the Inflamed Minotaur, flaming horns, axe and shield, on
        # a dark flagstone floor. Its "west" and "east" poses are the front
        # pose and its mirror (the board's own labels, kept); the face is
        # "south", the back "north".
        "src": "inflamed_minotaur_board.png", "bg": "warm", "tiles": 2.4,   # fire and bronze on cool flagstones
        "match_height": ("left", "right", "back"),
        # The board's own dark frame line down its outer edges.
        "bg_hint": {"front": [(0, 0, 15, 400)], "left": [(0, 0, 15, 400)],
                    "back": [(232, 0, 260, 400)], "right": [(232, 0, 260, 400)]},
        # The poses run to the board's edges (axe and shield): the boxes
        # reach past them into the crop's black padding.
        "Idle": {
            "front": (-12, 415, 227, 628),
            "back": (233, 415, 482, 628),
            "left": (-12, 57, 227, 292),
            "right": (233, 57, 482, 292),
        },
    },
    "bone_dragon": {
        # 2026-10-25: the Bone Dragon, purple death-mist on its wings and at
        # its feet, in a treasure-strewn crypt. Both side panels face left
        # (the "east" one is not mirrored), so right is the mirror.
        "src": "bone_dragon_board.jpg", "bg": "grabcut", "tiles": 2.6,
        "warm_seed": True,
        "Idle": {
            "front": (615, 468, 1205, 840),
            "back": (12, 478, 602, 858),
            "left": (72, 50, 602, 428),
            "right": ("mirror", "left"),
        },
        # The chest and the skulls on the floor (bone-coloured, like it).
        "bg_hint": {"left": [(0, 248, 32, 345), (205, 343, 268, 378)],
               "back": [(0, 255, 88, 335), (150, 330, 186, 380), (404, 320, 432, 352)],
               "front": [(120, 245, 222, 312)]},   # a lump of rubble beside its leg
        # Its tail and the spine down to the hips, seen from the front (they
        # sit on the grey smoke).
        "fg": {"front": [(300, 225, 300, 290, 8), (410, 225, 418, 250, 6), (418, 250, 410, 280, 6),
                         (410, 280, 396, 300, 6)]},
        "violet_grow": {"front": 230, "back": 240},   # the wings' mist, not the clouds at its feet
    },
    "screecher": {
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py, 2026-10-25)
        # 2026-10-25: the Screecher, a gaunt long-limbed undead crawler with a
        # gaping fanged maw, in a bone-strewn cave. Its side labels are
        # swapped (the "FACING LEFT" panel faces right), so the poses are
        # picked by what they show.
        "src": "screecher_board.jpg", "bg": "grabcut", "tiles": 1.2,
        "warm_seed": "pale",
        "Idle": {
            "front": (800, 50, 1330, 352),
            "back": (95, 50, 610, 352),
            "right": (130, 428, 690, 715),
            "left": (750, 428, 1300, 715),
        },
    },
    "granite_colossus": {
        # 2026-10-25: the Granite Colossus, a hulking stone golem with ember
        # eyes, in a forge. Its side labels are swapped (the "FACING LEFT"
        # panel faces right), so the poses are picked by what they show.
        "src": "granite_colossus_board.jpg", "bg": "grabcut", "tiles": 2.6,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (840, 28, 1290, 372),
            "back": (140, 28, 565, 372),
            "right": (240, 405, 505, 730),
            "left": (905, 405, 1170, 730),
        },
    },
    "grave_titan": {
        # 2026-10-25: the Grave Titan, a moss-grown stone giant in a bone crown
        # and tattered robes hauling a great boulder. The board came cut out
        # (kept with its transparency: its colours are read as they are, so
        # no white fringe; make_mattes judges it on white, as drawn). Its "NORTH"
        # pose shows the face and "SOUTH" the back: picked by what they show.
        "src": "grave_titan_board.png", "bg": "grabcut", "tiles": 2.2,
        "drop_shadow": 0.05,   # the painted ellipse under its feet
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (165, 100, 550, 575),
            "back": (720, 100, 1095, 575),
            "left": (215, 620, 520, 1120),
            "right": (745, 625, 1060, 1120),
        },
    },
    "armored_troll": {
        # 2026-10-25: the Armored Troll — grey-blue, spiked pauldrons, chain
        # and a spiked club — four unlabelled poses on black: front, back,
        # facing left, facing right.
        "src": "armored_troll_board.png", "bg": "grabcut", "tiles": 2.2,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (78, 10, 545, 562),
            "back": (767, 20, 1208, 562),
            "left": (89, 580, 455, 1126),
            "right": (852, 580, 1220, 1126),
        },
    },
    "ice_troll": {
        # 2026-10-25: the Ice Troll — blue hide, white shag and ice crystals —
        # four unlabelled poses on black: front, back, facing left, right.
        "src": "ice_troll_board.png", "bg": "grabcut", "tiles": 2.2,
        "matte": ("front", "back", "left", "right"),
        "Idle": {
            "front": (87, 14, 534, 586),
            "back": (761, 18, 1188, 586),
            "left": (176, 599, 457, 1170),
            "right": (833, 603, 1105, 1170),
        },
    },
    "large_bear": {
        # 2026-10-25: the Large Bear — a scarred brown grizzly — four poses on
        # black. Its "NORTH" pose shows the face and "SOUTH" its back: picked
        # by what they show. A small board (~225 px a pose).
        "src": "large_bear_board.png", "bg": "grabcut", "tiles": 1.9,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (10, 4, 176, 246),
            "back": (176, 2, 318, 244),
            "left": (306, 22, 519, 246),
            "right": (518, 22, 700, 246),
        },
    },
    "mini_bear": {
        # 2026-10-25: the Mini Bear — a young brown bear — four poses on
        # black. Its "NORTH" pose shows the face and "SOUTH" its back: picked
        # by what they show.
        "src": "mini_bear_board.png", "bg": "grabcut", "tiles": 1.1,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (246, 208, 518, 566),
            "back": (792, 208, 1057, 566),
            "left": (148, 688, 581, 1008),
            "right": (730, 688, 1153, 1008),
        },
    },
    "necromancer": {
        # 2026-10-25: the Necromancer — a hooded, ragged black-robed figure
        # with a skull-topped staff hung with severed heads — four poses on
        # black. Its "NORTH" pose shows the face and "SOUTH" its back:
        # picked by what they show. The height counts the staff's skull.
        "src": "necromancer_board.png", "bg": "grabcut", "tiles": 1.9,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (135, 8, 503, 548),
            "back": (760, 8, 1110, 548),
            "left": (195, 604, 526, 1120),
            "right": (746, 604, 1080, 1120),
        },
    },
    "treant": {
        # 2026-10-25: the Treant — a gnarled walking tree with a bark face,
        # branch arms and leaf sprigs — four poses on black. Its "NORTH" pose
        # shows the face and "SOUTH" its back: picked by what they show.
        "src": "treant_board.png", "bg": "grabcut", "tiles": 2.5,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (80, 12, 542, 556),
            "back": (726, 12, 1215, 556),
            "left": (185, 605, 474, 1120),
            "right": (827, 607, 1124, 1119),
        },
    },
    "vampire": {
        # 2026-10-25: the Vampire — a pale, fanged gentleman in a black frock
        # coat lined in red — four poses on black. Its "NORTH" pose shows the
        # face and "SOUTH" its back: picked by what they show.
        "src": "vampire_board.png", "bg": "grabcut", "tiles": 1.75,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (190, 12, 428, 546),
            "back": (834, 12, 1074, 546),
            "left": (262, 604, 421, 1108),
            "right": (835, 604, 998, 1108),
        },
    },
    "skeleton": {
        # 2026-10-25: the Skeleton — a bare skeleton warrior — four poses on
        # black, replacing the Craftpix Skeleton1. Its "NORTH" pose shows the
        # face and "SOUTH" its back: picked by what they show. The boxes stop
        # above the board's labels.
        "src": "skeleton_board.webp", "bg": "grabcut", "tiles": 1.7,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        # The model matte reads the right-facing skull's open eye socket as
        # background; keep it as part of the skull.
        "matte_fg": {"right": [(137, 33, 152, 47)]},
        "Idle": {
            "front": (118, 87, 513, 512),
            "back": (798, 87, 1195, 510),
            "left": (192, 612, 451, 1055),
            "right": (857, 612, 1120, 1055),
        },
    },
    "sewer_cobra": {
        # 2026-10-25: the Sewer Cobra — a coiled black cobra with a manhole-cover hood
        # and an iron collar, dripping green venom; the `sewer_croc` kind — four poses on black. Its "NORTH" pose shows
        # the face and "SOUTH" its back: picked by what they show. The boxes
        # stop above the board's labels.
        "src": "sewer_cobra_board.webp", "bg": "grabcut", "tiles": 1.6,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        # The model drops the venom drips and the open mouth: keep what is lit.
        "matte_fg": {"front": [(140, 100, 290, 300, "lit", 30)],
                     "left": [(0, 30, 140, 260, "lit", 30)],
                     "right": [(410, 30, 523, 260, "lit", 30)]},
        "Idle": {
            "front": (58, 11, 511, 540),
            "back": (774, 11, 1208, 559),
            "left": (37, 610, 536, 1142),
            "right": (688, 618, 1211, 1145),
        },
    },
    "ash_harpy": {
        # 2026-10-25: the Ash Harpy — a feathered harpy with a burning ponytail; the
        # height counts the flame — four poses on black. Its "NORTH" pose shows
        # the face and "SOUTH" its back: picked by what they show. The boxes
        # stop above the board's labels.
        "src": "ash_harpy_board.webp", "bg": "grabcut", "tiles": 1.75,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        # The model drops most of the ponytail's flame: keep what is lit.
        "matte_fg": {"front": [(215, 20, 300, 140, "lit", 40)],
                     "back": [(205, 5, 305, 120, "lit", 40)],
                     "left": [(135, 25, 211, 140, "lit", 40)],
                     "right": [(0, 25, 80, 145, "lit", 40)]},
        "Idle": {
            "front": (119, 7, 487, 546),
            "back": (727, 18, 1089, 546),
            "left": (214, 600, 425, 1155),
            "right": (838, 603, 1040, 1155),
        },
    },
    "snow_wraith": {
        # 2026-10-25: the Snow Wraith — a hooded, tattered wraith with a snowflake
        # clasp, trailing smoke where its legs would be — four poses on black. Its "NORTH" pose shows
        # the face and "SOUTH" its back: picked by what they show. The boxes
        # stop above the board's labels.
        "src": "snow_wraith_board.webp", "bg": "grabcut", "tiles": 1.75,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (34, 12, 510, 580),
            "back": (775, 11, 1215, 580),
            "left": (122, 626, 543, 1180),
            "right": (693, 626, 1121, 1180),
        },
    },
    "fire_goblin": {
        # 2026-10-25: the Fire Goblin — a goblin in red leather with a torch,
        # scimitar and round shield; the fire goblin soldier and shaman wear it
        # (the mage has its own board). The
        # height counts the torch's flame — four poses on black. Its "NORTH" pose shows
        # the face and "SOUTH" its back: picked by what they show. The boxes
        # stop above the board's labels.
        "src": "fire_goblin_board.webp", "bg": "grabcut", "tiles": 1.5,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (111, 16, 497, 546),
            "back": (764, 50, 1097, 546),
            "left": (164, 611, 415, 1145),
            "right": (841, 617, 1097, 1145),
        },
    },
    "sludge": {
        # 2026-10-25: the Sludge Being — a many-eyed ooze rising from its puddle,
        # holding a ball of slime; its "WEST" / "EAST" are left / right — four poses on black. Its "NORTH" pose shows
        # the face and "SOUTH" its back: picked by what they show. The boxes
        # stop above the board's labels.
        "src": "sludge_board.webp", "bg": "grabcut", "tiles": 1.45,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (45, 80, 543, 553),
            "back": (703, 100, 1219, 553),
            "left": (34, 617, 576, 1115),
            "right": (661, 617, 1212, 1115),
        },
    },
    "fire_goblin_mage": {
        # 2026-10-25: the Goblin Fire Mage — a goblin in a ragged black-and-
        # red robe, fire in both hands — four poses on black; the
        # `fire_goblin_mage` kind. Its "NORTH" pose shows the face and
        # "SOUTH" its back; "WEST" / "EAST" are left / right. The height
        # counts the flames.
        "src": "fire_goblin_mage_board.webp", "bg": "grabcut", "tiles": 1.6,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (92, 23, 493, 533),
            "back": (733, 31, 1160, 532),
            "left": (116, 610, 458, 1134),
            "right": (787, 612, 1122, 1134),
        },
    },
    "coyote": {
        # 2026-10-26: the Coyote — a lean brown-grey coyote — four poses on
        # black. Its "NORTH" pose shows the face and "SOUTH" its back;
        # "WEST" / "EAST" are left / right.
        "src": "coyote_board.webp", "bg": "grabcut", "tiles": 1.35,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (301, 41, 493, 458),
            "back": (1024, 29, 1204, 455),
            "left": (112, 510, 679, 915),
            "right": (853, 511, 1413, 915),
        },
    },
    "succubus": {
        # 2026-10-26: the Succubus — horned, bat-winged, in purple and black
        # leather and high boots — four labelled poses on black: front,
        # back, left, right. The boxes stop above the labels, which sit
        # right under her heels.
        "src": "succubus_board.webp", "bg": "grabcut", "tiles": 1.85,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (76, 2, 512, 558),
            "back": (697, 3, 1148, 558),
            "left": (204, 595, 463, 1167),
            "right": (773, 596, 1014, 1167),
        },
    },
    "cherub": {
        # 2026-10-26: the Cherub — a curly-haired winged infant in a white
        # suit with a heart-tipped crossbow — four labelled poses on black:
        # front, back, left, right. It hovers, feet off the ground.
        "src": "cherub_board.jpg", "bg": "grabcut", "tiles": 1.3,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (111, 20, 453, 418),
            "back": (559, 25, 976, 428),
            "left": (36, 490, 460, 885),
            "right": (555, 494, 988, 886),
        },
    },
    "spirit_collector": {
        # 2026-10-25: the Spirit Collector — a grizzled grave-robber in a
        # ragged coat and hat, a shovel on his back, a lantern of trapped
        # souls in his hand — four poses on black. Its "NORTH" pose shows the
        # face and "SOUTH" its back: picked by what they show. The height
        # counts the shovel's blade.
        "src": "spirit_collector_board.png", "bg": "grabcut", "tiles": 1.75,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (170, 8, 440, 534),
            "back": (826, 8, 1094, 534),
            "left": (186, 597, 450, 1094),
            "right": (826, 597, 1092, 1094),
        },
    },
    "bugbear": {
        # 2026-10-25: the Bugbear — a shaggy, fanged brute in spiked iron
        # pauldrons and greaves, a spiked mace in hand — four labelled poses
        # on black: north (front), south (back), west (left), east (right).
        "src": "bugbear_board.png", "bg": "grabcut", "tiles": 1.9,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (12, 6, 550, 520),
            "back": (752, 14, 1302, 520),
            "left": (69, 584, 488, 1122),
            "right": (804, 584, 1210, 1122),
        },
    },
    "giant_hawk": {
        # 2026-10-25: the Giant Hawk — midnight black, flecked brown, a sharp
        # hooked yellow beak, yellow talons with black claws — perched, four
        # labelled poses on black: north (front, wings half-spread), south
        # (back), west (left), east (right).
        "src": "giant_hawk_board.png", "bg": "grabcut", "tiles": 1.6,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (4, 2, 648, 546),
            "back": (678, 2, 1290, 546),
            "left": (70, 592, 628, 1108),
            "right": (678, 592, 1238, 1108),
        },
    },
    "infected_hunter": {
        # 2026-10-25: the Infected Hunter — a ragged, rotting trapper in a
        # wide hat with a chained hook and a net on his back — four labelled
        # poses on black. A small board (~250 px a pose).
        "src": "infected_hunter_board.png", "bg": "grabcut", "tiles": 1.7,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (4, 0, 254, 258),
            "back": (362, 0, 606, 258),
            "left": (32, 282, 254, 556),
            "right": (353, 285, 576, 556),
        },
    },
    "air_mage": {
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py, 2026-10-25)
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
                 drop_ice=False, bright_grow=0, sky_tol=0, warm_grow=0,
                 drop_blue=False, dark_regrow=0, bg_boxes=(), warm_seed=False,
                 violet_grow=0) -> np.ndarray:
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
    if sky_tol:
        # A near-black figure on the near-black night sky (the fire mage's
        # hood): GrabCut can't tell them apart by colour model, but the sky
        # is one flat colour and the figure's outline is blacker still, so
        # the sky within `sky_tol` of its own colour, flooded from the edge,
        # is certainly background — it stops at the outline.
        flat = sky & (np.arange(h)[:, None] < h * 0.75)
        tone = np.median(rgb[flat], axis=0) if flat.any() else np.array([12, 21, 26])
        near = np.sqrt(((rgb - tone) ** 2).sum(-1)) <= sky_tol
        mask[_flood(near, edge) & (mask != cv2.GC_BGD)] = cv2.GC_BGD
    for hint in fg_boxes:
        if len(hint) == 5:   # a line (x0, y0, x1, y1, width): a staff, a spear shaft
            cv2.line(mask, hint[0:2], hint[2:4], int(cv2.GC_FGD), hint[4])
        else:
            x0, y0, x1, y1 = hint
            mask[y0:y1, x0:x1] = cv2.GC_FGD
    if warm_seed == "pale":
        # A pale creature on a dim cave of the same greys (the Screecher):
        # only brightness tells them apart. Its lit skin (pale, nearly
        # colourless) is surely it, the darkest of the cave probably not.
        inner = mask == cv2.GC_PR_FGD
        mask[inner & (lum < 32)] = cv2.GC_PR_BGD
        mask[inner & (lum > 95) & (sat < 45)] = cv2.GC_FGD
    elif warm_seed:
        # Bone on a cool crypt (the Bone Dragon): its bone, wing membrane and
        # purple mist run warm or violet (red at or over blue), the teal wall,
        # grey smoke and slate rubble run cool. Cool starts as probable
        # background, bright bone as surely the creature.
        r_, g_, b_ = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        violet = (b_ > g_ + 25) & (r_ > g_ + 10)
        cool = (b_ - r_ > 6) & ~violet
        inner = mask == cv2.GC_PR_FGD
        mask[inner & cool] = cv2.GC_PR_BGD
        mask[inner & (lum > 150) & (sat < 60) & (r_ >= b_)] = cv2.GC_FGD
    for x0, y0, x1, y1 in bg_boxes:   # scenery surely not the creature (a chest, a skull)
        mask[y0:y1, x0:x1] = cv2.GC_BGD
    bgd, fgd = np.zeros((1, 65)), np.zeros((1, 65))
    cv2.setRNGSeed(0)   # GrabCut seeds its colour models randomly: keep the cut repeatable
    cv2.grabCut(bgr, mask, None, bgd, fgd, GRABCUT_ITER, cv2.GC_INIT_WITH_MASK)
    fg = (mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD)
    if sky_tol and dark_regrow:
        # Then win back the dark cloth GrabCut handed to the sky's colour
        # model (the top of his hood): dark, neutral pixels (not the sky's
        # own tone, not the blue snow) within a hood's depth of the figure.
        cloth = ~near & (lum < 80) & (rgb[..., 2] - rgb[..., 0] <= 16)
        close = _grow(fg, dark_regrow)
        seeds = list(zip(*np.nonzero(fg)))
        fg |= _flood((cloth & close) | fg, seeds) & (mask != cv2.GC_BGD)
    if violet_grow:
        # The death-mist on the wings: purple touching the cut, above row
        # `violet_grow` (not the clouds on the ground below it).
        r_, g_, b_ = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        violet = (b_ > g_ + 25) & (r_ > g_ + 10)
        violet[violet_grow:] = False
        seeds = list(zip(*np.nonzero(fg)))
        fg |= _flood(violet | fg, seeds)
    if sat_grow:
        seeds = list(zip(*np.nonzero(fg)))
        fg |= _flood((sat >= sat_grow) | fg, seeds)
    if warm_grow:
        # Saturated reds, oranges and skin only (the snow is saturated blue).
        seeds = list(zip(*np.nonzero(fg)))
        fg |= _flood(((sat >= warm_grow) & (rgb[..., 0] > rgb[..., 2] + 20)) | fg, seeds)
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
        if warm_seed is True:
            # The crypt seen between ribs, under a wing, between the legs:
            # left open whatever its size when it is the cool scenery.
            r_, g_, b_ = rgb[..., 0][pts], rgb[..., 1][pts], rgb[..., 2][pts]
            cool = (b_ - r_ > 6) & ~((b_ > g_ + 25) & (r_ > g_ + 10))
            if cool.mean() < 0.5 and len(comp) <= HOLE_FILL_MAX * 4:
                fg[pts] = True
        elif len(comp) <= HOLE_FILL_MAX or looks_bg[pts].mean() < 0.5:
            fg[pts] = True
    if warm_seed is True:
        # ...and any patch of that cool scenery GrabCut kept inside the cut.
        r_, g_, b_ = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        cool = (b_ - r_ > 6) & ~((b_ > g_ + 25) & (r_ > g_ + 10))
        for comp in _components(fg & cool):
            if len(comp) > 40:
                fg[tuple(np.array(comp).T)] = False
    if drop_ice:
        # A figure with nothing ice-coloured or near-black on it: any big
        # patch of snow blue or night sky GrabCut kept (seen between an arm
        # and a staff) is background.
        ice_like = (rgb[..., 2] - rgb[..., 0] > 25) & (sat < 65) & (lum > 35)   # shadowed snow too
        ice_like |= (lum < 30) & (sat < 25)                                       # and the night sky
        for comp in _components(fg & ice_like):
            if len(comp) > HOLE_FILL_MAX:
                fg[tuple(np.array(comp).T)] = False
    if drop_blue:
        # A figure with no blue on him: the shadowed snow hills seen between
        # an arm and his side are background, whatever GrabCut said.
        blue = fg & (rgb[..., 2] - rgb[..., 0] > 30) & (lum > 45)
        for comp in _components(blue):
            if len(comp) > 15:
                fg[tuple(np.array(comp).T)] = False
    if feet_trim:
        ys = np.nonzero(fg.any(axis=1))[0]
        band = int(ys.max() - FEET_BAND * (ys.max() - ys.min()))
        cool = (rgb[..., 2] >= rgb[..., 0]) & (sat < 45) & (lum > 50)
        fg[band:] &= ~cool[band:]
    return ~fg


def _cut_warm(rgb: np.ndarray, fg_boxes=(), bg_boxes=()) -> np.ndarray:
    """Background mask for a warm creature on a cool floor (the Inflamed
    Minotaur: flames, bronze and dark red armour on blue-grey flagstones).
    GrabCut can't hold it — its chainmail is the floor's own grey and pulls
    the floor in with it — so the creature is classified directly:
      - warm: red well over blue, not near-black (all of the fire and armour);
      - mail: busy grey (a high local contrast, the checker of rings) close
        to the warm parts — the smooth floor is not busy;
      - its ink: the dark outline right against the warm parts.
    Then specks dropped and holes filled as usual."""
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = rgb.mean(axis=2)
    warm = (r > b + 20) & (lum > 30)
    lf = lum.astype(np.float32)
    mean = cv2.blur(lf, (3, 3))
    busy = np.sqrt(np.maximum(cv2.blur(lf * lf, (3, 3)) - mean * mean, 0)) > 10   # floor ~1-9, mail ~11-25
    busy = cv2.morphologyEx(busy.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8)).astype(bool)
    near = _grow(warm, 24)   # the skirt hangs ~40 px wide between warm thighs
    pad = rgb.sum(axis=2) == 0   # the crop's padding past the board's edge
    fg = (warm | (busy & near) | ((lum < 40) & _grow(warm, 2))) & ~pad
    for hint in fg_boxes:
        m = np.zeros(fg.shape, np.uint8)
        if len(hint) == 5:
            cv2.line(m, hint[0:2], hint[2:4], 1, hint[4])
        else:
            m[hint[1]:hint[3], hint[0]:hint[2]] = 1
        fg |= m.astype(bool)
    fg = cv2.morphologyEx(fg.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)).astype(bool)
    for x0, y0, x1, y1 in bg_boxes:
        fg[y0:y1, x0:x1] = False
    h, w = fg.shape
    edge = [(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)] + \
           [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)]
    for comp in _components(~fg & ~_flood(~fg, edge)):
        if len(comp) <= HOLE_FILL_MAX:
            fg[tuple(np.array(comp).T)] = True
    return ~fg


def cut(board: Image.Image, box, kind: str, fg_boxes=(), sat_grow=0, snow=False,
        feet_trim=True, drop_ice=False, bright_grow=0, sky_tol=0, warm_grow=0,
        drop_blue=False, dark_regrow=0, bg_boxes=(), warm_seed=False, violet_grow=0) -> Image.Image:
    """The creature in `box`, full size, on transparency, cropped to itself."""
    rgb = np.asarray(board.crop(box).convert("RGB")).astype(int)
    h, w, _ = rgb.shape
    edge = [(0, x) for x in range(w)] + [(h - 1, x) for x in range(w)] + \
           [(y, 0) for y in range(h)] + [(y, w - 1) for y in range(h)]
    bg_like = _background_like(rgb, kind) if kind in ("checker_light", "checker_grey", "stone") else None
    if kind.startswith("matte:"):
        # The saved model matte (tools/make_mattes.py), with any boxes of
        # scenery it kept cleared and any hint lines it lost added back.
        fg = np.asarray(Image.open(kind[6:]).convert("L")) > 127
        for x0, y0, x1, y1 in bg_boxes:
            fg[y0:y1, x0:x1] = False
        for hint in fg_boxes:
            m = np.zeros(fg.shape, np.uint8)
            if len(hint) == 6 and hint[4] == "lit":
                # Everything in the box brighter than the black board
                # (venom drips, a flame's wisps the model dropped).
                x0, y0, x1, y1 = hint[0:4]
                m[y0:y1, x0:x1] = rgb[y0:y1, x0:x1].max(axis=2) > hint[5]
            elif len(hint) == 5:
                cv2.line(m, hint[0:2], hint[2:4], 1, hint[4])
            else:
                m[hint[1]:hint[3], hint[0]:hint[2]] = 1
            fg |= m.astype(bool)
        bg = ~fg
    elif kind == "warm":
        bg = _cut_warm(rgb, fg_boxes, bg_boxes)
    elif kind == "grabcut":
        bg = _cut_grabcut(rgb, fg_boxes, sat_grow, snow, feet_trim, drop_ice, bright_grow, sky_tol, warm_grow,
                          drop_blue, dark_regrow, bg_boxes, warm_seed, violet_grow)
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


def _drop_floor_shadow(img: Image.Image, band: float) -> Image.Image:
    """A painted floor shadow kept under the feet (the Grave Titan's board
    came cut out with its ellipse): dark, colourless pixels in the bottom
    `band` of the figure go, then the cut-out is cropped to what is left."""
    a = np.asarray(img).copy()
    rgb = a[..., :3].astype(int)
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    y0 = int(a.shape[0] * (1.0 - band))
    shadow = (lum < 80) & (sat < 20)
    shadow[:y0] = False
    a[..., 3][shadow] = 0
    ys, xs = np.nonzero(a[..., 3] > 0)
    return Image.fromarray(a[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")


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
                bg_kind = cfg["bg"]
                if d in cfg.get("matte", ()):
                    bg_kind = "matte:" + os.path.join(MATTES, "%s_%s.png" % (name, d))
                fg_hints = cfg.get("matte_fg", {}).get(d, ()) if bg_kind.startswith("matte:") \
                    else cfg.get("fg", {}).get(d, ())
                bg_hints = cfg.get("matte_bg", {}).get(d, ()) if bg_kind.startswith("matte:") \
                    else cfg.get("bg_hint", {}).get(d, ())
                full[anim][d] = cut(board, box, bg_kind, fg_hints,
                                    cfg.get("sat_grow", 0), cfg.get("snow", False),
                                    cfg.get("feet_trim", True), cfg.get("drop_ice", False),
                                    cfg.get("bright_grow", 0), cfg.get("sky_tol", 0),
                                    cfg.get("warm_grow", 0), cfg.get("drop_blue", False),
                                    cfg.get("dark_regrow", 0), bg_hints,
                                    cfg.get("warm_seed", False), cfg.get("violet_grow", {}).get(d, 0))
            if cfg.get("drop_shadow") and d in full[anim]:
                full[anim][d] = _drop_floor_shadow(full[anim][d], cfg["drop_shadow"])
        for d, box in cfg[anim].items():
            if box[0] == "mirror":
                full[anim][d] = full[anim][box[1]].transpose(Image.FLIP_LEFT_RIGHT)
    for d in cfg.get("match_height", ()):
        # A pose the board draws at another size (the minotaur's top row is
        # ~15% larger than its bottom row): brought to the front's height so
        # the creature doesn't grow when it turns.
        for anim in full:
            f = full[anim][d]
            k = full[anim]["front"].height / float(f.height)
            size = (max(1, round(f.width * k)), max(1, round(f.height * k)))
            g = f.convert("RGBa").resize(size, Image.BOX).convert("RGBA")
            a = np.asarray(g).copy()
            a[..., 3] = np.where(a[..., 3] >= 128, 255, 0)
            full[anim][d] = Image.fromarray(a, "RGBA")
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
    # The smooth version (smooth_art): the same cut-outs at SMOOTH_DENSITY
    # texels a tile, soft-filtered with soft alpha, kept beside the pixel one.
    sfac = full["Idle"]["front"].height / float(round(cfg["tiles"] * smooth_art.SMOOTH_DENSITY))
    soft = {a: {d: smooth_art.trim(smooth_art.resample(f, sfac)) for d, f in fs.items()} for a, fs in full.items()}
    scell = max(max(f.width, f.height) for fs in soft.values() for f in fs.values()) + 2
    sdir = os.path.join(smooth_art.ROOT, "sheets", name)
    os.makedirs(sdir, exist_ok=True)
    for anim, fs in soft.items():
        smooth_art.pack([[fs[d]] for d in ROWS], scell, 1, lambda row, ci: row[0], air=0).save(os.path.join(sdir, anim + ".png"))


def main() -> None:
    names = sys.argv[1:] or list(BOARDS)
    for n in names:
        build(n, BOARDS[n])


if __name__ == "__main__":
    main()
