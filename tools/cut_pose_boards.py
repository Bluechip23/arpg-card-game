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

Action sheets (2026-10-30): a creature may also have "actions" boards —
the designer's werewolf_slash_board.webp (two rows of a slash on black,
facing right then facing left) and werewolf_slash_front_back_board.webp
(the same slash seen from the front and from behind) — cut into one or
more multi-frame sheets (Attack.png, Attack2.png) in the Craftpix row order
(front, back, left, right), or with only the two side rows (left, right)
when a board has no front or back: the figure then turns to a side to play
them when it faces front or back. The boards are cut by brightness off
their black (the slash's red glow keeps a soft alpha), each facing scaled
so one named pose stands as tall as its Idle pose, and packed in the same
cells as the Idle sheet (SpriteEnemyFigure indexes every sheet by the Idle
cell). A pose may be ("mirror", box) — cut and flipped, so a back-view
sweep drawn with the right arm becomes the left arm's — or ("same",
pose), another pose of that facing again. An action board whose figure is
as dark as its backdrop (the Battle Turtle's armor board, 2026-11-03) sets
"matte": each frame is cut by a model matte (tools/make_mattes.py), with
the lit red pieces (a tossed brick, dug dirt) added back.

Output: assets/sprites/generated/sheets/<creature>/{Idle,Walk}.png
        (+ the action sheets, e.g. Attack.png / Attack2.png)
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
# The Hydra's head-loss sets are sized by her body, not her height: each
# board draws her heads and her bulk in its own proportions, and losing
# heads must make her shorter, not bigger. Set so her front stance's legs
# and trunk match the full Hydra's (tools: measured on the cut sheets).
# The widest a packed strip may be: past it a strip is packed in rows (many
# GPUs draw nothing from a texture wider than 8192 px).
MAX_SHEET_PX = 8192

# The Rat King's Infest board draws him squatter than his pose board does:
# matched to his Idle by bulk (width), not height (2026-11-04).
MATCH_SCALE_RK = {"front": 0.86, "back": 0.91, "left": 0.94, "right": 0.94}
TILES_H5 = 1.7
TILES_H3 = 1.7

# Per creature: board, how its background is told apart, the front Idle's
# height in texels, and a box (x0, y0, x1, y1) around each pose. A pose given
# as ("mirror", other) is the other pose flipped.
BOARDS = {
    "frankenstein": {
        # 2026-10-28: the designer's new Frankensteins Monster — green and
        # stitched, a torn brown coat over a black shirt, the neck bolts
        # crackling blue, heavy boots — one row on black: front, back, then
        # two side views, the first facing right and the second left.
        "src": "frankenstein_v2_board.webp", "bg": "grabcut", "tiles": 1.75,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        # The model trims the bolts' sparks: keep what is lit.
        "matte_fg": {d: [(0, 0, 9999, 9999, "lit", 45)] for d in ("front", "back", "left", "right")},
        "Idle": {
            "front": (4, 140, 410, 895),
            "back": (420, 140, 826, 895),
            "right": (866, 140, 1110, 898),
            "left": (1280, 140, 1518, 898),
        },
    },
    "giant_beaver": {
        # 2026-10-28: the designer's new Giant Beaver — a shaggy, red-eyed
        # beaver with sabre teeth, a scaled black tail and hooked claws — on
        # black, two rows: up on its hind legs (Idle) and on all fours (Walk),
        # FRONT, BACK, LEFT, RIGHT, each side facing its own way. The bottom
        # row's side poses meet tail to tail at x 1090. Height: standing.
        "src": "giant_beaver_v2_board.webp", "bg": "grabcut", "tiles": 1.3,
        "matte": ("front", "back", "left", "right",
                  "Walk:front", "Walk:back", "Walk:left", "Walk:right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (14, 46, 312, 540),
            "back": (363, 46, 656, 540),
            "left": (680, 46, 1121, 540),
            "right": (1122, 46, 1518, 540),
        },
        "Walk": {
            "front": (18, 640, 322, 930),
            "back": (358, 640, 630, 930),
            "left": (628, 640, 1090, 930),
            "right": (1090, 640, 1528, 930),
        },
    },
    "wyvern": {
        # 2026-10-28: the designer's new Wyvern — a green-scaled drake with
        # tattered brown wings, horns and a barbed tail — on black, two rows:
        # reared up on its hind legs (Idle) and down on all fours (Walk),
        # FRONT, BACK, LEFT, RIGHT, each side facing its own way. The top
        # row's BACK tail runs into the LEFT pose's claws: split at x 750.
        "src": "wyvern_v2_board.webp", "bg": "grabcut", "tiles": 1.9,
        "matte": ("front", "back", "left", "right",
                  "Walk:front", "Walk:back", "Walk:left", "Walk:right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (8, 70, 356, 511),
            "back": (366, 80, 750, 511),
            "left": (750, 80, 1128, 511),
            "right": (1128, 80, 1520, 511),
        },
        "Walk": {
            "front": (2, 612, 358, 904),
            "back": (360, 612, 686, 904),
            "left": (686, 612, 1145, 904),
            "right": (1145, 612, 1530, 904),
        },
    },
    "sanguine_penguin": {
        # 2026-10-28: the designer's new Sanguine — a scarred, bleeding
        # penguin in a bronze crested helm — one row on black: front, back,
        # then two side views, the first facing right and the second left.
        "src": "sanguine_penguin_v2_board.webp", "bg": "grabcut", "tiles": 1.15,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (24, 195, 378, 760),
            "back": (406, 190, 775, 760),
            "right": (776, 210, 1105, 768),
            "left": (1198, 210, 1527, 770),
        },
    },
    "djinn": {
        # 2026-10-28: the designer's new Djinn — a blue genie with a smoke
        # ponytail, gold cuffs and chains, his lower body a coiling blue
        # smoke tail — two rows on black; the top row (FRONT, BACK, LEFT,
        # RIGHT, each facing its own way) is used, the second row (other
        # poses: arms crossed, from above) is not. The labels sit below the
        # poses. Height to the ponytail's top.
        "src": "djinn_v2_board.webp", "bg": "grabcut", "tiles": 1.8,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        # The model trims the smoke's thin wisps: keep what is lit.
        "matte_fg": {d: [(0, 0, 9999, 9999, "lit", 30)] for d in ("front", "back", "left", "right")},
        "Idle": {
            "front": (30, 12, 345, 455),
            "back": (452, 14, 752, 455),
            "left": (798, 12, 1072, 455),
            "right": (1155, 14, 1407, 455),
        },
        # 2026-11-04: the designer's chain lightning board —
        # djinn_chain_lightning_board.webp, four labelled rows on black between
        # rule lines (NORTH (BACK / UP), SOUTH (FRONT / DOWN), WEST (LEFT), EAST
        # (RIGHT)), eight captioned frames a row: ready, eyes glowing, the
        # eyes crackling, the surge down his arms, the lightning gathered in
        # his hands, unleashed, the chain lightning, recovery. Both side rows
        # face right (the left is the right mirrored), and their last two
        # frames throw a long bolt out to the right: those boxes end just
        # past his hands, and the bolt to whoever is struck is the arc
        # sprite (djinn_arc) laid between them. The front's chain frame runs
        # its lightning down to the caption: its box stops above it. Cast.png,
        # played for his Chain Lightning; the ready pose is the height
        # reference, matched to each facing's Idle.
        "actions": {
            "src": "djinn_chain_lightning_board.webp",
            "levels": (16, 45, 20),   # the lightning's glow fades out through dim navy: above that, so it doesn't box the bolts in dark
            "fill_holes": 10,
            "open_dark": True,
            "keep_share": 0.002,   # loose sparks of the lightning
            "glow": False,
            "isolate": True,
            "isolate_floor": 14,
            # The side rows' unleash and chain frames join through the bolt
            # (one piece, centred in the chain frame): their boxes don't
            # overlap, so they are cut without isolating.
            "isolate_skip": (("right", "unleash"), ("right", "chain"), ("left", "unleash"), ("left", "chain")),
            # The bolts each box cuts through dissolve (`_fade_edge`): the
            # side rows' at his hands (cut on the right, then mirrored for the
            # left), the front's at the caption, the back's at the board's top.
            "edge_fade": {("right", "unleash"): (("right", 24),), ("right", "chain"): (("right", 24),),
                          ("left", "unleash"): (("right", 24),), ("left", "chain"): (("right", 24),),
                          ("front", "chain"): (("bottom", 16),), ("back", "chain"): (("top", 16),)},
            "match": "ready",
            "frames": {
                "front": {
                    "ready": (127, 271, 266, 486),
                    "eyes": (285, 271, 423, 486),
                    "crackle": (441, 270, 578, 486),
                    "surge": (598, 271, 738, 486),
                    "gather": (750, 271, 909, 486),
                    "unleash": (915, 271, 1090, 486),
                    "chain": (1064, 275, 1308, 485),
                    "recover": (1293, 271, 1431, 486),
                },
                "back": {
                    "ready": (136, 11, 265, 233),
                    "eyes": (290, 11, 419, 233),
                    "crackle": (455, 11, 583, 233),
                    "surge": (616, 10, 749, 233),
                    "gather": (767, 10, 935, 233),
                    "unleash": (932, 9, 1105, 233),
                    "chain": (1088, 0, 1281, 233),
                    "recover": (1302, 10, 1431, 233),
                },
                "left": {
                    "ready": ("mirror", (130, 787, 241, 1008)),
                    "eyes": ("mirror", (282, 788, 389, 1008)),
                    "crackle": ("mirror", (440, 788, 554, 1008)),
                    "surge": ("mirror", (593, 788, 701, 1008)),
                    "gather": ("mirror", (736, 787, 883, 1008)),
                    "unleash": ("mirror", (895, 788, 1042, 1008)),
                    "chain": ("mirror", (1092, 788, 1195, 1008)),
                    "recover": ("mirror", (1296, 788, 1408, 1008)),
                },
                "right": {
                    "ready": (130, 787, 241, 1008),
                    "eyes": (282, 788, 389, 1008),
                    "crackle": (440, 788, 554, 1008),
                    "surge": (593, 788, 701, 1008),
                    "gather": (736, 787, 883, 1008),
                    "unleash": (895, 788, 1042, 1008),
                    "chain": (1092, 788, 1195, 1008),
                    "recover": (1296, 788, 1408, 1008),
                },
            },
            "sheets": {
                "Cast": ["eyes", "crackle", "surge", "gather", "unleash", "chain", "recover"],
            },
        },
    },
    "djinn_arc": {
        # 2026-11-04: the lightning that bounces between Chain Lightning's
        # targets — djinn_lightning_arc_strip.webp, ten frames on transparency
        # of a crackling arc between two glowing nodes, growing from a thin
        # spark to a full arc and dying away. Packed as one row, Arc.png, in
        # his folder, every frame stretched to the widest frame's width so
        # the nodes sit at the same place in each (`stretch`); ArcBolt lays
        # it between the Djinn's hand and each target in turn, stretched to
        # the distance (its ends sit ~14% in from each side of every frame:
        # ArcBolt.NODE_SPAN). 1.6 tiles wide as packed.
        "into": "djinn",
        "strip": {
            "src": "djinn_lightning_arc_strip.webp",
            "sheet": "Arc",
            "width_tiles": 1.6,
            "align": "board",
            "stretch": True,
            "frames": [(5, 230, 190, 400), (190, 230, 372, 400), (372, 230, 575, 400), (575, 230, 791, 400), (791, 230, 1036, 400), (1036, 230, 1259, 400), (1259, 230, 1456, 400), (1456, 230, 1650, 400), (1650, 230, 1834, 400), (1834, 230, 1995, 400)],
        },
    },
    "ice_mage": {
        # 2026-10-27: the Ice Mage redrawn — a hooded frost mage in a fur-
        # trimmed blue robe with a crystal-headed staff and a swirl of frost
        # in hand — four poses on black. Its labels are swapped ("FACING UP"
        # is the face) and both side poses face right: the "FACING RIGHT"
        # one is the right, its mirror the left. The height counts the
        # staff's crystal, which tops the head (the body matches the other mages).
        "src": "ice_mage_board_v2.webp", "bg": "grabcut", "tiles": 1.75,
        "matte": ("front", "back", "right"),   # the model matte (tools/make_mattes.py)
        "matte_fg": {d: [(0, 0, 9999, 9999, "lit", 45)] for d in ("front", "back", "right")},
        "Idle": {
            "front": (38, 178, 384, 792),
            "back": (427, 178, 788, 792),
            "right": (1212, 178, 1536, 792),
            "left": ("mirror", "right"),
        },
    },
    "fire_mage": {
        # 2026-10-27: the Fire Mage redrawn — a hooded, masked fire ninja in
        # black and blood-red wraps, flame round both fists — four poses on
        # black ("FACING UP" is the face; the side labels are true).
        "src": "fire_mage_board_v2.webp", "bg": "grabcut", "tiles": 1.6,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        # The model trims the flames' wisps: keep what is lit.
        "matte_fg": {d: [(0, 0, 9999, 9999, "lit", 45)] for d in ("front", "back", "left", "right")},
        "Idle": {
            "front": (17, 37, 356, 489),
            "back": (411, 37, 727, 489),
            "left": (852, 37, 1106, 489),
            "right": (1210, 37, 1536, 489),
        },
    },
    "earth_mage": {
        # 2026-10-27: the Earth Mage redrawn — a bald, blue-painted druid in a
        # green hood and vine-bound wraps, a gem-topped vine staff in hand —
        # four poses on dark navy (front, back, left, right, labels cut off).
        # Its neck roll, shown only in the front view, is painted into the
        # other three by tools/paint_earth_mage_roll.py (designer: round the
        # back of his neck, not the front), which writes this board.
        "src": "earth_mage_druid_board.png", "bg": "grabcut", "tiles": 1.85,   # the staff tops him: his body matches the other mages
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (6, 2, 160, 272),
            "back": (160, 2, 295, 272),
            "left": (294, 2, 435, 272),
            "right": (447, 2, 550, 272),
        },
    },
    "spark_mage": {
        # 2026-10-27: the Spark Mage (shock mage) redrawn — a blond brawler in
        # a black vest and torn purple trousers, lightning round his fists —
        # four poses on dark navy. Both side poses face left, and the first
        # holds a vine staff that isn't his (the Earth Mage's): the staff-free
        # one is the left, and the right is its mirror.
        "src": "spark_mage_brawler_board.png", "bg": "grabcut", "tiles": 1.6,
        "matte": ("front", "back", "left"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (0, 8, 166, 347),
            "back": (166, 8, 367, 347),
            "left": (539, 8, 686, 347),
            "right": ("mirror", "left"),
        },
    },
    "ifrit": {
        # 2026-10-27: the Ifrit redrawn — a horned, scaled fire demon in
        # bronze plate with flame in both hands and a long tail — four
        # labelled poses on black (front, back, left, right; the side labels
        # are true). Replaces the brick-wall board.
        "src": "ifrit_board_v2.webp", "bg": "grabcut", "tiles": 2.0,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        # The model trims the flames' wisps: keep what is lit.
        "matte_fg": {d: [(0, 0, 9999, 9999, "lit", 45)] for d in ("front", "back", "left", "right")},
        "Idle": {
            "front": (226, 15, 679, 465),
            "back": (848, 15, 1306, 460),
            "left": (281, 507, 705, 932),
            "right": (831, 507, 1252, 932),
        },
    },
    "pit_fiend": {
        # 2026-10-28: the designer's new Pit Fiend — red-skinned and horned,
        # bat wings, spiked armour with a skull belt, a sword at his hip and
        # a glowing chain in hand — one row on black: front, back, then two
        # side views, the first facing left and the second right. Stills
        # only: it replaces the action board (tools/cut_pit_fiend.py, whose
        # walk and tail-sweep frames are not drawn on the new board).
        "src": "pit_fiend_v2_board.webp", "bg": "grabcut", "tiles": 1.75,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        # The model trims fire and glow: keep what is lit.
        "matte_fg": {d: [(0, 0, 9999, 9999, "lit", 45)] for d in ("front", "back", "left", "right")},
        "Idle": {
            "front": (8, 140, 460, 732),
            "back": (466, 140, 904, 732),
            "left": (910, 138, 1334, 732),
            "right": (1380, 138, 1774, 732),
        },
    },
    "bull_worm": {
        # 2026-10-28: the designer's new Alaskan Bull Worm (Worms
        # Armageddon's summon) — a ram-horned, many-eyed worm rearing out of
        # its own smouldering coils — one row on black: front, back, then
        # two side views, the first facing left and the second right.
        "src": "bull_worm_v2_board.webp", "bg": "grabcut", "tiles": 1.2,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        # The model trims fire and glow: keep what is lit.
        "matte_fg": {d: [(0, 0, 9999, 9999, "lit", 45)] for d in ("front", "back", "left", "right")},
        "Idle": {
            "front": (12, 188, 450, 766),
            "back": (476, 188, 882, 768),
            "left": (882, 186, 1316, 766),
            "right": (1344, 186, 1758, 766),
        },
    },
    "inflamed_minotaur": {
        # 2026-10-28: the designer's updated Inflamed Minotaur — flaming mane
        # and horns, a burning axe and a spiked shield, lava-veined armour —
        # a 2x2 board on black: front, back (top), facing left, facing right
        # (bottom). The top row's flames run off the board's top edge.
        "src": "inflamed_minotaur_v2_board.webp", "bg": "grabcut", "tiles": 2.4,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        # The model trims fire and glow: keep what is lit.
        "matte_fg": {d: [(0, 0, 9999, 9999, "lit", 45)] for d in ("front", "back", "left", "right")},
        "Idle": {
            "front": (48, 0, 658, 516),
            "back": (862, 0, 1486, 516),
            "left": (86, 517, 694, 1002),
            "right": (830, 517, 1448, 1002),
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
    "consumed": {
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py, 2026-10-25)
        # 2026-10-25: a gaunt long-limbed undead crawler with a gaping fanged
        # maw, in a bone-strewn cave. Drawn for the Consumed: it was put on
        # the Screecher by mistake and moved here on 2026-10-27 (designer). Its side labels are
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
        # 2026-10-27: the Granite Colossus redrawn — a hulking golem of mossy
        # cut stone with ember eyes — four labelled poses on black. Its side
        # labels are swapped (the "LEFT" panel faces right), so the poses are
        # picked by what they show.
        "src": "granite_colossus_board_v2.webp", "bg": "grabcut", "tiles": 2.6,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (157, 8, 658, 445),
            "back": (885, 12, 1375, 445),
            "left": (969, 520, 1283, 950),    # the board's "RIGHT"
            "right": (245, 512, 572, 950),    # the board's "LEFT"
        },
    },
    "grave_titan": {
        # 2026-10-25: the Grave Titan, a moss-grown stone giant in a bone crown
        # and tattered robes hauling a great boulder. The board came cut out
        # (kept with its transparency: its colours are read as they are, so
        # no white fringe; make_mattes judges it on white, as drawn). Its "NORTH"
        # pose shows the face and "SOUTH" the back: picked by what they show.
        "src": "grave_titan_board.png", "bg": "grabcut", "tiles": 2.2,
        # The painted ellipse under its feet goes — only the near-black of
        # it: its stone feet are grey and colourless too, and a looser cut
        # (lum < 80) took his feet and shins with the shadow (2026-10-27).
        "drop_shadow": (0.06, 30),
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (165, 100, 550, 575),
            "back": (720, 100, 1095, 575),
            "left": (215, 620, 520, 1120),
            "right": (745, 625, 1060, 1120),
        },
        # 2026-11-03: the designer's smash board — grave_titan_smash_board.webp,
        # "SMASH ATTACK (4 DIRECTIONS)", four labelled rows on black (NORTH
        # (FRONT), SOUTH (BACK), WEST (LEFT), EAST (RIGHT), the board's
        # "north" facing the camera), seven captioned frames a row: idle,
        # lift (start), overhead (raise), swing down (dark motion arcs about
        # the boulder), impact (rubble and dust thrown wide), recovery, and
        # return (idle). The arcs and the rubble are pieces apart from him
        # and are kept (`keep_share`); each box stops above its caption. The
        # board's idle is the height reference, matched to each facing's
        # Idle; its last frame is the idle again and is not played.
        "actions": {
            "src": "grave_titan_smash_board.webp",
            "shadow_band": 0.10,
            "shadow_lum": 45,   # the floor shadow is colourless grey under 45, brighter than his robe's solid level
            "levels": (4, 30, 6),   # his robe is near-black purple, just above the backdrop's 0-3
            "fill_holes": 4,   # a pocket brighter than the backdrop is his robe's painted folds
            "open_dark": True,   # the black between his legs and under his arms is backdrop, however small
            "keep_share": 0.002,   # the swing's arcs, the impact's rubble
            "glow": False,
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (155, 96, 320, 277),
                    "lift": (335, 94, 500, 276),
                    "overhead": (518, 63, 675, 277),
                    "swing": (683, 91, 849, 277),
                    "impact": (849, 134, 1067, 281),
                    "recover": (1067, 106, 1249, 278),
                    "back": (1252, 94, 1421, 277),
                },
                "back": {
                    "stance": (162, 332, 323, 510),
                    "lift": (338, 332, 501, 511),
                    "overhead": (515, 300, 678, 511),
                    "swing": (691, 338, 842, 512),
                    "impact": (842, 358, 1071, 514),
                    "recover": (1071, 346, 1253, 513),
                    "back": (1259, 332, 1423, 511),
                },
                "left": {
                    "stance": (165, 569, 306, 748),
                    "lift": (334, 564, 489, 748),
                    "overhead": (497, 533, 650, 748),
                    "swing": (661, 562, 828, 748),
                    "impact": (828, 606, 1058, 751),
                    "recover": (1058, 597, 1258, 748),
                    "back": (1265, 569, 1416, 748),
                },
                "right": {
                    "stance": (166, 815, 311, 993),
                    "lift": (337, 808, 496, 993),
                    "overhead": (513, 774, 671, 993),
                    "swing": (674, 815, 827, 993),
                    "impact": (827, 849, 1070, 997),
                    "recover": (1070, 840, 1262, 994),
                    "back": (1264, 815, 1411, 993),
                },
            },
            "sheets": {
                "Attack": ["lift", "overhead", "swing", "impact", "recover"],
            },
        },
    },
    "grave_titan_throw": {
        # 2026-11-03: the Grave Titan's boulder roll — grave_titan_throw_board.webp,
        # "BOULDER ROLL (ATTACK)", four labelled rows on black (NORTH (FRONT),
        # SOUTH (BACK), WEST (LEFT), EAST (RIGHT)), eight captioned frames a
        # row: idle (boulder on his shoulder), removing it, stepping in to
        # grip it with both hands, the wind-up, the full twisted wind-up,
        # the throw (motion lines past his arm), the boulder rolling away,
        # and his recovery (no boulder). The seventh frame draws only the
        # boulder in the side rows — the rolling boulder is its own sprite
        # (grave_titan_boulder) and he is not drawn leaving — so it is not
        # used. The frames crowd each other (a wind-up's dust reaches the
        # next frame's box): each frame's own pieces are kept (`isolate`).
        # Cut like his smash; packed into his folder as Throw.png, each
        # row's idle matched to that facing's Idle.
        "into": "grave_titan",
        "actions": {
            "src": "grave_titan_throw_board.webp",
            "shadow_band": 0.10,
            "shadow_lum": 45,
            "levels": (4, 30, 6),
            "fill_holes": 4,
            "open_dark": True,
            "keep_share": 0.002,   # the dust at his feet, the throw's motion lines
            "glow": False,
            "isolate": True,
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (105, 63, 266, 246),
                    "remove": (268, 63, 432, 247),
                    "grip": (417, 65, 582, 247),
                    "windup": (569, 66, 747, 247),
                    "full": (716, 63, 914, 247),
                    "throw": (877, 64, 1081, 247),
                    "recover": (1264, 59, 1421, 247),
                },
                "back": {
                    "stance": (105, 304, 267, 494),
                    "remove": (265, 304, 426, 492),
                    "grip": (418, 304, 585, 494),
                    "windup": (572, 304, 752, 494),
                    "full": (721, 304, 919, 493),
                    "throw": (888, 308, 1088, 493),
                    "recover": (1273, 304, 1420, 493),
                },
                "left": {
                    "stance": (114, 551, 254, 745),
                    "remove": (263, 549, 419, 744),
                    "grip": (396, 559, 578, 744),
                    "windup": (549, 555, 735, 742),
                    "full": (716, 550, 916, 743),
                    "throw": (869, 556, 1089, 743),
                    "recover": (1288, 563, 1430, 744),
                },
                "right": {
                    "stance": (112, 804, 254, 997),
                    "remove": (266, 805, 415, 997),
                    "grip": (403, 811, 590, 997),
                    "windup": (568, 806, 755, 997),
                    "full": (718, 806, 916, 996),
                    "throw": (881, 806, 1100, 996),
                    "recover": (1282, 804, 1429, 996),
                },
            },
            "sheets": {
                "Throw": ["remove", "grip", "windup", "full", "throw", "recover"],
            },
        },
    },
    "grave_titan_boulder": {
        # 2026-11-03: the boulder he rolls — grave_titan_boulder_strip.webp,
        # eight frames of the mossy boulder rolling to the right, cut out
        # (transparent), its painted shadow under it, pebbles and dust
        # thrown up behind it. Packed as one row, Boulder.png, into his
        # folder; Enemy's Boulder Roll sends it from his hands to the target
        # (SpriteEnemyFigure.throw_projectile, ThrownSprite), mirrored when it
        # rolls left. As wide as the boulder he carries: 1.1 tiles.
        "into": "grave_titan",
        "strip": {
            "src": "grave_titan_boulder_strip.webp",
            "sheet": "Boulder",
            "width_tiles": 1.1,
            "frames": [(10, 200, 250, 460), (260, 200, 500, 460), (505, 200, 750, 460), (750, 200, 1000, 460),
                       (1000, 200, 1250, 460), (1250, 200, 1500, 460), (1500, 200, 1750, 460), (1750, 200, 1990, 460)],
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
        # 2026-11-03: the designer's kick board — armored_troll_kick_board.webp,
        # "KICK ATTACK (4 DIRECTIONS x 7 FRAMES)", four labelled rows on
        # black (NORTH (FRONT), SOUTH (BACK), WEST (LEFT), EAST (RIGHT), the
        # board's "north" facing the camera), seven frames a row under
        # column captions: idle, shift, knee up, chamber (90 degrees), full
        # extend, recoil, return. Mid-kick his standing leg is drawn apart
        # from his body in the side rows, so every piece a frame owns is
        # kept (`keep_share`) and a neighbour's reaching into its box
        # blanked (`isolate`); each box runs to the row's ground line. Kick.png,
        # played for his Kick only (his Smash keeps its lunge); the idle is
        # the height reference, matched to each facing's Idle.
        "actions": {
            "src": "armored_troll_kick_board.webp",
            "levels": (4, 30, 6),   # his scale mail is near-black, just above the backdrop's 0
            "fill_holes": 4,
            "open_dark": True,
            "keep_share": 0.02,   # his standing leg mid-kick
            "glow": False,
            "isolate": True,
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (112, 85, 303, 283),
                    "shift": (302, 86, 495, 283),
                    "knee": (490, 83, 683, 283),
                    "chamber": (678, 83, 869, 283),
                    "extend": (873, 83, 1062, 283),
                    "recoil": (1059, 85, 1246, 283),
                    "back": (1244, 85, 1434, 283),
                },
                "back": {
                    "stance": (129, 304, 317, 500),
                    "shift": (319, 306, 510, 500),
                    "knee": (507, 304, 693, 500),
                    "chamber": (699, 304, 888, 500),
                    "extend": (892, 305, 1076, 500),
                    "recoil": (1081, 306, 1265, 500),
                    "back": (1265, 303, 1451, 500),
                },
                "left": {
                    "stance": (124, 522, 280, 730),
                    "shift": (313, 525, 466, 730),
                    "knee": (508, 521, 654, 730),
                    "chamber": (699, 523, 841, 730),
                    "extend": (877, 522, 1034, 730),
                    "recoil": (1079, 524, 1223, 730),
                    "back": (1258, 523, 1410, 730),
                },
                "right": {
                    "stance": (149, 757, 302, 960),
                    "shift": (342, 753, 489, 960),
                    "knee": (535, 755, 673, 960),
                    "chamber": (714, 754, 848, 960),
                    "extend": (903, 753, 1074, 960),
                    "recoil": (1096, 752, 1240, 960),
                    "back": (1282, 753, 1432, 960),
                },
            },
            "sheets": {
                "Kick": ["shift", "knee", "chamber", "extend", "recoil"],
            },
        },
    },
    "armored_troll_smash": {
        # 2026-11-03: the Armored Troll's smash — armored_troll_smash_board.webp,
        # "DOUBLE SMASH ATTACK", a table on black: four labelled rows (NORTH
        # (FRONT), SOUTH (BACK), WEST (LEFT), EAST (RIGHT), the board's
        # "north" facing the camera) of eight frames under numbered column
        # captions: idle, grip, raise (club overhead), smash 1 (the club into
        # the ground, a splash of earth), recoil (club up again), smash 2,
        # recovery, return. Each box stays inside its row's table lines.
        # Cut like his kick and packed into his folder as Attack.png: his
        # Smash plays it (his Kick has its own sheet); the idle is the height
        # reference, matched to each facing's Idle.
        "into": "armored_troll",
        "actions": {
            "src": "armored_troll_smash_board.webp",
            "levels": (4, 30, 6),
            "fill_holes": 4,
            "open_dark": True,
            "keep_share": 0.02,   # the smashes' flying earth
            "glow": False,
            "isolate": True,
            # The raised club's tip reaches the table line above the back,
            # left and right rows; the line's dim fringe (the box's top two
            # rows) would cling to it.
            "bg_boxes": {("back", "raise"): [(0, 0, 400, 2)], ("left", "raise"): [(0, 0, 400, 2)],
                         ("right", "raise"): [(0, 0, 400, 2)]},
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (136, 170, 290, 359),
                    "grip": (296, 173, 449, 359),
                    "raise": (459, 160, 610, 359),
                    "smash1": (626, 195, 790, 359),
                    "recoil": (804, 168, 942, 359),
                    "smash2": (955, 195, 1123, 359),
                    "recover": (1119, 169, 1274, 359),
                    "back": (1275, 171, 1437, 359),
                },
                "back": {
                    "stance": (144, 383, 298, 569),
                    "grip": (316, 386, 470, 569),
                    "raise": (468, 370, 609, 569),
                    "smash1": (622, 407, 795, 569),
                    "recoil": (807, 372, 938, 569),
                    "smash2": (950, 407, 1127, 569),
                    "recover": (1136, 385, 1295, 569),
                    "back": (1295, 383, 1437, 569),
                },
                "left": {
                    "stance": (136, 600, 266, 781),
                    "grip": (282, 600, 432, 781),
                    "raise": (458, 580, 602, 781),
                    "smash1": (591, 621, 779, 781),
                    "recoil": (768, 598, 929, 781),
                    "smash2": (930, 627, 1123, 781),
                    "recover": (1113, 599, 1255, 781),
                    "back": (1276, 600, 1419, 781),
                },
                "right": {
                    "stance": (151, 813, 290, 991),
                    "grip": (310, 812, 460, 991),
                    "raise": (462, 792, 606, 991),
                    "smash1": (616, 836, 795, 991),
                    "recoil": (804, 795, 928, 991),
                    "smash2": (942, 842, 1132, 991),
                    "recover": (1139, 813, 1292, 991),
                    "back": (1305, 812, 1437, 991),
                },
            },
            "sheets": {
                "Attack": ["grip", "raise", "smash1", "recoil", "smash2", "recover"],
            },
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
    "olorin_bear": {
        # 2026-11-01: Olorin's bear on its own — the designer's five poses on
        # a painted checker: facing up (its face), facing down (its back), the
        # two sides, and asleep. Idle is the standing bear; "Sleep" the curled
        # one (one pose, shown from every way), used by the title cutscene
        # where it dozes a few paces behind Olorin.
        "src": "olorin_bear_board.webp", "bg": "checker_light", "tiles": 1.6,
        "Idle": {
            "front": (72, 145, 294, 500),
            "back": (372, 145, 583, 493),
            "left": (615, 203, 1049, 490),
            "right": (1099, 203, 1528, 490),
        },
        "Sleep": {
            "front": (559, 645, 984, 891),
            "back": ("mirror", "front"),
            "left": (559, 645, 984, 891),
            "right": ("mirror", "front"),
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
        # 2026-11-01: the designer's attack board — mini_bear_attack_board.webp,
        # four labelled rows on black (NORTH (FRONT), SOUTH (BACK), LEFT,
        # RIGHT, the board's "north" facing the camera), the bear on a
        # painted floor shadow, ten frames a row: the stance twice, a paw
        # raised, the swipe, the paw coming down, a hunkered crouch, flat
        # on its face, rolled onto its back, rising, and the stance. The
        # whole of it is the Attack: a cute little bear that swipes, goes
        # over in a heap and scrambles back up (designer, 2026-11-01). The
        # stance is the height reference, matched to each facing's Idle.
        "actions": {
            "src": "mini_bear_attack_board.webp",
            "shadow_band": 0.10,
            "levels": (4, 36, 8),   # the underside's fur is near-black; the backdrop is pure black
            "fill_holes": 5,
            "match_scale": {"front": 1.08, "back": 1.08, "left": 1.15, "right": 1.15},   # the board draws him taller in proportion than his Idle: matched by bulk, not height
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (128, 85, 243, 248),
                    "raise": (410, 85, 535, 248),
                    "swipe": (558, 85, 681, 248),
                    "follow": (705, 93, 819, 248),
                    "settle": (841, 103, 962, 248),
                    "flat": (974, 140, 1110, 248),
                    "roll": (1114, 124, 1250, 248),
                    "rise": (1257, 112, 1384, 248),
                },
                "back": {
                    "stance": (129, 315, 241, 480),
                    "raise": (406, 315, 528, 480),
                    "swipe": (551, 315, 680, 480),
                    "follow": (700, 320, 822, 480),
                    "settle": (845, 333, 964, 480),
                    "flat": (980, 366, 1113, 480),
                    "roll": (1119, 352, 1253, 480),
                    "rise": (1264, 342, 1392, 480),
                },
                "left": {
                    "stance": (114, 552, 251, 688),
                    "raise": (391, 548, 534, 688),
                    "swipe": (538, 545, 677, 688),
                    "follow": (681, 553, 819, 688),
                    "settle": (823, 574, 966, 688),
                    "flat": (970, 593, 1113, 688),
                    "roll": (1113, 571, 1246, 688),
                    "rise": (1246, 566, 1385, 688),
                },
                "right": {
                    "stance": (114, 764, 255, 900),
                    "raise": (394, 758, 536, 900),
                    "swipe": (541, 755, 682, 900),
                    "follow": (691, 766, 826, 900),
                    "settle": (831, 787, 974, 900),
                    "flat": (980, 807, 1123, 900),
                    "roll": (1116, 786, 1249, 900),
                    "rise": (1250, 779, 1393, 900),
                },
            },
            "sheets": {
                "Attack": ["raise", "swipe", "follow", "settle", "flat", "roll", "rise"],
            },
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
        # 2026-10-31: the designer's slash board — skeleton_slash_board.webp,
        # four labelled rows on black (NORTH (FRONT), SOUTH (BACK), WEST
        # (LEFT), EAST (RIGHT), the board's "north" facing the camera): the
        # stance, the scimitar raised, the downward slash (a grey arc
        # trailing the blade), the follow-through at the ground in sparks,
        # the recovery, and the stance again. The stance is the height
        # reference, matched to each facing's Idle. The cloak's dark folds
        # are paint: every pocket inside the outline is solid.
        "actions": {
            "src": "skeleton_slash_board.webp",
            "shadow_band": 0.08,
            "keep_share": 0.035,
            "fill_holes": 7,   # the cloak's folds are painted (lum 10+); the black between his legs is the backdrop (3-5)
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (108, 40, 340, 262),
                    "windup": (350, 5, 545, 262),
                    "slash": (548, 30, 785, 262),
                    "follow": (788, 70, 1045, 262),
                    "recover": (1050, 55, 1268, 262),
                },
                "back": {
                    "stance": (150, 290, 375, 505),
                    "windup": (378, 265, 581, 505),
                    "slash": (582, 268, 795, 505),
                    "follow": (800, 320, 1050, 505),
                    "recover": (1055, 310, 1290, 505),
                },
                "left": {
                    "stance": (120, 530, 300, 755),
                    "windup": (370, 515, 540, 755),
                    "slash": (555, 535, 780, 755),
                    "follow": (783, 575, 1050, 755),
                    "recover": (1075, 548, 1290, 755),
                },
                "right": {
                    "stance": (150, 772, 330, 998),
                    "windup": (385, 760, 550, 998),
                    "slash": (555, 765, 790, 998),
                    "follow": (790, 815, 1050, 998),
                    "recover": (1052, 800, 1265, 998),
                },
            },
            "sheets": {
                "Attack": ["windup", "slash", "follow", "recover"],
            },
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
        # 2026-11-04: the designer's Venom Spray board — sewer_cobra_spray_board.webp,
        # "SEWER COBRA - VENOM SPRAY", four labelled rows in framed panels on
        # black (NORTH: the face, SOUTH: the back, WEST, EAST), eight
        # numbered frames a row: the stance, venom welling in its jaws, the
        # mouth opening, the spray starting, spraying, the full spray, the
        # spray dying, at rest. The spray is drawn from its mouth into the
        # neighbouring frame's space: each row is split at the contacts
        # (`split`), so every frame keeps its own spray. Frames 2-8 are
        # Cast.png, for its Venom Spray; the stance matched to its Idle. The
        # side rows' spraying boxes reach out the way the spray goes.
        "actions": {
            "src": "sewer_cobra_spray_board.webp",
            "levels": (4, 30, 6),    # its black scales and dark collar run just above the backdrop's 0
            "fill_holes": 22,        # its painted shading is brighter; the spray's faint haze between streaks stays open
            "open_dark": True,
            "keep_share": 0.01,      # the spray's droplets
            "glow": False,
            "split": True,
            "isolate_floor": 6,
            "split_floor": 30,       # split on its bright parts: the venom haze no longer bridges frames
            # Its body columns (the side rows' spraying boxes are widened).
            "split_centres": {"front": [188, 367, 541, 717, 897, 1076, 1255, 1432],
                              "back": [188, 367, 541, 717, 897, 1076, 1255, 1432],
                              "left": [214, 382, 560, 720, 905, 1080, 1265, 1452],
                              "right": [168, 342, 518, 700, 885, 1065, 1250, 1420]},
            "drop_dim_green": 45,    # the haze painted on black: a dark smudge on a lit floor
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (110, 70, 277, 292),
                    "draw": (277, 70, 454, 292),
                    "open": (454, 70, 629, 292),
                    "spit": (629, 70, 807, 292),
                    "spray": (807, 70, 986, 292),
                    "full": (986, 70, 1165, 292),
                    "trail": (1165, 70, 1343, 292),
                    "rest": (1343, 70, 1524, 292),
                },
                "back": {
                    "stance": (110, 302, 277, 529),
                    "draw": (277, 302, 454, 529),
                    "open": (454, 302, 629, 529),
                    "spit": (629, 302, 807, 529),
                    "spray": (807, 302, 986, 529),
                    "full": (986, 302, 1165, 529),
                    "trail": (1165, 302, 1343, 529),
                    "rest": (1343, 302, 1524, 529),
                },
                "left": {
                    "stance": (110, 538, 278, 750),
                    "draw": (278, 538, 455, 750),
                    "open": (455, 538, 625, 750),
                    "spit": (545, 538, 795, 750),
                    "spray": (715, 538, 970, 750),
                    "full": (890, 538, 1148, 750),
                    "trail": (1068, 538, 1341, 750),
                    "rest": (1341, 538, 1524, 750),
                },
                "right": {
                    "stance": (110, 758, 269, 975),
                    "draw": (269, 758, 445, 975),
                    "open": (445, 758, 629, 975),
                    "spit": (629, 758, 906, 975),
                    "spray": (826, 758, 1093, 975),
                    "full": (1013, 758, 1260, 975),
                    "trail": (1180, 758, 1429, 975),
                    "rest": (1349, 758, 1524, 975),
                },
            },
            "sheets": {
                "Cast": ["draw", "open", "spit", "spray", "full", "trail", "rest"],
            },
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
        # 2026-11-04: the designer's wing-flap board — ash_harpy_flap_board.webp,
        # cut out (transparent), four labelled rows (NORTH: the face, SOUTH:
        # the back, LEFT, RIGHT) under numbered columns, eight frames a row:
        # wings folded, rising, spread wide, flung up, sweeping down, folding
        # in, folded. Her wings are so wide the frames touch: each row is
        # split along the narrowest contact between neighbours
        # (`alpha_split`). Cast.png is frames 2-8 three times over — the
        # designer: she flaps three times while her vortex steals a card —
        # played for her Card Steal; frame 1 is the height reference.
        "actions": {
            "src": "ash_harpy_flap_board.webp",
            "bg": "alpha_split",
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (95, 28, 212, 207),
                    "f2": (212, 28, 348, 207),
                    "f3": (348, 28, 479, 207),
                    "f4": (479, 28, 610, 207),
                    "f5": (610, 28, 741, 207),
                    "f6": (741, 28, 869, 207),
                    "f7": (869, 28, 997, 207),
                    "f8": (997, 28, 1125, 207),
                },
                "back": {
                    "stance": (95, 212, 212, 397),
                    "f2": (212, 212, 348, 397),
                    "f3": (348, 212, 479, 397),
                    "f4": (479, 212, 610, 397),
                    "f5": (610, 212, 741, 397),
                    "f6": (741, 212, 869, 397),
                    "f7": (869, 212, 997, 397),
                    "f8": (997, 212, 1125, 397),
                },
                "left": {
                    "stance": (95, 400, 212, 597),
                    "f2": (212, 400, 348, 597),
                    "f3": (348, 400, 479, 597),
                    "f4": (479, 400, 610, 597),
                    "f5": (610, 400, 741, 597),
                    "f6": (741, 400, 869, 597),
                    "f7": (869, 400, 997, 597),
                    "f8": (997, 400, 1125, 597),
                },
                "right": {
                    "stance": (95, 598, 212, 793),
                    "f2": (212, 598, 348, 793),
                    "f3": (348, 598, 479, 793),
                    "f4": (479, 598, 610, 793),
                    "f5": (610, 598, 741, 793),
                    "f6": (741, 598, 869, 793),
                    "f7": (869, 598, 997, 793),
                    "f8": (997, 598, 1125, 793),
                },
            },
            "sheets": {
                "Cast": ["f2", "f3", "f4", "f5", "f6", "f7", "f8", "f2", "f3", "f4", "f5", "f6", "f7", "f8", "f2", "f3", "f4", "f5", "f6", "f7", "f8"],
            },
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
        # 2026-11-03: the designer's snowball board — snow_wraith_snowball_board.webp,
        # four labelled rows on black (NORTH, SOUTH, WEST, EAST; "north"
        # facing the camera, as on her pose board), seven frames a row: the
        # stance, a swirl of frost gathering at her hand, the snowball
        # formed and glowing, raised, thrown (the ball leaving her
        # fingers), the follow-through, and the stance. The frost and the
        # ball are pieces apart from her and are kept (`keep_share`); a
        # neighbour's reaching into a box is blanked (`isolate`). Throw.png,
        # played for her Snowball (her Ice Blast keeps its lunge); the
        # stance is the height reference, matched to each facing's Idle.
        "actions": {
            "src": "snow_wraith_snowball_board.webp",
            "levels": (4, 30, 6),   # her cloak's shadows are near-black navy, just above the backdrop's 0
            "fill_holes": 4,
            "open_dark": True,
            "keep_share": 0.001,   # the frost swirl's motes, the snowball in flight
            "glow": False,
            "isolate": True,
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (90, 7, 295, 250),
                    "gather": (288, 7, 485, 250),
                    "form": (479, 7, 675, 250),
                    "raise": (667, 7, 869, 250),
                    "throw": (857, 7, 1064, 250),
                    "follow": (1051, 7, 1258, 250),
                    "back": (1247, 7, 1448, 250),
                },
                "back": {
                    "stance": (103, 272, 301, 512),
                    "gather": (300, 272, 486, 512),
                    "form": (489, 272, 675, 512),
                    "raise": (666, 272, 873, 512),
                    "throw": (862, 272, 1077, 512),
                    "follow": (1057, 272, 1257, 512),
                    "back": (1256, 272, 1448, 512),
                },
                "left": {
                    "stance": (120, 547, 302, 776),
                    "gather": (296, 547, 489, 776),
                    "form": (479, 547, 675, 776),
                    "raise": (662, 547, 869, 776),
                    "throw": (820, 547, 1065, 776),
                    "follow": (1037, 548, 1261, 776),
                    "back": (1270, 547, 1448, 776),
                },
                "right": {
                    "stance": (83, 811, 270, 1045),
                    "gather": (275, 811, 475, 1045),
                    "form": (468, 811, 666, 1045),
                    "raise": (662, 812, 867, 1045),
                    "throw": (851, 812, 1087, 1045),
                    "follow": (1046, 811, 1259, 1045),
                    "back": (1241, 811, 1420, 1045),
                },
            },
            "sheets": {
                "Throw": ["gather", "form", "raise", "throw", "follow"],
            },
        },
    },
    "snow_wraith_snowball": {
        # 2026-11-03: the Snow Wraith's snowball in flight —
        # snow_wraith_snowball_strip.webp, eight frames of the snowball
        # flying right, cut out (transparent): a packed ball with a frosty
        # trail streaming behind it, sparkles about it and a blue glow,
        # turning over as it flies. Snowball.png in her folder; her Snowball
        # sends it from her hand to the target (SpriteEnemyFigure.
        # throw_projectile, ThrownSprite), mirrored when it flies left. The
        # first frame (ball, trail and sparkles) 0.45 tiles wide: the ball
        # about 0.3, a little bigger than in her hand so it reads in flight.
        "into": "snow_wraith",
        "strip": {
            "src": "snow_wraith_snowball_strip.webp",
            "sheet": "Snowball",
            "width_tiles": 0.45,
            "align": "board",
            "frames": [(0, 380, 217, 600), (217, 380, 420, 600), (420, 380, 626, 600), (626, 380, 834, 600), (834, 380, 1045, 600), (1045, 380, 1259, 600), (1259, 380, 1465, 600), (1465, 380, 1672, 600)],
        },
    },
    "snow_wraith_ice_blast": {
        # 2026-11-03: the Snow Wraith's Ice Blast — snow_wraith_ice_blast_board.webp,
        # four labelled rows on black (NORTH, SOUTH, LEFT, RIGHT; "north"
        # facing the camera), eleven frames a row: the stance, her arms
        # rising, spread, a crystal forming at her breast, growing, ringed
        # in frost, full, her arm thrown out (the crystal gone), then the ice
        # spear flying off from her hand and breaking up, and the stance.
        # The spear touches her hand from the eighth frame (in the left row
        # three frames and their spears run together), so the cast is cut
        # through her thrown-out arm and holds it while the spear flies: the
        # flying ice is its own sprite (snow_wraith_ice_shard). Cut like her
        # snowball and packed into her folder as Cast.png; the stance is the
        # height reference, matched to each facing's Idle.
        "into": "snow_wraith",
        "actions": {
            "src": "snow_wraith_ice_blast_board.webp",
            "levels": (14, 45, 18),   # the crystal's and hands' glow fades out through dim navy: above that, so it doesn't ring them dark
            "fill_holes": 8,
            "open_dark": True,
            "glow": False,
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (100, 0, 233, 166),
                    "arms": (277, 0, 404, 166),
                    "open": (446, 0, 577, 166),
                    "form": (618, 0, 752, 166),
                    "grow": (790, 0, 926, 166),
                    "crystal": (961, 0, 1099, 166),
                    "extend": (1136, 0, 1291, 166),
                    "hold": ("same", "extend"),
                },
                "back": {
                    "stance": (108, 168, 236, 334),
                    "arms": (283, 168, 407, 334),
                    "open": (450, 168, 579, 334),
                    "form": (623, 168, 752, 334),
                    "grow": (792, 168, 927, 334),
                    "crystal": (961, 168, 1100, 334),
                    "extend": (1138, 168, 1291, 334),
                    "hold": ("same", "extend"),
                },
                "left": {
                    "stance": (112, 337, 237, 499),
                    "arms": (281, 337, 408, 499),
                    "open": (436, 337, 581, 499),
                    "form": (601, 337, 751, 499),
                    "grow": (765, 337, 923, 499),
                    "crystal": (932, 337, 1093, 499),
                    "extend": (1097, 337, 1252, 499),
                    "hold": ("same", "extend"),
                },
                "right": {
                    "stance": (80, 499, 202, 667),
                    "arms": (231, 499, 368, 667),
                    "open": (400, 499, 541, 667),
                    "form": (567, 499, 710, 667),
                    "grow": (736, 499, 881, 667),
                    "crystal": (904, 499, 1044, 667),
                    "extend": (1072, 499, 1219, 667),
                    "hold": ("same", "extend"),
                },
            },
            "sheets": {
                "Cast": ["arms", "open", "form", "grow", "crystal", "extend", "hold"],
            },
        },
    },
    "snow_wraith_ice_shard": {
        # 2026-11-03: the ice in flight — snow_wraith_ice_shard_strip.webp,
        # eight frames of a jagged ice spear flying right, cut out
        # (transparent), splinters peeling off behind it, smaller as it
        # goes. IceShard.png in her folder; her Ice Blast sends it from her
        # hand to the target (ThrownSprite), mirrored when it flies left.
        # The first frame 1.3 tiles long.
        "into": "snow_wraith",
        "strip": {
            "src": "snow_wraith_ice_shard_strip.webp",
            "sheet": "IceShard",
            "width_tiles": 1.3,
            "align": "board",
            "frames": [(30, 240, 245, 380), (280, 240, 495, 380), (530, 240, 745, 380), (780, 240, 995, 380), (1005, 240, 1250, 380), (1290, 240, 1500, 380), (1550, 240, 1750, 380), (1800, 240, 1995, 380)],
        },
    },
    "ash_harpy_vortex": {
        # 2026-11-04: the Card Steal vortex — ash_harpy_vortex_strip.webp, a
        # 12-wide grid of frames on black: a wind vortex of dark smoke and
        # embers that starts at the player (each frame's right end), grows
        # toward the harpy (its left end), sweeps a small card round inside
        # it back to her — the card gone as it reaches her — and blows
        # itself out. The grid's first five frames and last two are empty
        # and left out. Cut by brightness with soft alpha (`black_key`), each
        # frame keeping its whole box (`trim` off: where the vortex sits in
        # its frame is the animation); Vortex.png in her folder. Her Card
        # Steal lays it from her to the player (ArcBolt), stretched to the
        # distance, through her three flaps.
        "into": "ash_harpy",
        "strip": {
            "src": "ash_harpy_vortex_strip.webp",
            "bg": "black_key",
            "sheet": "Vortex",
            "width_tiles": 1.4,
            "trim": False,
            "alpha_gain": 1.4,
            "frames": [(697, -4, 836, 114), (836, -4, 975, 114), (975, -4, 1115, 114), (1115, -4, 1254, 114), (1254, -4, 1393, 114), (1393, -4, 1533, 114), (1533, -4, 1672, 114), (0, 112, 139, 230), (139, 112, 279, 230), (279, 112, 418, 230), (418, 112, 557, 230), (557, 112, 697, 230), (697, 112, 836, 230), (836, 112, 975, 230), (975, 112, 1115, 230), (1115, 112, 1254, 230), (1254, 112, 1393, 230), (1393, 112, 1533, 230), (1533, 112, 1672, 230), (0, 231, 139, 349), (139, 231, 279, 349), (279, 231, 418, 349), (418, 231, 557, 349), (557, 231, 697, 349), (697, 231, 836, 349), (836, 231, 975, 349), (975, 231, 1115, 349), (1115, 231, 1254, 349), (1254, 231, 1393, 349), (1393, 231, 1533, 349), (1533, 231, 1672, 349), (0, 351, 139, 469), (139, 351, 279, 469), (279, 351, 418, 469), (418, 351, 557, 469), (557, 351, 697, 469), (697, 351, 836, 469), (836, 351, 975, 469), (975, 351, 1115, 469), (1115, 351, 1254, 469), (1254, 351, 1393, 469), (1393, 351, 1533, 469), (1533, 351, 1672, 469), (0, 470, 139, 588), (139, 470, 279, 588), (279, 470, 418, 588), (418, 470, 557, 588), (557, 470, 697, 588), (697, 470, 836, 588), (836, 470, 975, 588), (975, 470, 1115, 588), (1115, 470, 1254, 588), (1254, 470, 1393, 588), (1393, 470, 1533, 588), (1533, 470, 1672, 588), (0, 590, 139, 708), (139, 590, 279, 708), (279, 590, 418, 708), (418, 590, 557, 708), (557, 590, 697, 708), (697, 590, 836, 708), (836, 590, 975, 708), (975, 590, 1115, 708), (1115, 590, 1254, 708), (1254, 590, 1393, 708), (1393, 590, 1533, 708), (1533, 590, 1672, 708), (0, 702, 139, 820), (139, 702, 279, 820), (279, 702, 418, 820), (418, 702, 557, 820), (557, 702, 697, 820), (697, 702, 836, 820), (836, 702, 975, 820), (975, 702, 1115, 820), (1115, 702, 1254, 820), (1254, 702, 1393, 820)],
        },
    },
    "succubus_snap": {
        # 2026-11-04: the Succubus's Damaging Snap — succubus_snap_board.webp,
        # "SUCCUBUS - FINGER SNAP", four labelled rows in framed panels on
        # black (NORTH: the face, SOUTH: the back, WEST, EAST), eight
        # numbered frames a row: the stance, raising her hand, lifting it,
        # pointing, pinching her fingers, ready, the snap, and the flash of
        # the snap (a blue star at her fingers). Frames 2-8 are Attack.png,
        # packed into her folder, for her Damaging Snap; the scythe it sends
        # is its own sprite (succubus_scythe).
        "into": "succubus",
        "actions": {
            "src": "succubus_snap_board.webp",
            "levels": (8, 36, 10),
            "fill_holes": 20,
            "open_dark": True,
            "keep_share": 0.002,     # the snap's flash
            "glow": False,
            "isolate": True,
            "isolate_floor": 12,
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (100, 72, 275, 293),
                    "raise": (275, 72, 451, 293),
                    "lift": (451, 72, 627, 293),
                    "point": (627, 72, 805, 293),
                    "pinch": (805, 72, 983, 293),
                    "ready": (983, 72, 1162, 293),
                    "snap": (1162, 72, 1343, 293),
                    "flash": (1343, 72, 1524, 293),
                },
                "back": {
                    "stance": (100, 301, 275, 527),
                    "raise": (275, 301, 451, 527),
                    "lift": (451, 301, 629, 527),
                    "point": (629, 301, 806, 527),
                    "pinch": (806, 301, 983, 527),
                    "ready": (983, 301, 1163, 527),
                    "snap": (1163, 301, 1345, 527),
                    "flash": (1345, 301, 1524, 527),
                },
                "left": {
                    "stance": (100, 536, 277, 744),
                    "raise": (277, 536, 453, 744),
                    "lift": (453, 536, 629, 744),
                    "point": (629, 536, 806, 744),
                    "pinch": (806, 536, 984, 744),
                    "ready": (984, 536, 1165, 744),
                    "snap": (1165, 536, 1346, 744),
                    "flash": (1346, 536, 1524, 744),
                },
                "right": {
                    "stance": (100, 751, 265, 976),
                    "raise": (265, 751, 442, 976),
                    "lift": (442, 751, 619, 976),
                    "point": (619, 751, 797, 976),
                    "pinch": (797, 751, 973, 976),
                    "ready": (973, 751, 1152, 976),
                    "snap": (1152, 751, 1335, 976),
                    "flash": (1335, 751, 1524, 976),
                },
            },
            "sheets": {
                "Attack": ["raise", "lift", "point", "pinch", "ready", "snap", "flash"],
            },
        },
    },
    "succubus_scythe": {
        # The scythe her snap sends — succubus_scythe_strip.webp, "MINI
        # REAPER SCYTHE (SPINNING PROJECTILE)", eight numbered frames in a
        # framed panel on black of a small reaper's scythe spinning in a
        # blue glow (the eighth is the first again: seven are used). Cut by
        # brightness with soft alpha; Scythe.png in her folder; her Damaging
        # Snap sends it spinning at her victim (ThrownSprite). 0.6 tiles.
        "into": "succubus",
        "strip": {
            "src": "succubus_scythe_strip.webp",
            "bg": "black_key",
            "sheet": "Scythe",
            "width_tiles": 0.6,
            "width_of": "max",
            "align": "board",
            "frames": [(35, 428, 220, 618), (220, 428, 406, 618), (406, 428, 592, 618), (592, 428, 777, 618), (777, 428, 964, 618), (964, 428, 1151, 618), (1151, 428, 1339, 618)],
        },
    },
    "succubus_orb": {
        # The ball of drained mana: the left row's ball on her drain board,
        # cut by brightness with soft alpha. Orb.png in her folder; her Mana
        # Drain sends it from her target back to her hand (ThrownSprite,
        # reversed). 0.35 tiles.
        "into": "succubus",
        "strip": {
            "src": "succubus_drain_board.webp",
            "bg": "black_key",
            "sheet": "Orb",
            "width_tiles": 0.35,
            "frames": [(1088, 573, 1134, 619)],
        },
    },
    "treasure_bunny_vanish": {
        # 2026-11-04: the Treasure Bunny's escape — treasure_bunny_vanish_strip.webp,
        # "VANISH SMOKE - SAD FROWN (8 FRAMES)", eight numbered frames in a
        # framed panel on black: a puff of grey smoke rising from the
        # ground, billowing into a cloud with a sad frowning face, thinning
        # and drifting away. Cut by brightness with soft alpha (smoke);
        # Smoke.png in its folder; its Vanish plays it where it stood
        # (SpotEffect), the bunny gone as the cloud covers it. The fullest
        # cloud 1.3 tiles wide.
        "into": "treasure_bunny",
        "strip": {
            "src": "treasure_bunny_vanish_strip.webp",
            "bg": "black_key",
            "sheet": "Smoke",
            "width_tiles": 1.3,
            "width_of": "max",
            "align": "board",
            "alpha_gain": 1.3,
            "frames": [(20, 428, 203, 640), (203, 428, 392, 640), (392, 428, 583, 640), (583, 428, 780, 640), (780, 428, 977, 640), (977, 428, 1165, 640), (1165, 428, 1348, 640), (1348, 428, 1520, 640)],
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
        # 2026-11-04: the designer's throw board — sludge_throw_board.webp,
        # four labelled rows on black (NORTH: the face, SOUTH: the back,
        # WEST, EAST), eight frames a row: holding the ball of slime up (its
        # Idle), drawing it back, coiling, swinging, the throw, the follow-
        # through as the ball flies off (the board draws it flying across
        # the next frames' boxes), lowering its arm, at rest. Frames 2-8 are
        # Throw.png, for its Spit; the ball in flight is its own sprite
        # (sludge_ball). The row is split at the frames' contacts (`split`),
        # the thrown balls seeded to go with what lies nearest them
        # (`discard`); the first frame (the ball held, as its Idle) is the
        # height reference.
        "actions": {
            "src": "sludge_throw_board.webp",
            "levels": (8, 40, 12),   # its dark shading runs just above the backdrop's 0
            "fill_holes": 8,
            "open_dark": True,
            "keep_share": 0.2,       # a drop of slime falls away; the ball's own drips with it
            "glow": False,
            "split": True,
            "isolate_floor": 16,
            "discard": {"back": [(1155, 232), (1372, 222)],
                        "left": [(989, 491), (1200, 487)],
                        "right": [(1202, 706), (1424, 710)]},
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (110, 5, 316, 208),
                    "lift": (316, 5, 536, 208),
                    "coil": (536, 5, 765, 208),
                    "swing": (765, 5, 996, 208),
                    "throw": ("same", "swing"),   # its ball is painted over its puddle and cannot be parted from it: the swing held
                    "follow": (1222, 5, 1436, 208),
                    "lower": (1436, 5, 1623, 208),
                    "rest": (1623, 5, 1774, 208),
                },
                "back": {
                    "stance": (110, 208, 313, 405),
                    "lift": (313, 208, 542, 405),
                    "coil": (542, 208, 769, 405),
                    "swing": (769, 208, 993, 405),
                    "throw": (993, 208, 1210, 405),
                    "follow": (1210, 208, 1420, 405),
                    "lower": (1420, 208, 1616, 405),
                    "rest": (1616, 208, 1774, 405),
                },
                "left": {
                    "stance": (110, 410, 317, 628),
                    "lift": (317, 410, 530, 628),
                    "coil": (530, 410, 751, 628),
                    "swing": (751, 410, 992, 628),
                    "throw": (992, 410, 1215, 628),
                    "follow": (1215, 410, 1429, 628),
                    "lower": (1429, 410, 1619, 628),
                    "rest": (1619, 410, 1774, 628),
                },
                "right": {
                    "stance": (110, 632, 303, 850),
                    "lift": (303, 632, 527, 850),
                    "coil": (527, 632, 759, 850),
                    "swing": (759, 632, 988, 850),
                    "throw": (988, 632, 1195, 850),
                    "follow": (1195, 632, 1413, 850),
                    "lower": (1413, 632, 1612, 850),
                    "rest": (1612, 632, 1774, 850),
                },
            },
            "sheets": {
                "Throw": ["lift", "coil", "swing", "throw", "follow", "lower", "rest"],
            },
        },
    },
    "sewer_cobra_bite": {
        # 2026-11-04: the Sewer Cobra's Bite — sewer_cobra_bite_board.webp,
        # "SEWER COBRA - BITE ATTACK", the same four framed rows as its spray
        # board, eight numbered frames a row: the stance, rearing back, coiled
        # with the jaws open, the strike (motion arcs and a spatter of
        # venom), the bite, snapping shut, recovering, at rest. Frames 2-8
        # are Attack.png, packed into its folder, for its Bite; cut like its
        # spray, the green motion arcs kept.
        "into": "sewer_cobra",
        "actions": {
            "src": "sewer_cobra_bite_board.webp",
            "levels": (4, 30, 6),
            "fill_holes": 22,
            "open_dark": True,
            "keep_share": 0.01,      # the strike's arcs, the venom spatter
            "glow": False,
            "split": True,
            "isolate_floor": 6,
            "split_floor": 30,
            "split_centres": {"front": [190, 368, 541, 718, 898, 1076, 1252, 1435], "back": [190, 370, 543, 722, 898, 1080, 1255, 1435], "left": [180, 360, 525, 705, 895, 1080, 1265, 1440], "right": [180, 360, 535, 710, 900, 1080, 1265, 1435]},
            "drop_dim_green": 28,    # the faintest of the arcs' glow only: the arcs themselves stay
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (105, 70, 279, 292),
                    "rear": (279, 70, 454, 292),
                    "coil": (454, 70, 629, 292),
                    "strike": (629, 70, 808, 292),
                    "bite": (808, 70, 987, 292),
                    "snap": (987, 70, 1164, 292),
                    "recover": (1164, 70, 1343, 292),
                    "rest": (1343, 70, 1524, 292),
                },
                "back": {
                    "stance": (105, 302, 280, 527),
                    "rear": (280, 302, 456, 527),
                    "coil": (456, 302, 632, 527),
                    "strike": (632, 302, 810, 527),
                    "bite": (810, 302, 989, 527),
                    "snap": (989, 302, 1167, 527),
                    "recover": (1167, 302, 1345, 527),
                    "rest": (1345, 302, 1524, 527),
                },
                "left": {
                    "stance": (105, 538, 270, 748),
                    "rear": (270, 538, 442, 748),
                    "coil": (442, 538, 615, 748),
                    "strike": (615, 538, 800, 748),
                    "bite": (800, 538, 987, 748),
                    "snap": (987, 538, 1172, 748),
                    "recover": (1172, 538, 1352, 748),
                    "rest": (1352, 538, 1524, 748),
                },
                "right": {
                    "stance": (105, 758, 270, 975),
                    "rear": (270, 758, 447, 975),
                    "coil": (447, 758, 622, 975),
                    "strike": (622, 758, 805, 975),
                    "bite": (805, 758, 990, 975),
                    "snap": (990, 758, 1172, 975),
                    "recover": (1172, 758, 1350, 975),
                    "rest": (1350, 758, 1524, 975),
                },
            },
            "sheets": {
                "Attack": ["rear", "coil", "strike", "bite", "snap", "recover", "rest"],
            },
        },
    },
    "sludge_hammer": {
        # 2026-11-04: the Sludge Being's melee — sludge_hammer_board.webp,
        # "SLUDGE HAMMER ATTACK (MELEE)", four labelled rows in framed
        # panels on black (NORTH: the face, SOUTH: the back, WEST, EAST),
        # eight numbered frames a row: the ball held up (its Idle), the ball
        # swelling, morphing into a hammer of slime, raised, swung (motion
        # arcs), brought down, the smash in a splash of slime, and at rest
        # with the hammer melted back. Frames 2-8 are Attack.png, packed into
        # its folder, for its melee; the arcs and the splash are pieces apart
        # from it and kept. The boxes stay inside the panel lines and below
        # the column numbers; the bright rows between frames are its
        # puddles lining up, not lines.
        "into": "sludge",
        "actions": {
            "src": "sludge_hammer_board.webp",
            "levels": (8, 40, 12),
            "fill_holes": 8,
            "open_dark": True,
            "keep_share": 0.03,      # the swing's arcs, the splash
            "glow": False,
            "isolate": True,
            "isolate_floor": 16,
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (105, 70, 279, 294),
                    "morph": (279, 70, 451, 294),
                    "raise": (451, 70, 624, 294),
                    "hammer": (624, 70, 797, 294),
                    "swing": (797, 70, 982, 294),
                    "smash": (982, 70, 1158, 294),
                    "splash": (1158, 70, 1341, 294),
                    "rest": (1341, 70, 1510, 294),
                },
                "back": {
                    "stance": (115, 302, 282, 527),
                    "morph": (282, 302, 454, 527),
                    "raise": (454, 302, 637, 527),
                    "hammer": (637, 302, 813, 527),
                    "swing": (813, 302, 990, 527),
                    "smash": (990, 302, 1165, 527),
                    "splash": (1165, 302, 1353, 527),
                    "rest": (1353, 302, 1522, 527),
                },
                "left": {
                    "stance": (102, 535, 282, 743),
                    "morph": (282, 535, 453, 743),
                    "raise": (453, 535, 623, 743),
                    "hammer": (623, 535, 798, 743),
                    "swing": (798, 535, 985, 743),
                    "smash": (985, 535, 1156, 743),
                    "splash": (1156, 535, 1346, 743),
                    "rest": (1346, 535, 1516, 743),
                },
                "right": {
                    "stance": (107, 752, 281, 977),
                    "morph": (281, 752, 449, 977),
                    "raise": (449, 752, 633, 977),
                    "hammer": (633, 752, 809, 977),
                    "swing": (809, 752, 992, 977),
                    "smash": (992, 752, 1161, 977),
                    "splash": (1161, 752, 1349, 977),
                    "rest": (1349, 752, 1524, 977),
                },
            },
            "sheets": {
                "Attack": ["morph", "raise", "hammer", "swing", "smash", "splash", "rest"],
            },
        },
    },
    "sludge_ball": {
        # The ball of slime in flight: the East row's ball as it leaves the
        # hand, flying right, cut by brightness with soft alpha. Ball.png in
        # its folder; its Spit throws it at its prey (ThrownSprite),
        # mirrored when it flies left. As big as the ball it holds.
        "into": "sludge",
        "strip": {
            "src": "sludge_throw_board.webp",
            "bg": "black_key",
            "sheet": "Ball",
            "width_tiles": 0.55,
            "frames": [(1172, 682, 1234, 731)],
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
    "fire_goblin_shaman": {
        # 2026-10-28: the Fire Goblin Shaman — a goblin in a tattered,
        # rune-hemmed crimson robe, a skull and fangs at his throat, a
        # twisted iron staff crowned with fire — FRONT, BACK, LEFT, RIGHT on
        # black, each side facing its own way; his own board (he wore the
        # soldier's until now). The height counts the staff's flame.
        "src": "fire_goblin_shaman_board.webp", "bg": "grabcut", "tiles": 1.65,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        # The model trims the flame's wisps: keep what is lit.
        "matte_fg": {d: [(0, 0, 9999, 9999, "lit", 45)] for d in ("front", "back", "left", "right")},
        "Idle": {
            "front": (95, 0, 525, 568),
            "back": (715, 0, 1150, 568),
            "left": (115, 585, 535, 1158),
            "right": (705, 585, 1135, 1158),
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
        # 2026-10-31: the designer's nip board — coyote_nip_board.webp, four
        # labelled rows on black (NORTH (UP) facing the camera, SOUTH (DOWN)
        # from behind, WEST (LEFT), EAST (RIGHT)), the coyote on a painted
        # floor shadow: the stance, the head lowered, lower still, the nip
        # (jaws open, lunging), the head coming back up, and the stance
        # again. The stance is the height reference, matched to each
        # facing's Idle.
        "actions": {
            "src": "coyote_nip_board.webp",
            "shadow_band": 0.12,
            "fill_holes": 7,
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (190, 30, 303, 252),
                    "crouch": (408, 72, 518, 252),
                    "low": (630, 63, 748, 252),
                    "nip": (855, 61, 974, 252),
                    "recover": (1092, 61, 1208, 252),
                },
                "back": {
                    "stance": (187, 272, 295, 506),
                    "crouch": (383, 287, 510, 506),
                    "low": (607, 287, 738, 506),
                    "nip": (844, 305, 976, 506),
                    "recover": (1096, 288, 1221, 506),
                },
                "left": {
                    "stance": (134, 532, 372, 720),
                    "crouch": (367, 544, 597, 720),
                    "low": (587, 558, 820, 720),
                    "nip": (819, 569, 1052, 720),
                    "recover": (1048, 552, 1287, 720),
                },
                "right": {
                    "stance": (134, 772, 363, 960),
                    "crouch": (348, 782, 585, 960),
                    "low": (572, 781, 806, 960),
                    "nip": (785, 798, 1039, 960),
                    "recover": (1046, 780, 1285, 960),
                },
            },
            "sheets": {
                "Attack": ["crouch", "low", "nip", "recover"],
            },
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
        # 2026-11-04: the designer's Mana Drain board — succubus_drain_board.webp,
        # four labelled rows on black (FRONT, BACK, LEFT, RIGHT) under
        # numbered columns, eight frames a row: she lowers her hand, reaches
        # out, raises it, curls her fingers, beckons, the ball of blue energy
        # drawn back to her along its trail, and caught glowing in her hand.
        # The designer: the ball starts at her target and is brought back to
        # her hand — it is its own sprite (succubus_orb), so the seventh
        # frame, which paints it in flight, holds her beckoning pose instead.
        # Frames 2-8 are Cast.png, for her Mana Drain; the stance matched to
        # her Idle. The left row's sixth frame and the seventh frame's ball
        # touch: split at the contact (`split`, the balls `discard` points).
        "actions": {
            "src": "succubus_drain_board.webp",
            "levels": (8, 36, 10),   # her black wings run just above the backdrop
            "fill_holes": 20,
            "open_dark": True,
            "keep_share": 0.002,     # the glow in her hand
            "glow": False,
            "split": True,
            "isolate_floor": 12,
            "split_floor": 20,
            "discard": {"front": [(1168, 203)], "left": [(1110, 595)],
                        "right": [(1160, 852), (1125, 851), (1115, 841)]},
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (100, 30, 269, 250),
                    "lower": (269, 30, 445, 250),
                    "reach": (445, 30, 621, 250),
                    "raise": (621, 30, 797, 250),
                    "curl": (797, 30, 973, 250),
                    "pull": (973, 30, 1147, 250),
                    "draw": ("same", "pull"),   # the board draws the ball in flight here: it is its own sprite
                    "catch": (1310, 30, 1448, 250),
                },
                "back": {
                    "stance": (100, 279, 269, 505),
                    "lower": (269, 279, 445, 505),
                    "reach": (445, 279, 621, 505),
                    "raise": (621, 279, 797, 505),
                    "curl": (797, 279, 973, 505),
                    "pull": (973, 279, 1147, 505),
                    "draw": ("same", "pull"),   # the board draws the ball in flight here: it is its own sprite
                    "catch": (1310, 279, 1448, 505),
                },
                "left": {
                    "stance": (100, 534, 267, 765),
                    "lower": (267, 534, 441, 765),
                    "reach": (441, 534, 616, 765),
                    "raise": (616, 534, 791, 765),
                    "curl": (791, 534, 965, 765),
                    "pull": (965, 534, 1135, 765),
                    "draw": ("same", "pull"),   # the board draws the ball in flight here: it is its own sprite
                    "catch": (1297, 534, 1448, 765),
                },
                "right": {
                    "stance": (100, 796, 266, 1035),
                    "lower": (266, 796, 441, 1035),
                    "reach": (441, 796, 617, 1035),
                    "raise": (617, 796, 792, 1035),
                    "curl": (792, 796, 966, 1035),
                    "pull": (966, 796, 1140, 1035),
                    "draw": ("same", "pull"),   # the board draws the ball in flight here: it is its own sprite
                    "catch": (1303, 796, 1448, 1035),
                },
            },
            "sheets": {
                "Cast": ["lower", "reach", "raise", "curl", "pull", "draw", "catch"],
            },
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
    "swarm": {
        # 2026-10-26: the Swarm — a cloud of dozens of hornets — four
        # labelled poses on black: north (front), south (back), west
        # (left), east (right). Many separate bees, so no model matte and
        # no "biggest piece" cut: the black_key keeps every bee and gives
        # the wings partial alpha. The height is the cloud's.
        "src": "swarm_board.webp", "bg": "black_key", "tiles": 1.6,
        "Idle": {
            "front": (36, 26, 594, 530),
            "back": (712, 36, 1256, 530),
            "left": (22, 676, 622, 1096),
            "right": (697, 676, 1290, 1098),
        },
    },
    "wererat": {
        # 2026-10-26: the Wererat — a huge, shaggy black rat with long claws
        # and a bare pink tail — four labelled poses on black: north
        # (front), south (back), west (left), east (right); the `rat` kind.
        # The back's tail curls down beside its label, so that box reaches
        # past the label's top and the label is cleared.
        "src": "wererat_board.webp", "bg": "grabcut", "tiles": 1.3,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "matte_bg": {"back": [(95, 462, 375, 500)]},
        "Idle": {
            "front": (30, 112, 574, 562),
            "back": (742, 99, 1214, 587),
            "left": (9, 681, 627, 1060),
            "right": (664, 684, 1249, 1056),
        },
        # 2026-10-31: the designer's bite board — wererat_bite_board.webp,
        # four labelled rows on black (NORTH (FRONT), SOUTH (BACK), WEST
        # (LEFT), EAST (RIGHT) — the board's "north" faces the camera, the
        # game's front). The front and back rows: a crouch, a tensed crouch
        # (ready), the rat in the air, the bite — the rat landing behind a
        # red arc in a burst of dust — the landing, hunched, a settling
        # crouch and the crouch again. The side rows draw the leap and its
        # slash as one picture, so the leap is that picture with the arc
        # and dust cleared and the bite the whole of it. The tails are
        # drawn apart from the bodies (keep_share). The first crouch of
        # each row is the height reference, matched to that facing's Idle.
        "actions": {
            "src": "wererat_bite_board.webp",
            "shadow_band": 0.10,
            "keep_share": 0.035,
            "fill_holes": True,
            "levels": (6, 30, 8),   # the backdrop is 5-6; his fur starts at 8
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (115, 95, 314, 278),
                    "ready": (316, 95, 508, 278),
                    "leap": (448, 40, 694, 230),
                    "bite": (690, 60, 866, 278),
                    "land": (866, 120, 1082, 278),
                    "settle": (1086, 100, 1303, 278),
                },
                "back": {
                    "stance": (116, 330, 312, 530),
                    "ready": (316, 335, 514, 530),
                    "leap": (517, 285, 752, 515),
                    "bite": (724, 318, 880, 530),
                    "land": (880, 360, 1092, 530),
                    "settle": (1092, 342, 1305, 530),
                },
                "left": {
                    "stance": (115, 575, 336, 750),
                    "ready": (322, 572, 540, 750),
                    "leap": (540, 540, 782, 750),
                    "bite": (540, 540, 880, 750),
                    "land": (880, 590, 1094, 750),
                    "settle": (1094, 578, 1306, 750),
                },
                "right": {
                    "stance": (115, 806, 324, 975),
                    "ready": (324, 790, 540, 975),
                    "leap": (537, 762, 792, 975),
                    "bite": (537, 762, 890, 975),
                    "land": (886, 818, 1078, 975),
                    "settle": (1086, 806, 1302, 975),
                },
            },
            "bg_boxes": {
                ("front", "ready"): [(136, 0, 192, 55)],       # the leap's tail
                ("front", "leap"): [(0, 95, 56, 190), (240, 60, 246, 190)],   # the ready crouch's flank; the bite's paw
                ("front", "bite"): [(0, 0, 12, 100)],          # the leap's claw tips
                ("back", "leap"): [(223, 45, 235, 230), (173, 140, 235, 230)],   # the bite's arc and left paw
                ("back", "bite"): [(0, 0, 27, 84)],            # the leap's claw
                ("left", "ready"): [(0, 120, 15, 178)],        # the crouch's claws
                ("left", "leap"): [(150, 150, 242, 210), (220, 0, 242, 160), (0, 150, 32, 210)],   # the slash's dust, the arc's glow, the ready crouch's claws
                ("right", "leap"): [(163, 190, 255, 213), (236, 0, 255, 118)],   # the slash's dust and the arc's glow
            },
            "sheets": {
                "Attack": ["ready", "leap", "bite", "land", "settle"],
            },
        },
    },
    "sabertooth": {
        # 2026-11-03: the Sabertooth's Track — sabertooth_track_board.webp,
        # four labelled rows on black (NORTH (BACK), SOUTH (FRONT), WEST
        # (LEFT), EAST (RIGHT): this board's north is the back), seven
        # captioned frames a row: idle, a paw scraping the ground, scraping
        # deeper, a crouch, ready (the deepest crouch, eyes on its prey),
        # rising, and the idle again. Both side rows face right, so the
        # right is the east row and the left its mirror. The Sabertooth's
        # Idle / Walk are its walk sheet (tools/cut_creature_sheets.py):
        # the frames are scaled to those sheets' rows (the board's idle
        # stands as tall as each facing's Idle) and the cells regrown.
        # Track.png, played in place for its Track.
        "actions": {
            "src": "sabertooth_track_board.webp",
            "levels": (6, 35, 10),   # its belly's shading runs dark; the backdrop is 0-2
            "fill_holes": 6,
            "open_dark": True,
            "glow": False,
            "match": "stance",
            "match_scale": {"left": 1.15, "right": 1.15},   # the walk sheet's side view is longer-bodied than this board's: matched by bulk, not height
            "frames": {
                "front": {
                    "stance": (141, 299, 277, 510),
                    "paw": (337, 299, 466, 510),
                    "scrape": (522, 307, 656, 510),
                    "crouch": (703, 323, 848, 510),
                    "ready": (892, 335, 1048, 510),
                    "rise": (1090, 309, 1225, 510),
                    "back": (1280, 299, 1415, 510),
                },
                "back": {
                    "stance": (145, 21, 271, 248),
                    "paw": (336, 28, 457, 248),
                    "scrape": (525, 38, 651, 248),
                    "crouch": (714, 57, 843, 248),
                    "ready": (903, 75, 1043, 248),
                    "rise": (1099, 33, 1227, 248),
                    "back": (1282, 21, 1409, 248),
                },
                "left": {
                    "stance": ("mirror", (113, 825, 306, 955)),
                    "paw": ("mirror", (305, 827, 494, 955)),
                    "scrape": ("mirror", (495, 829, 687, 955)),
                    "crouch": ("mirror", (685, 837, 880, 955)),
                    "ready": ("mirror", (877, 848, 1068, 955)),
                    "rise": ("mirror", (1064, 827, 1248, 955)),
                    "back": ("mirror", (1249, 825, 1438, 955)),
                },
                "right": {
                    "stance": (113, 825, 306, 955),
                    "paw": (305, 827, 494, 955),
                    "scrape": (495, 829, 687, 955),
                    "crouch": (685, 837, 880, 955),
                    "ready": (877, 848, 1068, 955),
                    "rise": (1064, 827, 1248, 955),
                    "back": (1249, 825, 1438, 955),
                },
            },
            "sheets": {
                "Track": ["paw", "scrape", "crouch", "ready", "rise"],
            },
        },
    },
    "sabertooth_bite": {
        # 2026-11-03: the Sabertooth's Bite and Claw — sabertooth_bite_claw_board.webp,
        # "BITE & CLAW COMBO ATTACK", four labelled rows on black between
        # rule lines (NORTH (BACK VIEW), SOUTH (FRONT VIEW), WEST (LEFT
        # VIEW), EAST (RIGHT VIEW); unlike its track board, each side row
        # faces its own way), eight captioned frames a row: idle, crouch,
        # lunge, the bite (impact), the pull-through, the claw swipe,
        # recovery, return. The side rows' frames crowd each other: each
        # frame's own pieces are kept (`isolate`). Packed into its folder
        # as Attack.png, scaled to its walk-sheet Idle like its Track (the
        # sides by bulk); its Bite and Claw plays it.
        "into": "sabertooth",
        "actions": {
            "src": "sabertooth_bite_claw_board.webp",
            "levels": (6, 35, 10),
            "fill_holes": 6,
            "open_dark": True,
            "glow": False,
            "isolate": True,
            "isolate_floor": 14,   # the right row's lunge and bite touch through their fur's faint fringe
            "match": "stance",
            "match_scale": {"left": 1.15, "right": 1.15},
            "frames": {
                "back": {
                    "stance": (164, 84, 267, 261),
                    "crouch": (327, 107, 437, 261),
                    "lunge": (482, 94, 598, 261),
                    "bite": (636, 73, 756, 261),
                    "pull": (800, 80, 930, 261),
                    "claw": (963, 81, 1121, 261),
                    "recover": (1147, 94, 1258, 261),
                    "back": (1311, 84, 1416, 261),
                },
                "front": {
                    "stance": (159, 335, 280, 514),
                    "crouch": (318, 354, 442, 514),
                    "lunge": (477, 340, 601, 514),
                    "bite": (624, 352, 777, 514),
                    "pull": (793, 348, 927, 514),
                    "claw": (954, 334, 1119, 514),
                    "recover": (1136, 345, 1262, 514),
                    "back": (1304, 335, 1425, 514),
                },
                "left": {
                    "stance": (138, 606, 302, 741),
                    "crouch": (300, 613, 465, 741),
                    "lunge": (458, 614, 637, 741),
                    "bite": (625, 606, 806, 741),
                    "pull": (786, 600, 967, 741),
                    "claw": (959, 596, 1138, 741),
                    "recover": (1130, 609, 1301, 741),
                    "back": (1295, 607, 1449, 741),
                },
                "right": {
                    "stance": (145, 851, 307, 976),
                    "crouch": (298, 862, 466, 976),
                    "lunge": (455, 858, 624, 976),   # the lunge and the bite touch: the boxes meet at the seam
                    "bite": (624, 845, 790, 976),
                    "pull": (772, 848, 957, 976),
                    "claw": (935, 834, 1118, 976),
                    "recover": (1114, 851, 1294, 976),
                    "back": (1292, 851, 1448, 976),
                },
            },
            "sheets": {
                "Attack": ["crouch", "lunge", "bite", "pull", "claw", "recover"],
            },
        },
    },
    "sabertooth_sunken": {
        # 2026-11-03: the Sabertooth's Sunken Bite — sabertooth_sunken_bite_board.webp,
        # four labelled rows on black (NORTH, SOUTH, LEFT, RIGHT; north the
        # back, as on its other boards), fourteen frames a row (the side rows
        # thirteen, one sink frame fewer: that one is held twice): the
        # stance, a step, the lunge, the crouch, sinking its teeth in, deeper,
        # the shake (motion arcs either side), the release, rising, turning
        # back and the stance. The board turns its head to the camera through
        # the bite in every row — the back row too: it has no back-view
        # crouch — and that is used as drawn. Each frame's own pieces are
        # kept (`isolate`, the arcs by `keep_share`). Packed into its folder
        # as Sunken.png, scaled to its walk-sheet Idle like its Track.
        "into": "sabertooth",
        "actions": {
            "src": "sabertooth_sunken_bite_board.webp",
            "levels": (6, 35, 10),
            "fill_holes": 6,
            "open_dark": True,
            "keep_share": 0.01,   # the shake's arcs
            "glow": False,
            "isolate": True,
            "isolate_floor": 14,
            "match": "stance",
            "match_scale": {"left": 1.15, "right": 1.15},
            "frames": {
                "front": {
                    "stance": (117, 259, 214, 413),
                    "step": (237, 259, 331, 413),
                    "lunge": (355, 266, 451, 413),
                    "crouch": (459, 279, 574, 413),
                    "sink1": (582, 281, 704, 413),
                    "sink2": (704, 282, 829, 413),
                    "sink3": (829, 283, 950, 413),
                    "shake1": (950, 284, 1075, 413),
                    "shake2": (1075, 283, 1202, 413),
                    "release": (1204, 280, 1314, 413),
                    "rise": (1331, 266, 1424, 413),
                    "turn": (1447, 262, 1542, 413),
                    "back1": (1562, 259, 1656, 413),
                    "back2": (1677, 259, 1772, 413),
                },
                "back": {
                    "stance": (122, 42, 212, 203),
                    "step": (240, 42, 329, 203),
                    "lunge": (360, 51, 458, 203),
                    "crouch": (470, 62, 576, 203),
                    "sink1": (589, 66, 697, 203),
                    "sink2": (699, 68, 820, 203),
                    "sink3": (820, 70, 942, 203),
                    "shake1": (942, 69, 1071, 203),
                    "shake2": (1071, 69, 1202, 203),
                    "release": (1202, 65, 1313, 203),
                    "rise": (1323, 52, 1420, 203),
                    "turn": (1446, 45, 1538, 203),
                    "back1": (1564, 42, 1654, 203),
                    "back2": (1678, 41, 1769, 203),
                },
                "left": {
                    "stance": (95, 505, 249, 612),
                    "step": (249, 505, 391, 612),
                    "lunge": (391, 498, 534, 612),
                    "crouch": (534, 515, 676, 612),
                    "sink1": (676, 519, 808, 612),
                    "sink2": (808, 517, 939, 612),
                    "shake1": (939, 518, 1067, 612),
                    "shake2": (1067, 519, 1195, 612),
                    "release": (1195, 518, 1312, 612),
                    "rise": (1316, 511, 1435, 612),
                    "turn": (1443, 499, 1552, 612),
                    "back1": (1554, 499, 1660, 612),
                    "back2": (1661, 500, 1779, 612),
                    "sink3": ("same", "sink2"),   # the side rows draw one sink frame fewer
                },
                "right": {
                    "stance": (96, 703, 243, 804),
                    "step": (243, 705, 380, 804),
                    "lunge": (380, 695, 526, 804),
                    "crouch": (526, 708, 685, 804),
                    "sink1": (685, 709, 820, 804),
                    "sink2": (820, 711, 955, 804),
                    "shake1": (955, 713, 1081, 804),
                    "shake2": (1081, 714, 1213, 804),
                    "release": (1213, 714, 1326, 804),
                    "rise": (1329, 705, 1446, 804),
                    "turn": (1446, 703, 1548, 804),
                    "back1": (1548, 700, 1659, 804),
                    "back2": (1659, 702, 1779, 804),
                    "sink3": ("same", "sink2"),   # the side rows draw one sink frame fewer
                },
            },
            "sheets": {
                "Sunken": ["step", "lunge", "crouch", "sink1", "sink2", "sink3", "shake1", "shake2", "release", "rise"],
            },
        },
    },
    "magma_spider_web": {
        # 2026-11-04: the Magma Spider's Fire Web — magma_spider_web_board.webp,
        # "FIRE-WEB SHOOTING ATTACK", four labelled rows on black (NORTH: the
        # face, SOUTH: the back, WEST, EAST), eight numbered frames a row:
        # the stance, rearing, drawing back, aiming, spitting a glob of fire
        # (still strung to its jaws), and the recoil while the glob flies
        # off (the board draws it flying away across the next frames, into
        # their boxes). Frames 2-8 are Cast.png, packed into its folder; the
        # glob that flies off is its own sprite (magma_spider_glob), sent to
        # its prey. Each row is split at the contacts between neighbours
        # (`split`: a glob touches the next frame's spider), and only pieces
        # near the spider's size are kept (`keep_share`): a loose glob falls
        # away.
        "into": "magma_spider",
        "actions": {
            "src": "magma_spider_web_board.webp",
            "levels": (6, 35, 10),   # its black rock runs just above the backdrop's 0
            "fill_holes": 6,
            "open_dark": True,
            "keep_share": 0.2,       # a detached leg, not a flying glob (a tenth of the spider)
            "glow": False,
            "split": True,           # its globs touch the next frame's spider: parted at the contact
            # The painted globs (the flying one is its own sprite): dropped
            # with whatever lies nearer them than a spider (a strand parts
            # half way).
            # The spit frame's glob, still strung to its jaws, is kept on the
            # front and back rows (the flying glob leaves from there); the
            # side rows shoot it backward out of the abdomen, away from where
            # it faces, so theirs go and the flying glob leaves its head.
            "discard": {"front": [(1020, 234), (1190, 247)],
                        "back": [(1022, 327), (1191, 319), (1356, 312)],
                        "left": [(766, 673), (907, 682), (1074, 691), (1257, 703)],
                        "right": [(766, 916), (944, 918), (1122, 932), (1281, 942)]},
            "isolate_floor": 14,
            "match": "stance",
            "match_scale": {"left": 1.0, "right": 1.0},
            "frames": {
                "front": {
                    "stance": (110, 62, 273, 250),
                    "rear": (273, 62, 440, 250),
                    "draw": (440, 62, 605, 250),
                    "aim": (605, 62, 770, 250),
                    "spit": (770, 62, 936, 250),
                    "flick": (936, 62, 1105, 250),
                    "recoil": (1105, 62, 1273, 250),
                    "back": (1273, 62, 1440, 250),
                },
                "back": {
                    "stance": (110, 296, 273, 500),
                    "rear": (273, 296, 440, 500),
                    "draw": (440, 296, 605, 500),
                    "aim": (605, 296, 770, 500),
                    "spit": (770, 296, 936, 500),
                    "flick": (936, 296, 1105, 500),
                    "recoil": (1105, 296, 1273, 500),
                    "back": (1273, 296, 1440, 500),
                },
                "left": {
                    "stance": (110, 585, 273, 726),
                    "rear": (273, 585, 440, 726),
                    "draw": (440, 585, 605, 726),
                    "aim": (605, 585, 770, 726),
                    "spit": (770, 585, 936, 726),
                    "flick": (936, 585, 1105, 726),
                    "recoil": (1105, 585, 1273, 726),
                    "back": (1273, 585, 1440, 726),
                },
                "right": {
                    "stance": (110, 825, 273, 966),
                    "rear": (273, 825, 440, 966),
                    "draw": (440, 825, 605, 966),
                    "aim": (605, 825, 770, 966),
                    "spit": (770, 825, 936, 966),
                    "flick": (936, 825, 1105, 966),
                    "recoil": (1105, 825, 1273, 966),
                    "back": (1273, 825, 1440, 966),
                },
            },
            "sheets": {
                "Cast": ["rear", "draw", "aim", "spit", "flick", "recoil", "back"],
            },
        },
    },
    "magma_spider_glob": {
        # 2026-11-04: the Fire Web in flight and where it lands —
        # magma_spider_web_strip.webp, twelve frames on black: a ball of
        # webbing glowing with fire flying right, its trail streaming
        # longer as it goes (1-5); the impact, a burst of fire (6); the web
        # spreading out flat across the ground (7-12). Glob.png is the five
        # flying frames, its Fire Web's projectile (ThrownSprite), mirrored
        # when it flies left; the widest frame (ball and trail) 0.95 tiles.
        "into": "magma_spider",
        "strip": {
            "src": "magma_spider_web_strip.webp",
            "bg": "black_key",
            "sheet": "Glob",
            "width_tiles": 0.95,
            "width_of": "max",
            "align": "board",
            "frames": [(18, 400, 90, 525), (90, 400, 199, 525), (199, 400, 323, 525), (323, 400, 452, 525), (452, 400, 583, 525)],
        },
    },
    "magma_spider_webland": {
        # The impact and the web spreading (the strip's frames 6-12):
        # WebLand.png, laid on its prey's square as the ball lands
        # (SpotEffect), its last frame — the full web — held on the ground
        # for as long as the web lasts, in place of the fire walls' flames.
        # The full web 3 tiles wide: the 3x3 it covers.
        "into": "magma_spider",
        "strip": {
            "src": "magma_spider_web_strip.webp",
            "bg": "black_key",
            "sheet": "WebLand",
            "width_tiles": 3.0,
            "width_of": "max",
            "align": "board",
            "frames": [(583, 400, 708, 525), (708, 400, 831, 525), (831, 400, 967, 525), (967, 400, 1117, 525), (1117, 400, 1278, 525), (1278, 400, 1463, 525), (1463, 400, 1665, 525)],
        },
    },
    "wolf": {
        # 2026-10-31: the Wolf's bite — wolf_bite_board.webp, four labelled
        # rows on black (Up: from behind, Down: facing the camera, Left,
        # Right), the wolf on a painted floor shadow: the stance, a crouch,
        # the leap, the bite low to the ground, the recovery and the stance
        # again. The board slips twice: the Up row's bite faces the camera
        # and the Down row's sixth frame is seen from behind, so that one
        # is the back's bite. The Wolf's Idle / Walk are the designer's
        # walk sheet (tools/cut_creature_sheets.py): no board here, the
        # bite is scaled to those sheets' rows and their cells regrown.
        "actions": {
            "src": "wolf_bite_board.webp",
            "shadow_band": 0.16,
            "match": "stance",
            "match_scale": {"left": 0.88, "right": 0.88},   # the board's side views run longer and bulkier than the walk sheet's wolf
            "frames": {
                "front": {
                    "stance": (115, 300, 244, 520),
                    "crouch": (440, 305, 588, 522),
                    "leap": (596, 280, 752, 522),
                    "bite": (758, 332, 944, 526),
                    "recover": (1145, 322, 1295, 524),
                },
                "back": {
                    "stance": (113, 52, 240, 290),
                    "crouch": (428, 52, 560, 290),
                    "leap": (578, 30, 745, 290),
                    "bite": (952, 304, 1104, 522),
                    "recover": (963, 52, 1094, 290),
                },
                "left": {
                    "stance": (92, 585, 297, 742),
                    "crouch": (288, 598, 505, 742),
                    "leap": (495, 560, 745, 740),
                    "bite": (757, 600, 1024, 750),
                    "recover": (997, 588, 1286, 750),
                },
                "right": {
                    "stance": (98, 800, 297, 972),
                    "crouch": (298, 820, 530, 972),
                    "leap": (500, 770, 770, 952),
                    "bite": (772, 830, 1032, 972),
                    "recover": (1002, 804, 1288, 972),
                },
            },
            "sheets": {
                "Attack": ["crouch", "leap", "bite", "recover"],
            },
        },
    },
    "zombie": {
        # 2026-10-26: the Zombie — a gaunt, rotting man with an exposed
        # brain, a torn purple-and-green vest and shredded trousers — four
        # labelled poses on black: north (front), south (back), west (left),
        # east (right). The few flies the board draws around its head are
        # loose specks at game size and are left out.
        "src": "zombie_board.jpg", "bg": "grabcut", "tiles": 1.75,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (190, 18, 362, 441),
            "back": (668, 29, 833, 442),
            "left": (241, 508, 358, 929),
            "right": (678, 510, 794, 929),
        },
        # 2026-11-01: the designer's attack board — zombie_attack_board.webp,
        # four labelled rows on black (NORTH (FRONT), SOUTH (BACK), WEST
        # (LEFT), EAST (RIGHT), the board's "north" facing the camera), the
        # flies still about its head: the stance, the arms coming up, the
        # reach, the grab with both arms thrown forward, the arms drawing
        # back, and the stance twice. The flies are loose specks and fall
        # away as on the pose board. The stance is the height reference,
        # matched to each facing's Idle.
        "actions": {
            "src": "zombie_attack_board.webp",
            "shadow_band": 0.06,
            "fill_holes": 7,
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (190, 10, 295, 245),
                    "ready": (380, 25, 492, 245),
                    "reach": (565, 30, 692, 245),
                    "grab": (760, 30, 908, 245),
                    "recover": (950, 30, 1096, 245),
                },
                "back": {
                    "stance": (190, 258, 295, 495),
                    "ready": (372, 268, 510, 495),
                    "reach": (560, 270, 706, 495),
                    "grab": (760, 268, 908, 495),
                    "recover": (960, 268, 1100, 495),
                },
                "left": {
                    "stance": (190, 508, 280, 738),
                    "ready": (375, 518, 490, 738),
                    "reach": (537, 525, 686, 738),
                    "grab": (735, 515, 888, 738),
                    "recover": (942, 515, 1086, 738),
                },
                "right": {
                    "stance": (195, 750, 285, 985),
                    "ready": (388, 762, 497, 985),
                    "reach": (575, 765, 727, 985),
                    "grab": (782, 758, 934, 985),
                    "recover": (986, 760, 1114, 985),
                },
            },
            "sheets": {
                "Attack": ["ready", "reach", "grab", "recover"],
            },
        },
    },
    "rat_king": {
        # 2026-10-26: the Rat King, redrawn — a hulking black rat in a spiked
        # crown and runed, blood-spattered plate — four labelled poses on
        # black: north (front), south (back), west (left), east (right).
        # It replaces his walk-sheet cut (tools/cut_boss_sheets.py). The
        # designer: he must be bigger than the normal rat (the Wererat,
        # 1.3 tiles), so 2.1.
        "src": "rat_king_board.jpg", "bg": "grabcut", "tiles": 2.1,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (32, 46, 480, 458),
            "back": (569, 46, 970, 458),
            "left": (7, 547, 513, 866),
            "right": (542, 549, 1020, 866),
        },
        # 2026-11-04: the designer's Infest board — rat_king_infest_board.webp,
        # "RAT KING - INFEST (ATTACK ANIMATION)", four labelled rows on black
        # (NORTH: the face, SOUTH: the back, WEST, EAST), eleven frames a row,
        # and below them the effect panel (rat_king_infest's strip). In the
        # designer's words: he crouches low, his eyes glowing an eerie purple
        # and bright green, rubs his paws together rapidly, points a single
        # sharp claw at the victim, his eyes turned bright white, and
        # settles. Frames 2-10 are Cast.png, played for his Infest; the
        # first is the height reference, matched to each facing's Idle. The
        # first box starts below the panel title's frame line its crown
        # nearly touches; the side rows' tails reach the next frame's box
        # (`isolate`).
        "actions": {
            "src": "rat_king_infest_board.webp",
            "levels": (4, 30, 6),   # his black fur runs just above the backdrop's 0
            "fill_holes": 4,
            "open_dark": True,
            "keep_share": 0.002,   # the sparks about his paws
            "glow": False,
            "isolate": True,
            "isolate_floor": 14,
            "match": "stance",
            # The board draws him squatter than his pose board does: matched
            # by bulk (width), not height, so the crouch doesn't swell him.
            "match_scale": MATCH_SCALE_RK,
            "frames": {
                "front": {
                    "stance": (102, 30, 253, 122),
                    "crouch": (264, 30, 398, 122),
                    "low": (426, 30, 563, 122),
                    "glow": (592, 30, 729, 122),
                    "rub": (749, 30, 888, 122),
                    "rub2": (911, 30, 1051, 122),
                    "white": (1080, 30, 1220, 122),
                    "point": (1255, 30, 1392, 122),
                    "point2": (1440, 30, 1576, 122),
                    "settle": (1633, 30, 1766, 122),
                    "back": (1825, 30, 1959, 122),
                },
                "back": {
                    "stance": (111, 130, 240, 246),
                    "crouch": (265, 131, 394, 246),
                    "low": (428, 155, 561, 246),
                    "glow": (590, 133, 718, 246),
                    "rub": (750, 133, 880, 246),
                    "rub2": (912, 132, 1047, 246),
                    "white": (1077, 131, 1211, 246),
                    "point": (1252, 131, 1390, 246),
                    "point2": (1438, 130, 1578, 246),
                    "settle": (1633, 127, 1767, 246),
                    "back": (1822, 127, 1956, 246),
                },
                "left": {
                    "stance": (103, 250, 261, 348),
                    "crouch": (261, 256, 423, 348),
                    "low": (423, 265, 589, 348),
                    "glow": (590, 262, 752, 348),
                    "rub": (752, 252, 918, 348),
                    "rub2": (918, 250, 1082, 348),
                    "white": (1082, 249, 1248, 348),
                    "point": (1248, 249, 1431, 348),
                    "point2": (1432, 249, 1612, 348),
                    "settle": (1624, 249, 1800, 348),
                    "back": (1812, 249, 1986, 348),
                },
                "right": {
                    "stance": (95, 357, 255, 458),
                    "crouch": (255, 357, 417, 458),
                    "low": (417, 358, 577, 458),
                    "glow": (577, 354, 740, 458),
                    "rub": (740, 352, 907, 458),
                    "rub2": (907, 354, 1072, 458),
                    "white": (1073, 356, 1251, 458),
                    "point": (1251, 355, 1439, 458),
                    "point2": (1439, 354, 1631, 458),
                    "settle": (1631, 357, 1798, 458),
                    "back": (1811, 357, 1985, 458),
                },
            },
            "sheets": {
                "Cast": ["crouch", "low", "glow", "rub", "rub2", "white", "point", "point2", "settle"],
            },
        },
    },
    "rat_king_bite": {
        # 2026-11-04: the Rat King's bite — rat_king_bite_board.webp, "RAT
        # KING - BITE ATTACK", four labelled rows on black (NORTH: the face,
        # SOUTH: the back, WEST, EAST), ten frames a row: the stance, the
        # jaws opening, a crouch, the lunge, the bite, the snap, pulling
        # back, recovering, rising and the stance. Frames 2-9 are Attack.png
        # (his Bite), cut like his Infest and packed into his folder; the
        # first box starts below the title box's frame line, which his crown
        # touches.
        "into": "rat_king",
        "actions": {
            "src": "rat_king_bite_board.webp",
            "levels": (4, 30, 6),
            "fill_holes": 4,
            "open_dark": True,
            "glow": False,
            "isolate": True,
            "isolate_floor": 14,
            "match": "stance",
            # Its stance matched to his Idle by width (this board draws him
            # nearer his pose board's proportions than the Infest board does).
            "match_scale": {"front": 1.05, "back": 1.0, "left": 1.0, "right": 1.02},
            "frames": {
                "front": {
                    "stance": (107, 37, 262, 170),
                    "open": (303, 21, 447, 170),
                    "crouch": (479, 29, 636, 170),
                    "lunge": (654, 29, 820, 170),
                    "bite": (838, 34, 1011, 170),
                    "snap": (1032, 35, 1198, 170),
                    "pull": (1216, 31, 1391, 170),
                    "recover": (1410, 25, 1584, 170),
                    "rise": (1608, 19, 1776, 170),
                    "back": (1818, 15, 1980, 170),
                },
                "back": {
                    "stance": (105, 171, 261, 326),
                    "open": (291, 170, 448, 326),
                    "crouch": (479, 174, 635, 326),
                    "lunge": (660, 183, 825, 326),
                    "bite": (843, 189, 1013, 326),
                    "snap": (1034, 192, 1202, 326),
                    "pull": (1229, 186, 1393, 326),
                    "recover": (1425, 170, 1585, 326),
                    "rise": (1619, 170, 1780, 326),
                    "back": (1820, 170, 1977, 326),
                },
                "left": {
                    "stance": (100, 335, 280, 460),
                    "open": (280, 340, 464, 460),
                    "crouch": (464, 344, 657, 460),
                    "lunge": (657, 346, 836, 460),
                    "bite": (836, 335, 1023, 460),
                    "snap": (1023, 343, 1217, 460),
                    "pull": (1217, 344, 1410, 460),
                    "recover": (1410, 340, 1604, 460),
                    "rise": (1604, 335, 1803, 460),
                    "back": (1803, 336, 1988, 460),
                },
                "right": {
                    "stance": (100, 486, 280, 619),
                    "open": (280, 489, 468, 619),
                    "crouch": (468, 491, 650, 619),
                    "lunge": (650, 495, 835, 619),
                    "bite": (835, 488, 1024, 619),
                    "snap": (1024, 492, 1217, 619),
                    "pull": (1217, 491, 1405, 619),
                    "recover": (1405, 490, 1598, 619),
                    "rise": (1598, 487, 1794, 619),
                    "back": (1794, 487, 1988, 619),
                },
            },
            "sheets": {
                "Attack": ["open", "crouch", "lunge", "bite", "snap", "pull", "recover", "rise"],
            },
        },
    },
    "rat_king_infest": {
        # 2026-11-04: the Infest effect — the board's lower panel, "INFEST
        # EFFECT - SMOKE TO RATS (TARGET SQUARE)", eleven frames on black: a
        # thin purple ring, wispy dark smoke rising from it, the smoke
        # liquefying into a swarm of little purple-eyed rats that crawl
        # into the square, thinning out. Cut by brightness with soft alpha
        # (`bg: "black_key"`: the smoke is translucent, and every rat is a
        # piece of its own), packed as one row, Infest.png, in his folder;
        # his Infest lays it on the victim's square (SpotEffect), the ring
        # about the victim's feet. The full swarm is 2 tiles wide, the square and its edges.
        "into": "rat_king",
        "strip": {
            "src": "rat_king_infest_board.webp",
            "bg": "black_key",
            "sheet": "Infest",
            "width_tiles": 2.0,
            "alpha_gain": 1.8,   # faint purple wisps on black: thickened to read on the floor
            "width_of": "max",
            "align": "board",
            "frames": [(60, 514, 174, 648), (174, 514, 341, 648), (341, 514, 509, 648), (509, 514, 675, 648), (675, 514, 845, 648), (845, 514, 1019, 648), (1019, 514, 1205, 648), (1205, 514, 1406, 648), (1406, 514, 1612, 648), (1612, 514, 1808, 648), (1808, 514, 1985, 648)],
        },
    },
    "archer_rat": {
        # 2026-10-26: the Archer Rat, redrawn — a brown rat on its hind legs
        # with a longbow and a quiver of fletched arrows — four labelled
        # poses on black: north (front), south (back), west (left), east
        # (right). It replaces the tools/cut_archer_rat.py cut (standing and
        # all-fours sheets) and writes over its output. Smaller than the
        # Wererat (1.3 tiles).
        "src": "archer_rat_board.webp", "bg": "grabcut", "tiles": 1.0,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (69, 33, 423, 452),
            "back": (660, 79, 995, 456),
            "left": (11, 523, 511, 866),
            "right": (541, 523, 1017, 866),
        },
        # 2026-10-31: the designer's shoot board — archer_rat_shoot_board.webp,
        # four labelled rows on black (NORTH (FRONT), SOUTH (BACK), WEST
        # (LEFT), EAST (RIGHT), the board's "north" facing the camera): the
        # stance, the arrow nocked, the string drawn, drawn again, the
        # release (the front and back rows with the arrow in flight beside
        # the rat; the side rows the arrow alone, then the rat with the
        # bow sprung), the bow lowered / the stance. Draw.png is the nock
        # and the draw, held at full draw (SpriteEnemyFigure CP_HOLD) from
        # two tempo before the shot; Attack.png the shot: full draw, the
        # release, the bow lowered. The flying arrows are loose pieces and
        # fall away (only the rat and anything red is kept). The stance
        # is the height reference, matched to each facing's Idle.
        "actions": {
            "src": "archer_rat_shoot_board.webp",
            "shadow_band": 0.08,
            "fill_holes": 7,
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (108, 45, 275, 250),
                    "nock": (280, 45, 462, 250),
                    "draw": (465, 33, 670, 250),
                    "full": (671, 30, 868, 250),
                    "release": (868, 42, 1040, 250),
                    "lower": (1125, 38, 1330, 250),
                },
                "back": {
                    "stance": (108, 296, 300, 488),
                    "nock": (325, 270, 495, 488),
                    "draw": (502, 260, 675, 488),
                    "full": (705, 259, 880, 488),
                    "release": (898, 310, 1090, 488),
                    "lower": (1156, 270, 1348, 488),
                },
                "left": {
                    "stance": (108, 535, 325, 722),
                    "nock": (310, 524, 505, 722),
                    "draw": (518, 504, 705, 720),
                    "full": (726, 504, 918, 720),
                    "release": (1050, 530, 1325, 720),
                    "lower": (1338, 538, 1536, 722),
                },
                "right": {
                    "stance": (108, 763, 300, 952),
                    "nock": (295, 741, 478, 952),
                    "draw": (470, 745, 708, 952),
                    "full": (640, 752, 900, 952),
                    "release": (1078, 760, 1325, 952),
                    "lower": (1330, 766, 1530, 952),
                },
            },
            "sheets": {
                "Draw": ["nock", "draw"],
                "Attack": ["full", "release", "lower"],
            },
        },
    },
    "magma_spider": {
        # 2026-10-26: the Magma Spider — a spider of cracked black rock with
        # lava glowing through the seams — four labelled poses on black. Its
        # side labels are swapped: the pose marked "WEST (LEFT)" faces right
        # and "EAST (RIGHT)" faces left, so they are picked by what they show.
        "src": "magma_spider_board.jpg", "bg": "grabcut", "tiles": 1.2,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        # The model reads the dark rock abdomen as background (most of it
        # on the side views): keep everything brighter than the black board,
        # small near-black crevices filled.
        # On the back the thin web strands under the spinnerets would come
        # out a dark smudge at game size: they are cleared.
        "matte_fg": {"front": [(0, 0, 9999, 9999, "lit", 6, 600)],
                     "back": [(0, 0, 9999, 285, "lit", 6, 600)],
                     "left": [(0, 0, 9999, 9999, "lit", 6, 600)],
                     "right": [(0, 0, 9999, 9999, "lit", 6, 600)]},
        "matte_bg": {"back": [(100, 285, 360, 352)]},
        "Idle": {
            "front": (28, 72, 501, 452),
            "back": (540, 100, 1003, 452),
            "left": (539, 544, 1007, 866),    # the board's "EAST (RIGHT)"
            "right": (23, 544, 499, 866),     # the board's "WEST (LEFT)"
        },
        # 2026-11-04: the designer's Fire Bounce board — magma_spider_bounce_board.webp,
        # cut out (transparent), four labelled rows (NORTH: the face, SOUTH:
        # the back, WEST, EAST) under numbered columns, ten frames a row: the
        # stance, a crouch, a burst of fire under it as it springs, lifting
        # off, high in the air, coming down, landing in a burst of fire, the
        # flare dying, settling, the stance. Frames 2-10 are Bounce.png, for
        # its Fire Bounce: it leaps between its take-off and landing squares
        # through the airborne frames (SpriteEnemyFigure.leap_from). Each row
        # is split along the narrowest contact between neighbours
        # (`alpha_split`), and every frame keeps its height above the ground
        # (`keep_ground`): the airborne frames stay in the air, the bursts
        # reach below its feet.
        "actions": {
            "src": "magma_spider_bounce_board.webp",
            "bg": "alpha_split",
            "keep_ground": True,
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (88, 33, 196, 205),
                    "crouch": (196, 33, 303, 205),
                    "burst": (303, 33, 408, 205),
                    "lift": (408, 33, 513, 205),
                    "rise": (513, 33, 617, 205),
                    "fall": (617, 33, 722, 205),
                    "land": (722, 33, 826, 205),
                    "flare": (826, 33, 929, 205),
                    "settle": (929, 33, 1029, 205),
                    "back": (1029, 33, 1125, 205),
                },
                "back": {
                    "stance": (88, 205, 196, 395),
                    "crouch": (196, 205, 303, 395),
                    "burst": (303, 205, 408, 395),
                    "lift": (408, 205, 513, 395),
                    "rise": (513, 205, 617, 395),
                    "fall": (617, 205, 722, 395),
                    "land": (722, 205, 826, 395),
                    "flare": (826, 205, 929, 395),
                    "settle": (929, 205, 1029, 395),
                    "back": (1029, 205, 1125, 395),
                },
                "left": {
                    "stance": (88, 395, 196, 585),
                    "crouch": (196, 395, 303, 585),
                    "burst": (303, 395, 408, 585),
                    "lift": (408, 395, 513, 585),
                    "rise": (513, 395, 617, 585),
                    "fall": (617, 395, 722, 585),
                    "land": (722, 395, 826, 585),
                    "flare": (826, 395, 929, 585),
                    "settle": (929, 395, 1029, 585),
                    "back": (1029, 395, 1125, 585),
                },
                "right": {
                    "stance": (88, 585, 196, 775),
                    "crouch": (196, 585, 303, 775),
                    "burst": (303, 585, 408, 775),
                    "lift": (408, 585, 513, 775),
                    "rise": (513, 585, 617, 775),
                    "fall": (617, 585, 722, 775),
                    "land": (722, 585, 826, 775),
                    "flare": (826, 585, 929, 775),
                    "settle": (929, 585, 1029, 775),
                    "back": (1029, 585, 1125, 775),
                },
            },
            "sheets": {
                "Bounce": ["crouch", "burst", "lift", "rise", "fall", "land", "flare", "settle", "back"],
            },
        },
    },
    "treasure_bunny": {
        # 2026-10-26: the Treasure Bunny (was the Wererabbit) — a golden,
        # gem-studded rabbit with a loot sack on its back — four labelled
        # poses on black: north (front), south (back), west (left), east
        # (right).
        "src": "treasure_bunny_board.jpg", "bg": "grabcut", "tiles": 1.1,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (145, 29, 383, 458),
            "back": (653, 29, 889, 457),
            "left": (66, 519, 441, 870),
            "right": (594, 520, 970, 870),
        },
    },
    "corrupted_archangel": {
        # 2026-10-27: from the designer's boss trio board (boss_trio_board.webp:
        # the Corrupted Archangel, Cerberus and Hades, four labelled poses each
        # — NORTH is the face, SOUTH the back, EAST / WEST the sides). Replaces
        # the walk-sheet cut (tools/cut_boss_sheets.py); kept at the height
        # it had there. The row's title plaque is cleared where it reaches in.
        "src": "boss_trio_board.webp", "bg": "grabcut", "tiles": 1.9,
        "sharpen": 160,   # the source is soft (lossy, small figures): crisped before the shrink
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (218, 18, 498, 320),
            "back": (877, 18, 1167, 320),
            "left": (1230, 18, 1438, 320),
            "right": (574, 18, 782, 320),
        },
    },
    "cerberus": {
        # 2026-10-27: from the designer's boss trio board (boss_trio_board.webp:
        # the Corrupted Archangel, Cerberus and Hades, four labelled poses each
        # — NORTH is the face, SOUTH the back, EAST / WEST the sides). Replaces
        # the walk-sheet cut (tools/cut_boss_sheets.py); kept at the height
        # it had there. The row's title plaque is cleared where it reaches in.
        # Both its side poses face right: EAST is the right, mirrored for the left.
        "src": "boss_trio_board.webp", "bg": "grabcut", "tiles": 2.4,
        "sharpen": 160,   # the source is soft (lossy, small figures): crisped before the shrink
        "matte": ("front", "back", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (252, 374, 486, 628),
            "back": (906, 374, 1094, 628),
            "right": (499, 374, 873, 628),
            "left": ("mirror", "right"),
        },
    },
    "hades": {
        # 2026-10-27: from the designer's boss trio board (boss_trio_board.webp:
        # the Corrupted Archangel, Cerberus and Hades, four labelled poses each
        # — NORTH is the face, SOUTH the back, EAST / WEST the sides). Replaces
        # the walk-sheet cut (tools/cut_boss_sheets.py); kept at the height
        # it had there. The row's title plaque is cleared where it reaches in.
        "src": "boss_trio_board.webp", "bg": "grabcut", "tiles": 1.9,
        "sharpen": 160,   # the source is soft (lossy, small figures): crisped before the shrink
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "matte_bg": {"front": [(0, 0, 40, 125)]},      # the HADES plaque's edge
        # Keep the purple flames' wisps the model trims.
        "matte_fg": {d: [(0, 0, 9999, 9999, "lit", 55)] for d in ("back", "left", "right")},
        "Idle": {
            "front": (225, 672, 526, 970),
            "back": (872, 672, 1173, 970),
            "left": (1248, 672, 1491, 970),
            "right": (563, 672, 791, 970),
        },
    },
    "npc_sellsword": {
        # 2026-10-27: the town's Sellsword — a bespectacled woman in a black
        # waistcoat, puffed white sleeves and breeches, a ledger at her hip —
        # from her NPC sheet: the top row's four standing poses ("North" the
        # face, "South" the back, "East" faces right, "West" left). The
        # sheet's title plaque reaches the front box's corner: cleared.
        "src": "sellsword_npc_board.webp", "bg": "grabcut", "tiles": 1.65,
        "sharpen": 160,   # the source is soft (lossy, small figures): crisped before the shrink
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "matte_bg": {"front": [(0, 0, 30, 14)]},
        # The boxes stop at her soles: the shiny floor plate below would leave
        # specks, and her black boots are too dark for the shadow drop.
        "Idle": {
            "front": (360, 104, 528, 493),
            "back": (834, 104, 978, 493),
            "left": (1071, 104, 1165, 493),
            "right": (637, 104, 729, 493),
        },
    },
    "npc_blacksmith": {
        # 2026-10-27: the town's Blacksmith — a long-haired, moustached smith
        # in a torn vest, leather apron and mail leggings — from his NPC
        # sheet: the top row's four standing poses (as the Sellsword's).
        "src": "blacksmith_npc_board.webp", "bg": "grabcut", "tiles": 1.75,
        "sharpen": 160,   # the source is soft (lossy, small figures): crisped before the shrink
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "drop_shadow": (0.05, 30),
        "Idle": {
            "front": (338, 130, 527, 494),
            "back": (836, 130, 1024, 494),
            "left": (1128, 130, 1223, 494),
            "right": (612, 130, 732, 494),
        },
    },
    "summon_skeleton": {
        # 2026-10-27: the summoned Skeleton (Summon Skeleton, Skeleton Army):
        # a bare skeleton with a glowing teal skull, a short sword and a
        # scabbard — four labelled poses on black: north (front), south
        # (back), west (left), east (right). The boxes stop above the labels.
        "src": "summon_skeleton_board.jpg", "bg": "grabcut", "tiles": 1.5,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        # The skull's soft glow is left out: an on/off cut turns it into a
        # hard teal disc; the skull keeps its own teal light.
        "Idle": {
            "front": (117, 8, 364, 442),
            "back": (666, 16, 908, 442),
            "left": (224, 496, 371, 929),
            "right": (667, 496, 894, 929),
        },
    },
    "battle_turtle": {
        # 2026-10-28: the Battle Turtle summon (Summon Battle Turtle, Turtle
        # Power) — a hulking armoured snapping-turtle warrior with a spiked
        # shell — from its sheet's top row (the detail panels below are not
        # used). "FACING UP" shows the face and "FACING DOWN" the shell:
        # picked by what they show; the side labels are true. The board's
        # background is a dark navy, not black.
        "src": "battle_turtle_board.webp", "bg": "grabcut", "tiles": 1.6,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (0, 115, 393, 576),
            "back": (404, 115, 779, 576),
            "left": (791, 115, 1147, 576),
            "right": (1201, 115, 1514, 576),
        },
        # 2026-11-03: the designer's armor board — battle_turtle_armor_board.webp,
        # four rows of ten on dark navy (facing the camera, its shell, facing
        # right, facing left): the stance, a crouch, a claw reaching down,
        # the claw digging in, a brick pulled from the dirt, the brick held
        # up, tossed over its head with a roar, the brick in the air, the
        # brick landing on it (its armor), and the stance again. Armor.png is
        # crouch to land; it plays each time the turtle gives itself armor
        # (main._regain_turtle_armor). Its shading is as dark as the navy
        # backdrop, so each frame is cut by a model matte, as its Idle is
        # (tools/make_mattes.py), with the brick and its dirt added back as
        # the red pieces. The stance is the height reference, matched to
        # each facing's Idle.
        "actions": {
            "src": "battle_turtle_armor_board.webp",
            "matte": True,
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (10, 22, 155, 262),
                    "crouch": (155, 22, 305, 262),
                    "reach": (305, 22, 442, 262),
                    "dig": (442, 22, 587, 262),
                    "pull": (587, 22, 729, 262),
                    "lift": (729, 22, 876, 262),
                    "toss": (876, 22, 1014, 262),
                    "high": (1014, 22, 1160, 262),
                    "land": (1160, 22, 1305, 262),
                },
                "back": {
                    "stance": (6, 276, 157, 515),
                    "crouch": (157, 276, 302, 515),
                    "reach": (302, 276, 441, 515),
                    "dig": (441, 276, 585, 515),
                    "pull": (585, 276, 730, 515),
                    "lift": (730, 276, 873, 515),
                    "toss": (873, 276, 1017, 515),
                    "high": (1017, 276, 1162, 515),
                    "land": (1162, 276, 1305, 515),
                },
                "right": {
                    "stance": (6, 530, 151, 778),
                    "crouch": (151, 530, 297, 778),
                    "reach": (297, 530, 438, 778),
                    "dig": (438, 530, 585, 778),
                    "pull": (585, 530, 727, 778),
                    "lift": (727, 530, 866, 778),
                    "toss": (866, 530, 1018, 778),
                    "high": (1018, 530, 1154, 778),
                    "land": (1154, 530, 1300, 778),
                },
                "left": {
                    "stance": (12, 789, 159, 1035),
                    "crouch": (159, 789, 304, 1035),
                    "reach": (304, 789, 442, 1035),
                    "dig": (442, 789, 589, 1035),
                    "pull": (589, 789, 734, 1035),
                    "lift": (734, 789, 867, 1035),
                    "toss": (867, 789, 1020, 1035),
                    "high": (1020, 789, 1169, 1035),
                    "land": (1169, 789, 1311, 1035),
                },
            },
            "sheets": {
                "Armor": ["crouch", "reach", "dig", "pull", "lift", "toss", "high", "land"],
            },
        },
    },
    "shadow_hound": {
        # 2026-10-28: the Shadow Hound summon (Summon Shadow Hound) — a wolf of
        # black smoke veined with lightning, with silver claws — from its
        # sheet's top row (the detail panels are not used). The sheet came
        # cut out: its mattes are its own alpha (alpha > 128, written once
        # from the board instead of by tools/make_mattes.py). Both "FACING UP" and "FACING DOWN" show
        # the face — there is no back view — so the back is "FACING UP" (the
        # head low, the smoke trailing up) until the designer draws one.
        "src": "shadow_hound_board.webp", "bg": "grabcut", "tiles": 1.75,   # the front is a tall smoke column: this puts the side views at a wolf's height
        "matte": ("front", "back", "left", "right"),   # from the sheet's alpha (written below)
        "Idle": {
            "front": (306, 6, 514, 564),
            "back": (42, 6, 255, 564),
            "left": (530, 172, 1061, 564),
            "right": (1065, 172, 1531, 564),
        },
    },
    "hydra": {
        # 2026-10-28: the Hydra redrawn — a green many-headed serpent-beast
        # with a spined back and tail — from its sheet's top row (the detail
        # panels are not used), on a painted checkerboard. "FACING UP" shows
        # the heads' faces and "FACING DOWN" the backs of the necks: picked by
        # what they show; the side labels are true. Replaces its walk-sheet
        # cut (tools/cut_creature_sheets.py) — one pose a direction now.
        "src": "hydra_board.webp", "bg": "grabcut", "tiles": 2.2,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (11, 27, 316, 580),
            "back": (322, 73, 636, 580),
            "left": (652, 126, 1123, 580),
            "right": (1157, 105, 1529, 580),
        },
        # 2026-11-03: the designer's attack sheets — one board a facing on
        # black (hydra_attack_front_board.webp, _back_, _left_, _right_),
        # eight frames across, unlabelled, no floor shadow: the stance, the
        # heads rearing up and apart, the roar with every mouth opening, the
        # strike with the heads flung up and wide (the side views lunge
        # them forward), the heads spread out, drawing back in, nearly the
        # stance, and the stance. The frames crowd their slots — a head
        # reaches into the next frame's box — but no two touch, so the cut
        # keeps each frame's own figure and drops the neighbour's head. The
        # stance is the height reference, matched to each facing's Idle.
        "actions": {
            "src": {"front": "hydra_attack_front_board.webp", "back": "hydra_attack_back_board.webp",
                    "left": "hydra_attack_left_board.webp", "right": "hydra_attack_right_board.webp"},
            "fill_holes": 12,   # the black between the necks is the backdrop (mean ~2) and stays open; painted pockets are brighter
            "glow": False,   # no slash glow: a neighbouring head's red tongue in the box is not an arc to keep
            "open_dark": True,   # the black between legs and under the tail is backdrop, however small
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (22, 138, 234, 480),
                    "rear": (264, 138, 488, 480),
                    "roar": (502, 136, 748, 482),
                    "strike": (750, 126, 1024, 480),
                    "spread": (1030, 136, 1266, 482),
                    "settle": (1278, 144, 1502, 480),
                    "recover": (1526, 138, 1740, 482),
                },
                "back": {
                    "stance": (26, 108, 234, 508),
                    "rear": (266, 104, 486, 508),
                    "roar": (506, 94, 744, 508),
                    "strike": (750, 76, 1000, 508),
                    "spread": (1016, 94, 1258, 508),
                    "settle": (1276, 100, 1496, 508),
                    "recover": (1524, 112, 1738, 508),
                },
                "left": {
                    "stance": (18, 196, 244, 414),
                    "rear": (254, 198, 478, 414),
                    "roar": (474, 196, 754, 414),
                    "strike": (724, 206, 1036, 414),
                    "spread": (1014, 196, 1298, 414),
                    "settle": (1284, 196, 1522, 414),
                    "recover": (1540, 196, 1764, 414),
                },
                "right": {
                    "stance": (6, 200, 244, 442),
                    "rear": (246, 200, 478, 442),
                    "roar": (464, 198, 736, 442),
                    "strike": (690, 200, 1038, 442),
                    "spread": (948, 210, 1302, 442),
                    "settle": (1246, 200, 1520, 442),
                    "recover": (1506, 200, 1750, 442),
                },
            },
            "sheets": {
                "Attack": ["rear", "roar", "strike", "spread", "settle", "recover"],
            },
        },
    },
    "hydra_heal": {
        # 2026-11-03: the Hydra's heal — hydra_heal_board.webp, "5 HEADS ->
        # 8 HEADS / HEAL + REGROW": twelve numbered frames facing the camera
        # on a checkerboard, in two framed panels: five heads on all fours,
        # rising onto her hind legs, rearing tall with her claws up, the
        # heads roaring, new necks sprouting and budding into heads, eight
        # heads roaring, and settling. One facing: the figure plays it
        # facing the camera whichever way she faces. Packed into the full
        # Hydra's folder (her Heal plays as she regrows every head), its
        # first frame standing as tall as the five-head Hydra's front Idle.
        "into": "hydra",
        "match_to": "hydra_5",
        "actions": {
            "src": "hydra_heal_board.webp",
            "bg": "checker_light",
            "rows": ["front"],
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (26, 211, 250, 475),
                    "rise": (277, 190, 506, 476),
                    "rear": (520, 179, 753, 476),
                    "up": (776, 153, 1009, 476),
                    "tall": (1032, 129, 1263, 476),
                    "roar": (1288, 119, 1523, 476),
                    "sprout": (12, 561, 256, 919),
                    "bud": (264, 566, 505, 919),
                    "grown": (520, 564, 745, 919),
                    "crown": (776, 547, 1002, 919),
                    "howl": (1032, 550, 1259, 919),
                    "settle": (1288, 543, 1527, 919),
                },
            },
            "sheets": {
                "Heal": ["stance", "rise", "rear", "up", "tall", "roar", "sprout", "bud", "grown", "crown", "howl", "settle"],
            },
        },
    },
    "hydra_8": {
        # 2026-11-03: the Hydra with eight heads — the designer's board of
        # her after the first hit she takes (every hit costs her heads; her
        # heal regrows them all): four labelled poses on a checkerboard,
        # NORTH (FRONT), SOUTH (BACK), WEST (LEFT), EAST (RIGHT), the same
        # green serpent-beast with two heads fewer. The board draws her
        # stockier and lower-crowned than her full board, so she is sized
        # by her body, not her height: at 1.8 tiles her legs and trunk
        # match the full Hydra's attack stance (2.2 tiles would make her
        # a quarter bulkier for losing heads).
        "src": "hydra_8_board.webp", "bg": "checker_light", "tiles": 1.8,
        "Idle": {
            "front": (209, 8, 606, 496),
            "back": (832, 8, 1236, 496),
            "left": (69, 539, 661, 1003),
            "right": (769, 539, 1372, 1003),
        },
        # Her attack board — hydra_8_attack_board.webp, the four views
        # across the top (not used: the pose board is twice as fine) and
        # four labelled rows on black, eight numbered frames a row: the
        # stance, the heads rearing up, the roar, the strike, the heads
        # flung widest (the side views lunge them forward), drawing back
        # in, nearly the stance, and the stance — the same swing as the
        # full Hydra's sheets. The frames are small (a third of the pose
        # board's height) and are grown to the Idle's size.
        "actions": {
            "src": "hydra_8_attack_board.webp",
            "fill_holes": 12,
            "glow": False,
            "open_dark": True,
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (162, 270, 292, 428),
                    "rear": (338, 274, 474, 427),
                    "roar": (502, 274, 649, 428),
                    "strike": (660, 268, 835, 427),
                    "spread": (839, 268, 1025, 428),
                    "settle": (1040, 273, 1189, 426),
                    "recover": (1223, 273, 1354, 428),
                },
                "back": {
                    "stance": (171, 463, 295, 617),
                    "rear": (336, 463, 486, 617),
                    "roar": (503, 463, 656, 616),
                    "strike": (668, 461, 845, 616),
                    "spread": (844, 459, 1032, 617),
                    "settle": (1042, 462, 1198, 617),
                    "recover": (1224, 461, 1363, 617),
                },
                "left": {
                    "stance": (161, 650, 309, 796),
                    "rear": (324, 655, 477, 795),
                    "roar": (479, 649, 649, 795),
                    "strike": (644, 650, 830, 796),
                    "spread": (821, 657, 1034, 795),
                    "settle": (1032, 651, 1203, 794),
                    "recover": (1223, 652, 1368, 795),
                },
                "right": {
                    "stance": (151, 833, 301, 982),
                    "rear": (317, 832, 479, 981),
                    "roar": (486, 827, 663, 982),
                    "strike": (661, 829, 846, 981),
                    "spread": (835, 831, 1031, 981),
                    "settle": (1036, 834, 1199, 981),
                    "recover": (1211, 832, 1364, 981),
                },
            },
            "sheets": {
                "Attack": ["rear", "roar", "strike", "spread", "settle", "recover"],
            },
        },
    },
    "hydra_5": {
        # 2026-11-03: the Hydra with five heads — after her second hit —
        # four labelled poses on a checkerboard, NORTH (FRONT), SOUTH
        # (BACK), WEST (LEFT), EAST (RIGHT). Sized by her body like the
        # eight-head set (TILES_H5), so the sets swap without her swelling.
        "src": "hydra_5_board.webp", "bg": "checker_light", "tiles": TILES_H5,
        "Idle": {
            "front": (185, 12, 609, 488),
            "back": (947, 12, 1458, 494),
            "left": (88, 494, 718, 966),
            "right": (853, 496, 1449, 965),
        },
        # Her attack board — hydra_5_attack_board.webp: the four views across
        # the top (not used: the pose board is finer) and four labelled rows
        # in framed panels on a dark navy backdrop, eight numbered frames a
        # row, the same swing as the other sets. The backdrop is ~15-26, not
        # black: the levels sit above it, and only pockets painted brighter
        # than it are filled (the navy between the necks stays open). The
        # panel frames and numbers are pieces apart from her and fall away.
        "actions": {
            "src": "hydra_5_attack_board.webp",
            "levels": (30, 60, 36),
            "fill_holes": 28,   # the navy is 15-26: a pocket brighter than that is painted shade
            "glow": False,
            "open_dark": True,
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (168, 266, 294, 418),
                    "rear": (340, 269, 468, 418),
                    "roar": (502, 270, 649, 418),
                    "strike": (671, 264, 837, 418),
                    "spread": (844, 264, 1021, 418),
                    "settle": (1034, 269, 1176, 418),
                    "recover": (1214, 269, 1347, 419),
                },
                "back": {
                    "stance": (163, 456, 293, 600),
                    "rear": (338, 455, 477, 602),
                    "roar": (502, 455, 654, 602),
                    "strike": (670, 454, 837, 603),
                    "spread": (846, 453, 1020, 603),
                    "settle": (1034, 454, 1190, 604),
                    "recover": (1216, 455, 1353, 603),
                },
                "left": {
                    "stance": (157, 638, 309, 781),
                    "rear": (330, 637, 479, 780),
                    "roar": (496, 638, 651, 780),
                    "strike": (656, 640, 844, 780),
                    "spread": (833, 636, 1035, 781),
                    "settle": (1034, 639, 1203, 780),
                    "recover": (1210, 637, 1369, 780),
                },
                "right": {
                    "stance": (150, 821, 306, 970),
                    "rear": (324, 819, 480, 971),
                    "roar": (492, 817, 662, 971),
                    "strike": (665, 818, 845, 972),
                    "spread": (839, 818, 1036, 972),
                    "settle": (1032, 819, 1193, 971),
                    "recover": (1203, 821, 1356, 971),
                },
            },
            "sheets": {
                "Attack": ["rear", "roar", "strike", "spread", "settle", "recover"],
            },
        },
    },
    "hydra_3": {
        # 2026-11-03: the Hydra with three heads — after her third hit, the
        # last set. One board, hydra_3_attack_board.webp, on the same dark
        # navy as the five-head attack board: her four views across the top
        # (NORTH (FRONT), SOUTH (BACK), WEST (LEFT), EAST (RIGHT): her Idle,
        # cut by brightness — there is no pose board of her own) and four
        # rows of eight numbered attack frames below. Sized by her body like
        # the other sets (TILES_H3).
        "src": "hydra_3_attack_board.webp", "bg": "black_glow", "tiles": TILES_H3,
        "levels": (30, 60, 36),
        "fill_holes": 28,
        "open_dark": True,
        "Idle": {
            "front": (313, 10, 489, 194),
            "back": (602, 9, 761, 192),
            "left": (861, 10, 1072, 191),
            "right": (1192, 11, 1399, 191),
        },
        "actions": {
            "src": "hydra_3_attack_board.webp",
            "levels": (30, 60, 36),
            "fill_holes": 28,
            "glow": False,
            "open_dark": True,
            # The left spread's box reaches the panel's frame line, which
            # her topmost head touches: the line's three rows are cleared.
            "bg_boxes": {("left", "spread"): [(0, 0, 220, 3)]},
            "match": "stance",
            "frames": {
                "front": {
                    "stance": (168, 254, 291, 396),
                    "rear": (343, 254, 472, 396),
                    "roar": (508, 253, 651, 395),
                    "strike": (669, 250, 834, 395),
                    "spread": (836, 247, 1016, 395),
                    "settle": (1037, 257, 1177, 395),
                    "recover": (1219, 254, 1341, 396),
                },
                "back": {
                    "stance": (174, 440, 288, 586),
                    "rear": (340, 438, 462, 586),
                    "roar": (506, 438, 646, 586),
                    "strike": (672, 438, 830, 587),
                    "spread": (849, 438, 1021, 587),
                    "settle": (1044, 439, 1178, 586),
                    "recover": (1224, 439, 1346, 587),
                },
                "left": {
                    "stance": (159, 625, 295, 761),
                    "rear": (330, 624, 472, 760),
                    "roar": (493, 620, 653, 761),
                    "strike": (650, 619, 830, 761),
                    "spread": (814, 618, 1027, 761),
                    "settle": (1030, 622, 1186, 761),
                    "recover": (1214, 623, 1358, 761),
                },
                "right": {
                    "stance": (154, 806, 295, 955),
                    "rear": (327, 807, 474, 955),
                    "roar": (495, 804, 651, 955),
                    "strike": (661, 801, 845, 955),
                    "spread": (836, 801, 1037, 955),
                    "settle": (1034, 805, 1187, 955),
                    "recover": (1208, 806, 1355, 955),
                },
            },
            "sheets": {
                "Attack": ["rear", "roar", "strike", "spread", "settle", "recover"],
            },
        },
    },
    "olorin": {
        # 2026-10-28: Olorin — the grey wanderer in a wide hat and tattered
        # cloak, an orb-topped branch staff, a sword on his back, his bear at
        # his side — from his sheet's top row (the detail panels are not
        # used). "facing up" shows his face and "facing down" his back. His
        # "facing left" bear has a head at each end, so the designer chose
        # "facing right" (mirrored for the left), with the stray arm and
        # second staff out of his back removed by tools/fix_olorin_board.py,
        # which writes this board. The height counts the staff's top.
        "src": "olorin_board.png", "bg": "grabcut", "tiles": 2.15,
        # Hat tip to boots, he is drawn ~9% smaller in profile and ~13%
        # smaller from behind than from the front (the left mirrors the right).
        "pose_scale": {"back": 1.13, "right": 1.09, "left": 1.09},
        "matte": ("front", "back", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (21, 59, 363, 580),
            "back": (381, 109, 701, 568),
            "right": (1176, 177, 1529, 577),
            "left": ("mirror", "right"),
        },
    },
    "seance_specter": {
        # 2026-10-28: Jeremy's Seance spirit — a white-haired skeletal wraith
        # in a tattered dark cloak, its lower body violet flame trailing to
        # wisps — on a painted checkerboard. "FACING UP" shows its face and
        # "FACING DOWN" its back; both side poses face right, so "FACING
        # RIGHT" is the right, mirrored for the left (the detail panels and
        # the pounce are not used). The boxes stop above the labels.
        "src": "seance_specter_board.webp", "bg": "grabcut", "tiles": 1.75,
        "matte": ("front", "back", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (14, 32, 296, 593),
            "back": (372, 44, 684, 593),
            "right": (1158, 46, 1452, 593),
            "left": ("mirror", "right"),
        },
    },
    "crypt_crawler": {
        # 2026-10-28: the Crypt Crawler — a great bristling grave spider with
        # a cracked, cross-carved headstone and skulls grown into its back,
        # moss and cobweb between its legs — FRONT, BACK, LEFT, RIGHT on
        # black, each side facing its own way. The legs reach past the labels'
        # tops, so the labels are marked background. The height runs from the
        # headstone's top to the leg tips.
        "src": "crypt_crawler_board.webp", "bg": "grabcut", "tiles": 1.6,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "matte_bg": {"front": [(246, 531, 362, 569)],
                     "back": [(261, 523, 357, 560)],
                     "left": [(255, 533, 350, 570)],
                     "right": [(228, 526, 338, 563)]},
        "Idle": {
            "front": (10, 10, 615, 585),
            "back": (665, 20, 1248, 595),
            "left": (15, 605, 607, 1172),
            "right": (660, 612, 1240, 1172),
        },
    },
    "mind_eater": {
        # 2026-10-28: the Mind Eater — a domed, mottled violet head over a
        # maw of long fangs, a mass of suckered tentacles trailing below —
        # four labelled poses on black. Its "LEFT" pose faces right and its
        # "RIGHT" pose faces left (the mouth shows the way), so each is used
        # for the way it faces. The tentacle tips reach past the labels' tops,
        # so the labels are marked background instead of cropped off. The
        # height runs from the dome to the lowest tentacle tip.
        "src": "mind_eater_board.webp", "bg": "grabcut", "tiles": 1.9,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "matte_bg": {"front": [(240, 506, 364, 542)],
                     "back": [(233, 496, 337, 532)],
                     "right": [(261, 536, 362, 572)],
                     "left": [(178, 535, 297, 573)]},
        "Idle": {
            "front": (30, 30, 600, 580),
            "back": (690, 40, 1230, 572),
            "right": (20, 610, 545, 1180),   # labelled LEFT, faces right
            "left": (735, 615, 1232, 1188),  # labelled RIGHT, faces left
        },
        # 2026-11-04: the designer's tentacle board — mind_eater_writhe_board.webp,
        # "TENTACLED HORROR - TENTACLE IDLE (LOOP)", four labelled rows in
        # framed panels on black (NORTH (FRONT), SOUTH (BACK), WEST (LEFT),
        # EAST (RIGHT), each facing its own way), eight numbered frames a row
        # of its tentacles writhing. The designer: this is what it does when
        # it attacks — Writhe.png, all eight frames, played in place for its
        # Mind Slow and its Manipulate Mind Space. The first frame is the
        # height reference, matched to each facing's Idle. The bright band
        # across the back row is its bodies lining up, not a line.
        "actions": {
            "src": "mind_eater_writhe_board.webp",
            "levels": (8, 36, 10),
            "fill_holes": 20,
            "open_dark": True,
            "glow": False,
            "split": True,
            "isolate_floor": 14,
            "match": "w1",
            "frames": {
                "front": {
                    "w1": (102, 68, 277, 293),
                    "w2": (277, 68, 453, 293),
                    "w3": (453, 68, 628, 293),
                    "w4": (628, 68, 805, 293),
                    "w5": (805, 68, 983, 293),
                    "w6": (983, 68, 1161, 293),
                    "w7": (1161, 68, 1340, 293),
                    "w8": (1340, 68, 1525, 293),
                },
                "back": {
                    "w1": (102, 300, 280, 506),
                    "w2": (280, 300, 456, 506),
                    "w3": (456, 300, 632, 506),
                    "w4": (632, 300, 808, 506),
                    "w5": (808, 300, 986, 506),
                    "w6": (986, 300, 1165, 506),
                    "w7": (1165, 300, 1342, 506),
                    "w8": (1342, 300, 1525, 506),
                },
                "left": {
                    "w1": (102, 513, 287, 744),
                    "w2": (287, 513, 462, 744),
                    "w3": (462, 513, 636, 744),
                    "w4": (636, 513, 811, 744),
                    "w5": (811, 513, 987, 744),
                    "w6": (987, 513, 1166, 744),
                    "w7": (1166, 513, 1347, 744),
                    "w8": (1347, 513, 1525, 744),
                },
                "right": {
                    "w1": (102, 750, 277, 976),
                    "w2": (277, 750, 455, 976),
                    "w3": (455, 750, 633, 976),
                    "w4": (633, 750, 809, 976),
                    "w5": (809, 750, 986, 976),
                    "w6": (986, 750, 1164, 976),
                    "w7": (1164, 750, 1342, 976),
                    "w8": (1342, 750, 1525, 976),
                },
            },
            "sheets": {
                "Writhe": ["w1", "w2", "w3", "w4", "w5", "w6", "w7", "w8"],
            },
        },
    },
    "hell_door": {
        # 2026-10-28: Hell's Door — a horned skull of cracked stone over a
        # doorway of molten light, rubble piled round it — one view on black;
        # the designer's redraw of the cave pack's skull gate (gates1.png,
        # which it replaces). A door looks the same from every side, so all
        # four directions are the one view. ~3 tiles to the horns, as before.
        "src": "hell_door_board.webp", "bg": "grabcut", "tiles": 3.0,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        # The model may trim the doorway's glow: keep what is lit.
        "matte_fg": {d: [(0, 0, 9999, 9999, "lit", 45)] for d in ("front", "back", "left", "right")},
        "Idle": {
            "front": (30, 25, 1222, 1200),
            "back": (30, 25, 1222, 1200),
            "left": (30, 25, 1222, 1200),
            "right": (30, 25, 1222, 1200),
        },
    },
    "rat_nest": {
        # 2026-10-28: the Rat King's nest — a ring of straw round a dark
        # hollow, gnawed bones and a skull in its weave — one view on black.
        # A nest looks the same from every side, so all four directions are
        # the one view. ~2 tiles wide (its height ~1 tile), like the nest it
        # replaces (a battler drawn in code, now deleted).
        "src": "rat_nest_board.webp", "bg": "grabcut", "tiles": 1.0,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (130, 210, 1345, 820),
            "back": (130, 210, 1345, 820),
            "left": (130, 210, 1345, 820),
            "right": (130, 210, 1345, 820),
        },
    },
    "grave_digger": {
        # 2026-10-28: the Boneyard's Grave Digger — a heavy man in a flat cap,
        # waistcoat and mud-caked trousers, a spade on his back and a lit
        # lantern hung from a crooked pole over his shoulder — four labelled
        # poses on black (FRONT, BACK, LEFT, RIGHT; each side faces its own
        # way). The boxes stop above the labels; the height counts the
        # lantern's top (his body is ~1.65 tiles, like the townsfolk).
        "src": "grave_digger_board.webp", "bg": "grabcut", "tiles": 2.05,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        # The model drops the hanging lantern (a lit thing apart from him):
        # keep what is lit round it, above the soft glow.
        "matte_fg": {"front": [(250, 20, 350, 180, "lit", 55)],
                     "back": [(10, 20, 105, 180, "lit", 55)],
                     "left": [(25, 10, 115, 175, "lit", 55)],
                     "right": [(240, 10, 335, 175, "lit", 55)]},
        "Idle": {
            "front": (190, 0, 570, 558),
            "back": (725, 0, 1050, 558),
            "left": (110, 594, 470, 1120),
            "right": (790, 594, 1140, 1120),
        },
    },
    "npc_armory": {
        # 2026-10-28: the town's Armory keeper — a woman in a grimy dress,
        # leather apron and tool belt, long black gloves — from her NPC
        # sheet's top row ("FACING UP" the face, "FACING DOWN" the back).
        # Both side poses face right: "FACING RIGHT" is the right, mirrored
        # for the left. The boxes stop at her soles.
        "src": "armory_npc_board.webp", "bg": "grabcut", "tiles": 1.65,
        "sharpen": 140,
        "matte": ("front", "back", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (60, 32, 249, 534),
            "back": (420, 32, 605, 534),
            "right": (1189, 33, 1341, 538),
            "left": ("mirror", "right"),
        },
    },
    "npc_dojo_master": {
        # 2026-10-29: the Dojo master — an old bald sensei with a long white
        # beard and topknot, in a dark robe with a red sash — four poses on
        # black beside two target dummies: front and back on top, then the
        # pose facing right and the pose facing left.
        "src": "dojo_master_board.webp", "bg": "grabcut", "tiles": 1.75,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (992, 38, 1232, 510),
            "back": (1296, 38, 1529, 510),
            "right": (1024, 522, 1172, 978),
            "left": (1318, 522, 1465, 978),
        },
    },
    "npc_card_dealer": {
        # 2026-10-28: the town's Card Dealer — a dandy in a feathered tricorn
        # and a gold-trimmed black frock coat, cards fanned in one hand —
        # from his NPC sheet's top row (front, back, then two poses that both
        # face right: the first is the right, mirrored for the left), on a
        # painted checkerboard.
        "src": "card_dealer_npc_board.webp", "bg": "grabcut", "tiles": 1.75,
        "sharpen": 140,
        "matte": ("front", "back", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (124, 12, 345, 616),
            "back": (477, 12, 712, 614),
            "right": (870, 11, 1080, 614),
            "left": ("mirror", "right"),
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
    "werewolf": {
        # 2026-10-28: the designer's updated Werewolf — a shaggy, muscled
        # wolf-man on his hind legs, yellow eyes, a bushy tail — one row on
        # black with a soft painted shadow at the feet: front, back, then
        # two side views, the first facing right and the second left. The
        # back view's tail tip touches the right-facing one: split at x 727.
        # Kept at his old height (~1.9 tiles). Replaces his stone-floor walk
        # sheet (tools/cut_creature_sheets.py).
        "src": "werewolf_board.webp", "bg": "grabcut", "tiles": 1.9,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "drop_shadow": (0.06, 30),
        "Idle": {
            "front": (8, 190, 352, 745),
            "back": (380, 190, 727, 748),
            "right": (727, 190, 1132, 748),
            "left": (1172, 190, 1528, 748),
        },
        # 2026-10-30: the designer's slash boards. werewolf_slash_board.webp:
        # the same werewolf, two rows on black, facing right then facing
        # left — a wind-up with the far arm raised, a downward rake with the
        # near arm (a red arc past the muzzle), a lunging sweep with the far
        # arm (a red arc over the head), and the recovery, claws forward;
        # each row flanked by half a figure (the board tiles), not used.
        # werewolf_slash_front_back_board.webp (a screenshot, a blurred bar
        # across its top): two rows facing the camera and two from behind,
        # each with a wind-up, an arc rake, a lunging sweep and standing
        # poses; the front's rake arcs to the viewer's right and its sweep
        # to the left, the back's rake and sweep both to the right, so the
        # back sweep is mirrored and the two arcs alternate arms as the
        # side views' do. The slash arcs reach into the neighbouring
        # frames' boxes, so those slivers are cleared (bg boxes, in each
        # box's own coordinates). Each facing's recovery (the front's
        # square stance, the back's standing pose) is scaled to its Idle
        # pose's height. Claw = Attack (wind-up, rake, recovery); the rake
        # on a debuffed target, a second hit with the other arm = Attack2
        # (wind-up, rake, sweep, recovery), the front and back recovering
        # in the sweep's three-quarter turn.
        "actions": {
            "src": {"left": "werewolf_slash_board.webp", "right": "werewolf_slash_board.webp",
                    "front": "werewolf_slash_front_back_board.webp", "back": "werewolf_slash_front_back_board.webp"},
            "shadow_band": 0.10,
            "match": {"left": "recover", "right": "recover", "front": "stance", "back": "recover"},
            "match_scale": {"front": 0.9, "back": 0.9},   # the front/back board draws him bulkier than his Idle
            "frames": {
                "right": {
                    "windup": (62, 50, 340, 410),
                    "rake": (318, 55, 606, 410),
                    "sweep": (553, 75, 932, 410),
                    "recover": (893, 90, 1125, 410),
                    "recover2": ("same", "recover"),
                },
                "left": {
                    "windup": (95, 462, 350, 812),
                    "rake": (343, 474, 616, 812),
                    "sweep": (616, 500, 955, 812),
                    "recover": (955, 490, 1158, 812),
                    "recover2": ("same", "recover"),
                },
                "front": {
                    "windup": (14, 272, 212, 505),
                    "rake": (216, 44, 472, 275),
                    "sweep": (437, 294, 716, 506),
                    "recover": (692, 74, 910, 275),      # claws forward, turned the rake's way
                    "recover2": (716, 300, 930, 506),    # claws forward, turned the sweep's way
                    "stance": (912, 300, 1078, 505),     # the square front stance: the height reference only
                },
                "back": {
                    "windup": (22, 530, 226, 775),
                    "rake": (247, 530, 518, 775),
                    "sweep": ("mirror", (510, 556, 812, 775)),
                    "recover": (840, 556, 1056, 775),    # standing, as the Idle back
                    "recover2": (772, 808, 1036, 1033),  # the arm still out the sweep's way
                },
            },
            "bg_boxes": {
                ("right", "windup"): [(256, 245, 278, 360), (273, 100, 278, 195)],   # the rake's tail and back
                ("right", "rake"): [(0, 195, 28, 245), (237, 290, 288, 355)],   # the wind-up's claw; the sweep's left foot
                ("right", "sweep"): [(0, 0, 54, 267), (338, 228, 379, 335)],   # the rake's arc; the recovery's tail
                ("right", "recover"): [(0, 0, 37, 212)],          # the sweep's claw
                ("left", "windup"): [(240, 95, 255, 228)],        # the rake's arc
                ("left", "recover"): [(185, 0, 203, 215)],        # the next tile's half figure
                ("back", "sweep"): [(0, 0, 7, 118)],              # the rake's arc tip and glow (before the mirror)
            },
            "sheets": {
                "Attack": ["windup", "rake", "recover"],
                "Attack2": ["windup", "rake", "sweep", "recover2"],
            },
        },
    },
    "roc": {
        # 2026-10-28: the Roc — a great golden-brown eagle, ruff raised,
        # golden talons — one row on black: front, back, then two side views,
        # the first facing left and the second right. The side views' tails
        # brush past each other: split at x 1112. Bigger than the Giant Hawk
        # (1.6 tiles).
        "src": "roc_board.webp", "bg": "grabcut", "tiles": 2.1,
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "Idle": {
            "front": (14, 165, 370, 800),
            "back": (372, 165, 702, 810),
            "left": (702, 170, 1112, 808),
            "right": (1112, 170, 1532, 808),
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
        # 2026-10-27: the Air Mage redrawn — a silver-haired sorceress in a
        # tattered violet-and-blue robe, wind curling round her hands — four
        # labelled poses on black: front, back, left, right. Replaces her
        # cut from air_mage_board.jpg.
        "matte": ("front", "back", "left", "right"),   # the model matte (tools/make_mattes.py)
        "src": "air_mage_sorceress_board.webp", "bg": "grabcut", "tiles": 1.6,
        # The model drops the thin ends of the wind swirls: keep what is lit.
        "matte_fg": {d: [(0, 0, 9999, 9999, "lit", 45)] for d in ("front", "back", "left", "right")},
        "Idle": {
            "front": (110, 35, 500, 560),
            "back": (771, 32, 1128, 557),
            "left": (135, 640, 501, 1156),
            "right": (754, 640, 1105, 1155),
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

# The Golem summon (Summon Golem): the Granite Colossus in miniature, cut from
# the same board and its mattes at an ally's height (2026-10-28, so it matches
# the designer's other art; it wore the golem pack's chibi Golem1 until then).
BOARDS["summon_golem"] = {**BOARDS["granite_colossus"], "tiles": 1.5,
                          "matte_name": "granite_colossus"}

# Texels per tile the boards are cut at (designer, 2026-10-24: err on the
# side of under-pixelating what we make): twice the world's 32, the heroes'
# own fineness — one texel a screen pixel at the default zoom. Each board
# gives its front Idle's height in tiles; SpriteEnemyFigure draws these
# sheets at scale 32 / DENSITY.
DENSITY = 64
SMOOTH_GUTTER = 8   # empty rows under each smooth pose (see build)

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
    if kind == "black_key":
        return _cut_black_key(rgb)
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
            if len(hint) in (6, 7) and hint[4] == "lit":
                # Everything in the box brighter than the black board
                # (venom drips, a flame's wisps the model dropped). A 7th
                # value also fills the enclosed holes up to that many px
                # (near-black crevices in dark rock), not the wider gaps
                # between legs.
                x0, y0, x1, y1 = hint[0:4]
                m[y0:y1, x0:x1] = rgb[y0:y1, x0:x1].max(axis=2) > hint[5]
                if len(hint) == 7:
                    n, lab, st, _ = cv2.connectedComponentsWithStats((1 - m).astype(np.uint8), connectivity=4)
                    for i in range(1, n):
                        x, y, cw, ch, area = st[i]
                        if area <= hint[6] and x > 0 and y > 0 and x + cw < m.shape[1] and y + ch < m.shape[0]:
                            m[lab == i] = 1
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


BLACK_FLOOR = 12      # black_key: at or under this the board is background
BLACK_SOLID = 45      # black_key: at or over this a pixel is fully opaque
BLACK_BODY = 22       # black_key: the outline of a piece; what it encloses is solid
BLACK_SPECK = 12      # black_key: lit pieces smaller than this (px) are noise


def _cut_black_key(rgb: np.ndarray) -> Image.Image:
    """A board of many separate small things on pure black (the Swarm's
    bees): every lit piece is kept, not only the biggest, and the dim pixels
    (translucent wings, soft edges) get partial alpha with their colour
    un-darkened — the black board read as a premultiplied backdrop."""
    lum = rgb.max(axis=2).astype(float)
    alpha = np.clip((lum - BLACK_FLOOR) / float(BLACK_SOLID - BLACK_FLOOR), 0.0, 1.0)
    # Dark paint inside a bee (abdomen stripes, shaded legs) is not
    # backdrop: everything a piece's outline encloses, a pixel in from its
    # rim, is opaque; only the rim and the thin wing edges stay soft.
    body = (lum > BLACK_BODY).astype(np.uint8)
    outside = np.pad(1 - body, 1, constant_values=1)
    flood = outside.copy()
    cv2.floodFill(flood, None, (0, 0), 2)
    filled = (flood[1:-1, 1:-1] != 2).astype(np.uint8)   # the pieces, holes filled
    core = cv2.erode(filled, np.ones((3, 3), np.uint8)).astype(bool)
    alpha[core] = 1.0
    lit = (alpha > 0).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(lit, connectivity=8)
    small = np.zeros(n, bool)
    small[1:] = st[1:, cv2.CC_STAT_AREA] < BLACK_SPECK
    alpha[small[lab]] = 0.0
    a = np.maximum(alpha, 1e-6)[..., None]
    col = np.clip(rgb / a, 0, 255)
    col = np.where(alpha[..., None] > 0, col, 0)
    rgba = np.dstack([col, alpha * 255.0]).round().astype(np.uint8)
    ys, xs = np.nonzero(rgba[..., 3] > 0)
    return Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")


ACTION_ROWS = ["left", "right"]   # the rows of an action sheet (SpriteEnemyFigure: a two-row sheet)


def _cut_black_glow(rgb: np.ndarray, bg_boxes=(), shadow_band: float = 0.0, keep_share: float = 0.0,
                    fill_holes: bool = False, levels=None, glow: bool = True,
                    open_dark: bool = False, shadow_lum: float = 0.0) -> Image.Image:
    """One figure and the glow of its attack on pure black (the werewolf's
    slash board): alpha from brightness as the black key does, the dim
    glow of the slash arcs kept soft and un-darkened, then only the
    biggest lit piece (the figure) and the reddish pieces (the arcs)
    survive — a neighbouring frame's claw or tail that reaches into the
    box is dropped, its arc cleared by a bg box — and, with `keep_share`,
    every piece at least that share of the biggest (the wererat's tail,
    drawn apart from its body). Every pocket the outline closes in is
    solid with `fill_holes` (the wererat's near-black fur is paint as dark
    as the backdrop, and nothing on his board closes a pocket of backdrop
    in); with a brightness, also those painted brighter than it; else only
    small pockets are. `levels` (floor, solid, body) stand
    in for BLACK_FLOOR / BLACK_SOLID / BLACK_BODY: the wererat's black
    fur sits just above the backdrop's black, so his levels are low. The
    soft painted shadow
    at the feet (dim, colourless, in the bottom `shadow_band` of the
    figure and not inside the body) goes too. A board with no glow (`glow`
    False: the hydra's attack sheets) keeps nothing by its colour, so a
    neighbouring frame's red tongue in the box is dropped with the rest of
    that frame. With `open_dark` (the Hydra's small attack frames, where a
    gap between two legs is only a few dozen pixels) a pocket no brighter
    than `fill_holes` stays open whatever its size: it is the backdrop,
    not shading. `shadow_lum` is the brightest a floor-shadow pixel is
    (else the solid level): the Grave Titan's robe needs a low solid level
    and his floor shadow is brighter than it."""
    rgb = rgb.copy()
    for x0, y0, x1, y1 in bg_boxes:
        rgb[y0:y1, x0:x1] = 0
    floor, solid_at, body_at = levels or (BLACK_FLOOR, BLACK_SOLID, BLACK_BODY)
    lum = rgb.max(axis=2).astype(float)
    sat = (rgb.max(axis=2) - rgb.min(axis=2)).astype(float)
    alpha = np.clip((lum - floor) / float(solid_at - floor), 0.0, 1.0)
    body = (lum > body_at).astype(np.uint8)
    outside = np.pad(1 - body, 1, constant_values=1)
    flood = outside.copy()
    cv2.floodFill(flood, None, (0, 0), 2)
    filled = (flood[1:-1, 1:-1] != 2).astype(np.uint8)
    # Dark paint inside the body (shaded fur) is solid, but the black the
    # slash arc closes in against the chest is the board: only small
    # enclosed pockets are filled.
    if fill_holes is not True:
        # Small pockets are always the figure's; a bigger one only when
        # `fill_holes` is a brightness and the pocket is painted brighter
        # than that (the skeleton's cloak folds: the backdrop between his
        # legs, closed in by his foot shadow, is pure black and stays open).
        holes = (filled & (1 - body)).astype(np.uint8)
        hn, hlab, hst, _ = cv2.connectedComponentsWithStats(holes, connectivity=4)
        for i in range(1, hn):
            if hst[i, cv2.CC_STAT_AREA] > HOLE_FILL_MAX or open_dark:
                painted = fill_holes not in (False, None) and lum[hlab == i].mean() > float(fill_holes)
                if not painted:
                    filled[hlab == i] = 0
    core = cv2.erode(filled, np.ones((3, 3), np.uint8)).astype(bool)
    soft = alpha < 1.0
    alpha[core] = 1.0
    lit = (alpha > 0).astype(np.uint8)
    n, lab, st, _ = cv2.connectedComponentsWithStats(lit, connectivity=8)
    if n > 1:
        areas = st[1:, cv2.CC_STAT_AREA]
        biggest = 1 + int(np.argmax(areas))
        keep = np.zeros(n, bool)
        keep[biggest] = True
        for i in range(1, n):
            if i == biggest or areas[i - 1] < BLACK_SPECK:
                continue
            if keep_share > 0 and areas[i - 1] >= areas[biggest - 1] * keep_share:
                keep[i] = True
                continue
            px = rgb[lab == i].astype(float)
            r, g, b = px[:, 0].mean(), px[:, 1].mean(), px[:, 2].mean()
            keep[i] = glow and r > 1.4 * max(g, b) + 8   # a red slash arc
        alpha[~keep[lab]] = 0.0
    if shadow_band > 0:
        ys = np.nonzero((alpha > 0).any(axis=1))[0]
        y0 = int(ys.max() + 1 - (ys.max() + 1 - ys.min()) * shadow_band)
        shadow = (soft | (lum < (shadow_lum or solid_at))) & (sat < 20) & (lum < (shadow_lum or solid_at))
        shadow[:y0] = False
        alpha[shadow] = 0.0
    a = np.maximum(alpha, 1e-6)[..., None]
    col = np.clip(rgb / a, 0, 255)
    col = np.where(alpha[..., None] > 0, col, 0)
    rgba = np.dstack([col, alpha * 255.0]).round().astype(np.uint8)
    ys, xs = np.nonzero(rgba[..., 3] > 0)
    return Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")


def _fade_edge(img: Image.Image, side: str, px: int) -> Image.Image:
    """Alpha ramped to nothing over the last `px` pixels on one side of a
    cut-out: a bolt the frame box cuts through (the Djinn's lightning, which
    the arc sprite carries on) dissolves instead of ending on a straight line."""
    a = np.asarray(img).copy()
    h, w = a.shape[:2]
    n = max(1, min(px, w if side in ("left", "right") else h))
    ramp = np.linspace(0.0, 1.0, n, endpoint=False)[::-1] if side in ("right", "bottom") else np.linspace(0.0, 1.0, n, endpoint=False)
    alpha = a[..., 3].astype(float)
    if side == "right":
        alpha[:, w - n:] *= ramp[None, :]
    elif side == "left":
        alpha[:, :n] *= ramp[None, :]
    elif side == "bottom":
        alpha[h - n:, :] *= ramp[:, None]
    else:
        alpha[:n, :] *= ramp[:, None]
    a[..., 3] = alpha.round().astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def _sharpen(img: Image.Image, amount: float) -> Image.Image:
    """Unsharp mask on the colour (alpha untouched), for boards whose source is
    soft (lossy or upscaled): the detail reads after the cut is shrunk."""
    from PIL import ImageFilter
    rgb = img.convert("RGB").filter(ImageFilter.UnsharpMask(radius=2.0, percent=int(amount), threshold=2))
    out = rgb.convert("RGBA")
    out.putalpha(img.getchannel("A"))
    return out


def _drop_floor_shadow(img: Image.Image, band: float, lum_max: float = 80) -> Image.Image:
    """A painted floor shadow kept under the feet (the Grave Titan's board
    came cut out with its ellipse): dark, colourless pixels in the bottom
    `band` of the figure go, then the cut-out is cropped to what is left."""
    a = np.asarray(img).copy()
    rgb = a[..., :3].astype(int)
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    y0 = int(a.shape[0] * (1.0 - band))
    shadow = (lum < lum_max) & (sat < 20)
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


def action_rows(cfg: dict) -> list:
    """The rows of a creature's action sheets: the four Craftpix rows when
    its boards show every facing, else the two side rows."""
    if "rows" in cfg["actions"]:
        return cfg["actions"]["rows"]   # the heal: the front row only
    frames = cfg["actions"]["frames"]
    return ROWS if all(d in frames for d in ROWS) else ACTION_ROWS


def pack_action(frames: dict, poses: list, cell: int, rows: list, air: int = 0) -> Image.Image:
    """An action sheet: `poses` in order across, the facings down `rows`,
    each frame bottom-centred in its cell, `air` empty rows under the feet."""
    sheet = Image.new("RGBA", (cell * len(poses), cell * len(rows)))
    for r, d in enumerate(rows):
        for c, pose in enumerate(poses):
            f = frames[d][pose]
            sheet.paste(f, (c * cell + (cell - f.width) // 2, r * cell + cell - air - f.height), f)
    return sheet


def action_matte_path(kind: str, d: str, pose: str) -> str:
    """The saved model matte of one action frame (tools/make_mattes.py)."""
    return os.path.join(MATTES, "%s_act_%s_%s.png" % (kind, d, pose))


def _cut_action_matte(rgb: np.ndarray, matte: str, red_lum: int) -> Image.Image:
    """One action frame by its model matte (the Battle Turtle's armor board:
    its shading is as dark as the navy backdrop, so brightness can't part
    them). The matte is the figure, solid; the pieces the model leaves out
    that are red and lit (the brick flying over its head, the dirt it digs)
    are added back. Pieces under KEEP_SHARE of the biggest go (specks)."""
    fg = np.asarray(Image.open(matte).convert("L")) > 127
    lum = rgb.max(axis=2)
    red = (lum > red_lum) & (rgb[..., 0] > 1.25 * np.maximum(rgb[..., 1], rgb[..., 2]) + 6)
    n, lab, st, _ = cv2.connectedComponentsWithStats(red.astype(np.uint8), connectivity=8)
    for i in range(1, n):
        if st[i, cv2.CC_STAT_AREA] >= BLACK_SPECK * 4:
            fg |= lab == i
    n, lab, st, _ = cv2.connectedComponentsWithStats(fg.astype(np.uint8), connectivity=8)
    if n > 1:
        areas = st[1:, cv2.CC_STAT_AREA]
        keep = np.zeros(n, bool)
        keep[1:] = areas >= areas.max() * KEEP_SHARE * 0.25
        fg = keep[lab]
    ys, xs = np.nonzero(fg)
    rgba = np.dstack([rgb.astype(np.uint8), np.where(fg, 255, 0).astype(np.uint8)])
    return Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")


def cut_action_frames(cfg: dict, kind: str = "") -> dict:
    """The frames of a creature's action boards, full size, uncut to scale:
    {direction: {pose: image}}. A pose is a box on the facing's board,
    ("mirror", box) for the box flipped, or ("same", pose) for another
    pose of the facing again. With "matte" each frame is cut by its model
    matte (tools/make_mattes.py) instead of by brightness off the black."""
    act = cfg["actions"]
    boards = {}

    def board(d: str) -> Image.Image:
        name = act["src"][d] if isinstance(act["src"], dict) else act["src"]
        if name not in boards:
            boards[name] = Image.open(SRC % name)
        return boards[name]

    labels = {}

    def others(d: str, box) -> np.ndarray:
        """`isolate`: a mask of the pieces of the board in `box` that belong
        to another frame (their centre lies outside the box) — a crowded
        board's neighbouring dust cloud reaching in (the Titan's throw)."""
        name = act["src"][d] if isinstance(act["src"], dict) else act["src"]
        if name not in labels:
            lum = np.asarray(board(d).convert("RGB")).max(axis=2)
            # `isolate_floor`: tell the frames apart above the cut's own
            # floor where two touch only through their faint fringes (the
            # Sabertooth's lunge and bite).
            floor = act.get("isolate_floor", (act.get("levels") or (BLACK_FLOOR,))[0])
            labels[name] = cv2.connectedComponentsWithStats((lum > floor).astype(np.uint8), connectivity=8)
        _, lab, _, cen = labels[name]
        x0, y0, x1, y1 = box
        # The box may run past the board (the crop pads it with black).
        sub = np.zeros((y1 - y0, x1 - x0), lab.dtype)
        cx0, cy0 = max(0, x0), max(0, y0)
        cx1, cy1 = min(lab.shape[1], x1), min(lab.shape[0], y1)
        sub[cy0 - y0:cy1 - y0, cx0 - x0:cx1 - x0] = lab[cy0:cy1, cx0:cx1]
        ids = np.unique(sub)
        # A piece spanning the board is a table's lines (the Troll's smash
        # board), with whatever figure touches them: never blanked — the
        # lines themselves lie outside the frames' boxes.
        stats = labels[name][2]
        h, w = lab.shape
        away = [i for i in ids if i and not (x0 <= cen[i][0] < x1 and y0 <= cen[i][1] < y1)
                and stats[i, cv2.CC_STAT_WIDTH] < w * 0.5 and stats[i, cv2.CC_STAT_HEIGHT] < h * 0.5]
        return np.isin(sub, away)

    split_cache = {}
    bottoms = {}

    def alpha_split(d: str, box) -> Image.Image:
        """`bg: "alpha_split"`: a board that came cut out (its own alpha), its
        frames so close their wings touch (the Ash Harpy's flap). Every frame
        of the row is split at once: each solid pixel goes to the frame whose
        body (a column at its box's centre) it is nearest through the solid
        pixels themselves, so touching wings part at their narrowest contact;
        the soft edge goes with the solid pixels it hugs."""
        name = act["src"][d] if isinstance(act["src"], dict) else act["src"]
        row = [b for b in act["frames"][d].values() if b[0] not in ("same", "mirror") and b[1] == box[1] and b[3] == box[3]]
        key = (name, box[1], box[3])
        if key not in split_cache:
            rgba = np.asarray(board(d).convert("RGBA"))
            y0, y1 = box[1], box[3]
            X0, X1 = min(b[0] for b in row), max(b[2] for b in row)
            reg = rgba[y0:y1, X0:X1]
            if act.get("bg") == "alpha_split":
                solid = reg[..., 3] >= 128
            else:
                # `split` on a board on black: what is lit is solid (the
                # Magma Spider's web board, its globs touching the next
                # frame's spider).
                floor = act.get("split_floor", act.get("isolate_floor", (act.get("levels") or (BLACK_FLOOR,))[0]))
                solid = reg[..., :3].max(axis=2) > floor
            h, w = solid.shape
            lab = np.full((h, w), -1, np.int32)
            q = deque()
            # `discard`: points on the board (the Magma Spider's painted
            # globs) that seed a label of their own; what is nearer them than
            # any frame's body goes with them and is dropped.
            for gx, gy in act.get("discard", {}).get(d, ()):
                if y0 <= gy < y1 and X0 <= gx < X1:
                    for yy in range(max(0, gy - y0 - 4), min(h, gy - y0 + 5)):
                        for xx in range(max(0, gx - X0 - 4), min(w, gx - X0 + 5)):
                            if solid[yy, xx] and lab[yy, xx] < 0:
                                lab[yy, xx] = len(row)
                                q.append((yy, xx))
            near_glob = np.zeros((h, w), bool)   # body seeds stay clear of a discard point
            for gx, gy in act.get("discard", {}).get(d, ()):
                yy0, xx0 = gy - y0, gx - X0
                near_glob[max(0, yy0 - 20):max(0, yy0 + 21), max(0, xx0 - 20):max(0, xx0 + 21)] = True
            # `split_centres`: each frame's body column on the board, when a
            # box was widened toward its spray and its middle no longer is.
            given = act.get("split_centres", {}).get(d)
            body_x = [int(given[k]) if given else (b[0] + b[2]) // 2 for k, b in enumerate(row)]
            for j, b in enumerate(row):
                cx = body_x[j] - X0
                for x in range(max(0, cx - 6), min(w, cx + 7)):
                    for y in np.nonzero(solid[:, x])[0]:
                        if lab[y, x] < 0 and not near_glob[y, x]:
                            lab[y, x] = j
                            q.append((y, x))
            while q:
                y, x = q.popleft()
                for dy, dx in _N4:
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and solid[ny, nx] and lab[ny, nx] < 0:
                        lab[ny, nx] = lab[y, x]
                        q.append((ny, nx))
            if act.get("bg") != "alpha_split" and act.get("split_floor"):
                # Split on the bright parts only (`split_floor`): faint haze
                # no longer bridges one frame to the next; then each label
                # grows a few pixels into the dim pixels beside it (its own
                # dark shading), never across a frame's bright parts.
                dim = reg[..., :3].max(axis=2) > (act.get("levels") or (BLACK_FLOOR,))[0]
                for _ in range(int(act.get("split_grow", 6))):
                    grown = lab.copy()
                    for dy, dx in _N4:
                        sh = np.roll(lab, (dy, dx), axis=(0, 1))
                        take = (grown < 0) & dim & (sh >= 0)
                        grown[take] = sh[take]
                    lab = grown
                solid = solid | (dim & (lab >= 0))
            # Islands no body reaches (a loose flame): the nearest body's.
            centres = np.array([x - X0 for x in body_x])
            ys, xs = np.nonzero(solid & (lab < 0))
            for y, x in zip(ys, xs):
                lab[y, x] = int(np.argmin(np.abs(centres - x)))
            # The soft edge: within 4 px of a frame's solid pixels.
            soft = (reg[..., 3] >= 24) & ~solid
            for j in range(len(row)):
                near = cv2.dilate((lab == j).astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool)
                lab[soft & near & (lab < 0)] = j
            split_cache[key] = (reg, lab, X0, row)
        reg, lab, X0, row = split_cache[key]
        j = row.index(box)
        img = reg.copy()
        img[..., 3] = np.where(lab == j, img[..., 3], 0)
        ys, xs = np.nonzero(img[..., 3] > 0)
        # Its lowest solid row on the board (`keep_ground` measures heights
        # against it).
        solid_ys = np.nonzero(img[..., 3] >= 128)[0]
        bottom = int(solid_ys.max() if len(solid_ys) else ys.max())
        bottoms[(d, box)] = box[1] + bottom
        if act.get("keep_ground"):
            # Heights are measured from the lowest solid row: the faint
            # painted shadow below it would stand the frame on the shadow,
            # lifting it (the game draws its own shadow).
            return Image.fromarray(img[ys.min():bottom + 1, xs.min():xs.max() + 1], "RGBA")
        return Image.fromarray(img[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")

    out = {}
    for d, poses in act["frames"].items():
        out[d] = {}
        again = []
        for pose, spec in poses.items():
            if spec[0] == "same":
                again.append((pose, spec[1]))
                continue
            mirror = spec[0] == "mirror"
            box = spec[1] if mirror else spec
            if act.get("bg") == "alpha_split":
                img = alpha_split(d, box)
                out[d][pose] = img.transpose(Image.FLIP_LEFT_RIGHT) if mirror else img
                continue
            if act.get("bg"):
                # A board on a checkerboard (the Hydra's heal): cut as the
                # pose boards are, not by brightness off black.
                img = cut(board(d), box, act["bg"])
                out[d][pose] = img.transpose(Image.FLIP_LEFT_RIGHT) if mirror else img
                continue
            rgb = np.asarray(board(d).crop(box).convert("RGB")).astype(int)
            if act.get("split"):
                # Each pixel to the frame whose body it is nearest through
                # the lit pixels: touching frames part at their narrowest
                # contact (see alpha_split, which does the same on alpha).
                part = np.asarray(alpha_split(d, box))
                key = (act["src"][d] if isinstance(act["src"], dict) else act["src"], box[1], box[3])
                reg, lab, X0, row = split_cache[key]
                j = row.index(box)
                mine = lab[:, box[0] - X0:box[2] - X0] == j
                rgb[~mine] = 0
            if act.get("drop_dim_green"):
                # A glow painted on black (the Cobra's venom haze) reads as a
                # dark smudge on a lit floor: its dim green goes.
                g, r_, b_ = rgb[..., 1], rgb[..., 0], rgb[..., 2]
                rgb[(g > r_ * 1.2) & (g > b_ * 1.2) & (rgb.max(axis=2) < act["drop_dim_green"])] = 0
            elif act.get("isolate") and (d, pose) not in act.get("isolate_skip", ()):
                rgb[others(d, box)] = 0
            img = _cut_black_glow(rgb, act.get("bg_boxes", {}).get((d, pose), ()), act.get("shadow_band", 0.0),
                                  act.get("keep_share", 0.0), act.get("fill_holes", False), act.get("levels"),
                                  act.get("glow", True), act.get("open_dark", False), act.get("shadow_lum", 0.0))
            for side, px in act.get("edge_fade", {}).get((d, pose), ()):
                img = _fade_edge(img, side, px)
            out[d][pose] = img.transpose(Image.FLIP_LEFT_RIGHT) if mirror else img
        for pose, other in again:
            out[d][pose] = out[d][other]
        if act.get("keep_ground"):
            # A jump (the Magma Spider's Fire Bounce): every frame keeps its
            # height above the ground line — the match pose's lowest solid
            # row — instead of standing on it: an airborne frame is padded
            # down to the line, and how far a frame reaches below it (a fire
            # burst at the feet) is kept for the packing (act["_drops"]).
            line = bottoms[(d, poses[act.get("match", "recover") if isinstance(act.get("match"), str) else act["match"][d]])]
            act.setdefault("_drops", {})
            for pose, spec in poses.items():
                if spec[0] in ("same", "mirror") or (d, spec) not in bottoms:
                    continue
                img = out[d][pose]
                lowest = bottoms[(d, spec)]
                # the image's bottom edge on the board: its soft fringe may
                # run a little below the lowest solid row
                below = max(0, lowest - line)
                gap = max(0, line - lowest)
                if gap:
                    pad = Image.new("RGBA", (img.width, img.height + gap))
                    pad.paste(img, (0, 0))
                    out[d][pose] = pad
                act["_drops"][(d, pose)] = below
                act.setdefault("_air", {})[(d, pose)] = gap
    return out


def _action_setting(cfg: dict, key: str, default, d: str):
    v = cfg["actions"].get(key, default)
    return v.get(d, default) if isinstance(v, dict) else v


def _used_poses(cfg: dict) -> set:
    return {p for poses in cfg["actions"]["sheets"].values() for p in poses}


def cut_actions(name: str, cfg: dict, full: dict) -> dict:
    """The action frames, full size, each facing's scaled so its `match`
    pose stands as tall as that facing's Idle pose (full size too)."""
    out = cut_action_frames(cfg, name)
    for d, fs in out.items():
        k = full["Idle"][d].height / float(fs[_action_setting(cfg, "match", "recover", d)].height) * _action_setting(cfg, "match_scale", 1.0, d)
        for pose, f in fs.items():
            size = (max(1, round(f.width * k)), max(1, round(f.height * k)))
            fs[pose] = f.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
            if (d, pose) in cfg["actions"].get("_drops", {}):
                cfg["actions"]["_drops"][(d, pose)] *= k   # full size, as the Idle
                cfg["actions"]["_air"][(d, pose)] *= k
    # Only the poses a sheet plays are packed (a height reference is not).
    used = _used_poses(cfg)
    return {d: {p: f for p, f in fs.items() if p in used} for d, fs in out.items()}


def _sheet_rows(sheet: Image.Image, cell: int):
    """Each row's drawn height and the empty rows under its feet (its air)
    in a packed four-row sheet, from the first column."""
    out = []
    for r in range(4):
        box = sheet.crop((0, r * cell, cell, (r + 1) * cell)).getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
        out.append((box[3] - box[1], cell - box[3]) if box else (cell, 0))
    return out


def _regrow(sheet: Image.Image, old: int, new: int) -> Image.Image:
    """A packed sheet in bigger square cells: every cell's content shifted
    to sit bottom-centred in its new cell, so nothing else moves."""
    cols, rows = sheet.width // old, sheet.height // old
    out = Image.new("RGBA", (cols * new, rows * new))
    dx, dy = (new - old) // 2, new - old
    for r in range(rows):
        for c in range(cols):
            out.paste(sheet.crop((c * old, r * old, (c + 1) * old, (r + 1) * old)), (c * new + dx, r * new + dy))
    return out


def build_actions_on_sheets(name: str, cfg: dict) -> None:
    """Action sheets for a creature whose Idle / Walk were cut by another
    tool (the wolf's walk sheet, tools/cut_creature_sheets.py): each facing
    is scaled so its `match` pose stands as tall as that row of the
    existing Idle sheet (pixel and smooth each), and the frames are packed
    with the Idle rows' own air under the feet. When a frame outgrows the
    Idle cell, Idle.png and Walk.png are regrown to the new cell (their
    content shifted, not resampled: SpriteEnemyFigure indexes every sheet
    by the Idle cell)."""
    raw = cut_action_frames(cfg, name)
    used = _used_poses(cfg)
    rows = action_rows(cfg)
    folder = cfg.get("into", name)   # the heal is packed into the Hydra's own folder
    frames = {}
    for root, kind in ((OUT % folder, "pixel"), (os.path.join(smooth_art.ROOT, "sheets", folder), "smooth")):
        idle = Image.open(os.path.join(root, "Idle.png"))
        cell = idle.height // 4
        info = dict(zip(ROWS, _sheet_rows(idle, cell)))
        # `match_to`: the match pose stands as tall as another kind's Idle
        # pose of that facing (the heal's five-head stance: the five-head
        # Hydra's), not as this folder's own.
        ref = info
        if cfg.get("match_to"):
            rroot = root.replace("/" + folder, "/" + cfg["match_to"])
            ridle = Image.open(os.path.join(rroot, "Idle.png"))
            ref = dict(zip(ROWS, _sheet_rows(ridle, ridle.height // 4)))
        frames = {}
        for d, fs in raw.items():
            k = ref[d][0] / float(fs[_action_setting(cfg, "match", "recover", d)].height) * _action_setting(cfg, "match_scale", 1.0, d)
            frames[d] = {}
            for pose, f in fs.items():
                if pose not in used:
                    continue
                if kind == "pixel":
                    frames[d][pose] = shrink(f, 1.0 / k)
                else:
                    frames[d][pose] = smooth_art.trim(smooth_art.resample(f, 1.0 / k))
        air = max(a for _, a in info.values())
        need = max(max(f.width, f.height) for fs in frames.values() for f in fs.values()) + 2 + air
        if need > cell:
            # Every sheet in the folder (the Hydra's Attack too, not only
            # Idle / Walk) is regrown; this entry's own sheets are rewritten.
            # A thrown strip (Boulder.png, Snowball.png) has cells of its
            # own and is left as it is.
            for f in sorted(os.listdir(root)):
                if f.endswith(".png") and f[:-4] not in cfg["actions"]["sheets"]:
                    path = os.path.join(root, f)
                    im = Image.open(path)
                    if im.height % cell or im.width % cell:
                        continue
                    _regrow(im, cell, need).save(path)
            print("%-13s %s cells %d -> %d px (its sheets regrown)" % (folder, kind, cell, need))
            cell = need
        for anim, poses in cfg["actions"]["sheets"].items():
            if kind == "pixel":
                pack_action(frames, poses, cell, rows, air).save(os.path.join(root, anim + ".png"))
            else:
                smooth_art.pack([[frames[d][p] for p in poses] for d in rows], cell, len(poses), lambda row, ci: row[ci], air=air).save(os.path.join(root, anim + ".png"))
    dims = ", ".join("%s %dx%d" % (d, f.width, f.height) for d, f in frames[rows[0]].items())
    print("%-13s on %s's sheets: %s" % (name, folder, dims))


def build_strip(name: str, cfg: dict) -> None:
    """A one-row strip of frames that is not the creature itself (the Grave
    Titan's rolling boulder): the board came cut out (its own alpha), each
    box's pieces kept whole (pebbles and dust too), every frame scaled so the
    first stands `width_tiles` wide, packed bottom-centred into square cells
    in one row — pixel (on/off alpha) and smooth — into the kind's folder."""
    st = cfg["strip"]
    board = Image.open(SRC % st["src"]).convert("RGBA")
    raw = []
    for box in st["frames"]:
        if st.get("bg") == "black_key":
            # A strip on black (the Rat King's Infest smoke): cut by
            # brightness, soft alpha, every lit piece kept; padded back to
            # the box so `align` still lines the frames up.
            rgb = np.asarray(board.convert("RGB").crop(box)).astype(int)
            lum = rgb.max(axis=2).astype(float)
            alpha = np.clip((lum - BLACK_FLOOR) / float(BLACK_SOLID - BLACK_FLOOR), 0.0, 1.0)
            a = np.maximum(alpha, 1e-6)[..., None]
            col = np.where(alpha[..., None] > 0, np.clip(rgb / a, 0, 255), 0)
            # `alpha_gain`: the smoke thickened (its colour kept), so a wisp
            # drawn faint on black still reads as a dark shadow on a lit floor.
            alpha = np.clip(alpha * float(st.get("alpha_gain", 1.0)), 0.0, 1.0)
            f = Image.fromarray(np.dstack([col, alpha * 255.0]).round().astype(np.uint8), "RGBA")
            raw.append(f)
            continue
        f = board.crop(box)
        a = np.asarray(f).copy()
        a[..., 3] = np.where(a[..., 3] >= 128, 255, 0)   # the board's faint haze goes
        f = Image.fromarray(a, "RGBA")
        raw.append(f)
    # Trimmed to each frame's art; with `align` "board" every frame keeps the
    # rows they span together, so a ball flying level doesn't bob as its
    # sparkles come and go (the snowball).
    boxes = [f.getbbox() or (0, 0, f.width, f.height) for f in raw]
    if st.get("trim") is False:
        # Each frame keeps its whole box (the Harpy's vortex: it grows from
        # one end of its frame toward the other, so its place in the frame
        # is the animation).
        boxes = [(0, 0, f.width, f.height) for f in raw]
    elif st.get("align") == "board":
        y0, y1 = min(b[1] for b in boxes), max(b[3] for b in boxes)
        boxes = [(b[0], y0, b[2], y1) for b in boxes]
    raw = [f.crop(b) for f, b in zip(raw, boxes)]
    width = raw[0].width
    if st.get("width_of") == "max":
        width = max(f.width for f in raw)   # `width_tiles` is the widest frame's
    if st.get("stretch"):
        # Every frame stretched across to the widest frame's width (the
        # Djinn's arc: its ends then sit at the same place in each frame,
        # however long the arc has grown), `width_tiles` that width.
        width = max(f.width for f in raw)
        raw = [f.convert("RGBa").resize((width, f.height), Image.LANCZOS).convert("RGBA") for f in raw]
    for root, kind, density, air in ((OUT % cfg["into"], "pixel", DENSITY, 0),
                                     (os.path.join(smooth_art.ROOT, "sheets", cfg["into"]), "smooth", smooth_art.SMOOTH_DENSITY, SMOOTH_GUTTER)):
        factor = width / float(st["width_tiles"] * density)
        if kind == "pixel":
            fs = [shrink(f, factor) for f in raw]
        elif st.get("trim") is False:
            fs = [smooth_art.resample(f, factor) for f in raw]   # each keeps its whole box
        else:
            fs = [smooth_art.trim(smooth_art.resample(f, factor)) for f in raw]
        cell = max(max(f.width, f.height) for f in fs) + 2 + air
        # One row, unless that runs past MAX_SHEET_PX: then rows of equal
        # length (the Harpy's 77-frame vortex is 7 rows of 11; KINDS names
        # the rows). A texture wider than many GPUs allow draws nothing.
        cols = len(fs)
        if cols * cell > MAX_SHEET_PX:
            nrows = next((r for r in range(2, len(fs) + 1) if len(fs) % r == 0 and len(fs) // r * cell <= MAX_SHEET_PX), None)
            assert nrows, "%s: %d frames do not split into equal rows under %d px" % (name, len(fs), MAX_SHEET_PX)
            cols = len(fs) // nrows
        grid = [fs[i:i + cols] for i in range(0, len(fs), cols)]
        if kind == "pixel":
            sheet = Image.new("RGBA", (cell * cols, cell * len(grid)))
            for r, row in enumerate(grid):
                for i, f in enumerate(row):
                    sheet.paste(f, (i * cell + (cell - f.width) // 2, r * cell + cell - air - f.height), f)
        else:
            sheet = smooth_art.pack(grid, cell, cols, lambda row, ci: row[ci], air=air)
        sheet.save(os.path.join(root, st["sheet"] + ".png"))
        print("%-13s %s: %d frames (%d row(s) of %d), %d-px cells into %s" % (name, kind, len(fs), len(grid), cols, cell, cfg["into"]))


def _pad_bottom(img: Image.Image, n: int) -> Image.Image:
    if n <= 0:
        return img
    out = Image.new("RGBA", (img.width, img.height + n))
    out.paste(img, (0, 0))
    return out


def _keep_ground(cfg: dict, still: dict, act_frames: dict, factor: float, trimmed: bool = False) -> None:
    """`keep_ground` actions (see cut_action_frames): every sheet gets the
    same room under the ground line, as deep as the lowest-reaching frame
    (a fire burst at the spider's feet), so frames reaching below it are
    not lifted onto it and the Idle's feet stay on the same line. Airborne
    frames were padded down to the line at full size; `trimmed` (the smooth
    look trims its frames) pads them again here, from what was cut away."""
    act = cfg.get("actions", {})
    drops = act.get("_drops")
    if not act.get("keep_ground") or not drops:
        return
    deepest = max(drops.values()) / factor
    for fs in still.values():
        for d in list(fs.keys()):
            fs[d] = _pad_bottom(fs[d], round(deepest))
    for d, fs in act_frames.items():
        for p in list(fs.keys()):
            below = drops.get((d, p), 0.0) / factor
            pad = deepest - below
            if trimmed:
                pad += act.get("_air", {}).get((d, p), 0.0) / factor
            fs[p] = _pad_bottom(fs[p], round(pad))


def build(name: str, cfg: dict) -> None:
    if "strip" in cfg:
        build_strip(name, cfg)
        return
    if "src" not in cfg:
        build_actions_on_sheets(name, cfg)
        if "into" not in cfg:
            # Sheets packed into its folder by other entries (the
            # Sabertooth's bite and claw beside its Track) are rebuilt with it.
            for other, ocfg in BOARDS.items():
                if ocfg.get("into") == name:
                    build(other, ocfg)
        return
    board = Image.open(SRC % cfg["src"])
    full = {}
    for anim in ("Idle", "Walk", "Sleep"):
        if anim not in cfg:
            continue
        full[anim] = {}
        for d, box in cfg[anim].items():
            if box[0] != "mirror":
                bg_kind = cfg["bg"]
                # Idle poses are named by direction; another animation's by
                # "Walk:left" (its own matte, its own hints).
                key = d if anim == "Idle" else "%s:%s" % (anim, d)
                if key in cfg.get("matte", ()):
                    bg_kind = "matte:" + os.path.join(MATTES, "%s_%s.png" % (cfg.get("matte_name", name), key.replace(":", "_")))
                fg_hints = cfg.get("matte_fg", {}).get(key, ()) if bg_kind.startswith("matte:") \
                    else cfg.get("fg", {}).get(key, ())
                bg_hints = cfg.get("matte_bg", {}).get(key, ()) if bg_kind.startswith("matte:") \
                    else cfg.get("bg_hint", {}).get(key, ())
                if bg_kind == "black_glow":
                    # A pose on a dark board (the three-head Hydra's views
                    # head her attack board: no board of her own): cut as
                    # the attack frames are, by brightness off the backdrop.
                    rgb = np.asarray(board.crop(box).convert("RGB")).astype(int)
                    full[anim][d] = _cut_black_glow(rgb, (), 0.0, 0.0, cfg.get("fill_holes", False),
                                                    cfg.get("levels"), False, cfg.get("open_dark", False))
                    continue
                full[anim][d] = cut(board, box, bg_kind, fg_hints,
                                    cfg.get("sat_grow", 0), cfg.get("snow", False),
                                    cfg.get("feet_trim", True), cfg.get("drop_ice", False),
                                    cfg.get("bright_grow", 0), cfg.get("sky_tol", 0),
                                    cfg.get("warm_grow", 0), cfg.get("drop_blue", False),
                                    cfg.get("dark_regrow", 0), bg_hints,
                                    cfg.get("warm_seed", False), cfg.get("violet_grow", {}).get(d, 0))
            if cfg.get("sharpen") and d in full[anim] and box[0] != "mirror":
                full[anim][d] = _sharpen(full[anim][d], cfg["sharpen"])
            if cfg.get("drop_shadow") and d in full[anim]:
                ds = cfg["drop_shadow"]
                band, lum_max = (ds if isinstance(ds, tuple) else (ds, 80))
                full[anim][d] = _drop_floor_shadow(full[anim][d], band, lum_max)
        for d, box in cfg[anim].items():
            if box[0] == "mirror":
                full[anim][d] = full[anim][box[1]].transpose(Image.FLIP_LEFT_RIGHT)
    for d, k in cfg.get("pose_scale", {}).items():
        # A pose the board draws smaller than the front (measured on the
        # figure, not its full height — a staff can top one pose and not
        # another): scaled up by k so the character doesn't shrink as it turns.
        for anim in full:
            f = full[anim][d]
            size = (max(1, round(f.width * k)), max(1, round(f.height * k)))
            g = f.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
            a = np.asarray(g).copy()
            a[..., 3] = np.where(a[..., 3] >= 128, 255, 0)
            full[anim][d] = Image.fromarray(a, "RGBA")
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
    # The action board's frames (the werewolf's slash), already at the Idle
    # side views' scale: they share the cells with Idle / Walk below.
    actions = cut_actions(name, cfg, full) if "actions" in cfg else {}
    factor = full["Idle"]["front"].height / float(round(cfg["tiles"] * DENSITY))
    small = {a: {d: shrink(f, factor) for d, f in fs.items()} for a, fs in full.items()}
    small_act = {d: {p: shrink(f, factor) for p, f in fs.items()} for d, fs in actions.items()}
    _keep_ground(cfg, small, small_act, factor)
    cell = max(max(f.width, f.height) for fs in list(small.values()) + list(small_act.values()) for f in fs.values()) + 2
    os.makedirs(OUT % name, exist_ok=True)
    for anim, fs in small.items():
        pack(fs, cell).save(os.path.join(OUT % name, anim + ".png"))
    for anim, poses in cfg.get("actions", {}).get("sheets", {}).items():
        pack_action(small_act, poses, cell, action_rows(cfg)).save(os.path.join(OUT % name, anim + ".png"))
    dims = ", ".join("%s %dx%d" % (d, f.width, f.height) for d, f in small["Idle"].items())
    print("%-13s ÷%.1f, %d-px cells: %s" % (name, factor, cell, dims))
    # The smooth version (smooth_art): the same cut-outs at SMOOTH_DENSITY
    # texels a tile, soft-filtered with soft alpha, kept beside the pixel one.
    sfac = full["Idle"]["front"].height / float(round(cfg["tiles"] * smooth_art.SMOOTH_DENSITY))
    soft = {a: {d: smooth_art.trim(smooth_art.resample(f, sfac)) for d, f in fs.items()} for a, fs in full.items()}
    soft_act = {d: {p: smooth_art.trim(smooth_art.resample(f, sfac)) for p, f in fs.items()} for d, fs in actions.items()}
    _keep_ground(cfg, soft, soft_act, sfac, trimmed=True)
    # SMOOTH_GUTTER empty rows under each pose: the smooth sheets are drawn
    # with mipmaps, and a pose standing on its cell's bottom edge bled into the
    # top of the row below (a faint mark over Olorin's hat, 2026-10-28). The
    # feet are found from the art, so the gutter doesn't lift the figure.
    scell = max(max(f.width, f.height) for fs in list(soft.values()) + list(soft_act.values()) for f in fs.values()) + 2 + SMOOTH_GUTTER
    sdir = os.path.join(smooth_art.ROOT, "sheets", name)
    os.makedirs(sdir, exist_ok=True)
    for anim, fs in soft.items():
        smooth_art.pack([[fs[d]] for d in ROWS], scell, 1, lambda row, ci: row[0], air=SMOOTH_GUTTER).save(os.path.join(sdir, anim + ".png"))
    for anim, poses in cfg.get("actions", {}).get("sheets", {}).items():
        rows = [[soft_act[d][p] for p in poses] for d in action_rows(cfg)]
        smooth_art.pack(rows, scell, len(poses), lambda row, ci: row[ci], air=SMOOTH_GUTTER).save(os.path.join(sdir, anim + ".png"))
    # Sheets packed into this kind's folder by another entry (the Hydra's
    # heal) are rebuilt with it, in its new cells.
    for other, ocfg in BOARDS.items():
        if ocfg.get("into") == name:
            build(other, ocfg)


def main() -> None:
    names = sys.argv[1:] or [k for k, c in BOARDS.items() if "into" not in c]   # an "into" entry is built with its kind
    for n in names:
        build(n, BOARDS[n])


if __name__ == "__main__":
    main()
