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
pose), another pose of that facing again.

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
                    fill_holes: bool = False, levels=None) -> Image.Image:
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
    figure and not inside the body) goes too."""
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
            if hst[i, cv2.CC_STAT_AREA] > HOLE_FILL_MAX:
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
            keep[i] = r > 1.4 * max(g, b) + 8   # a red slash arc
        alpha[~keep[lab]] = 0.0
    if shadow_band > 0:
        ys = np.nonzero((alpha > 0).any(axis=1))[0]
        y0 = int(ys.max() + 1 - (ys.max() + 1 - ys.min()) * shadow_band)
        shadow = soft & (sat < 20) & (lum < solid_at)
        shadow[:y0] = False
        alpha[shadow] = 0.0
    a = np.maximum(alpha, 1e-6)[..., None]
    col = np.clip(rgb / a, 0, 255)
    col = np.where(alpha[..., None] > 0, col, 0)
    rgba = np.dstack([col, alpha * 255.0]).round().astype(np.uint8)
    ys, xs = np.nonzero(rgba[..., 3] > 0)
    return Image.fromarray(rgba[ys.min():ys.max() + 1, xs.min():xs.max() + 1], "RGBA")


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


def cut_action_frames(cfg: dict) -> dict:
    """The frames of a creature's action boards, full size, uncut to scale:
    {direction: {pose: image}}. A pose is a box on the facing's board,
    ("mirror", box) for the box flipped, or ("same", pose) for another
    pose of the facing again."""
    act = cfg["actions"]
    boards = {}

    def board(d: str) -> Image.Image:
        name = act["src"][d] if isinstance(act["src"], dict) else act["src"]
        if name not in boards:
            boards[name] = Image.open(SRC % name)
        return boards[name]

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
            rgb = np.asarray(board(d).crop(box).convert("RGB")).astype(int)
            img = _cut_black_glow(rgb, act.get("bg_boxes", {}).get((d, pose), ()), act.get("shadow_band", 0.0),
                                  act.get("keep_share", 0.0), act.get("fill_holes", False), act.get("levels"))
            out[d][pose] = img.transpose(Image.FLIP_LEFT_RIGHT) if mirror else img
        for pose, other in again:
            out[d][pose] = out[d][other]
    return out


def _action_setting(cfg: dict, key: str, default, d: str):
    v = cfg["actions"].get(key, default)
    return v.get(d, default) if isinstance(v, dict) else v


def _used_poses(cfg: dict) -> set:
    return {p for poses in cfg["actions"]["sheets"].values() for p in poses}


def cut_actions(cfg: dict, full: dict) -> dict:
    """The action frames, full size, each facing's scaled so its `match`
    pose stands as tall as that facing's Idle pose (full size too)."""
    out = cut_action_frames(cfg)
    for d, fs in out.items():
        k = full["Idle"][d].height / float(fs[_action_setting(cfg, "match", "recover", d)].height) * _action_setting(cfg, "match_scale", 1.0, d)
        for pose, f in fs.items():
            size = (max(1, round(f.width * k)), max(1, round(f.height * k)))
            fs[pose] = f.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")
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
    raw = cut_action_frames(cfg)
    used = _used_poses(cfg)
    rows = action_rows(cfg)
    frames = {}
    for root, kind in ((OUT % name, "pixel"), (os.path.join(smooth_art.ROOT, "sheets", name), "smooth")):
        idle = Image.open(os.path.join(root, "Idle.png"))
        cell = idle.height // 4
        info = dict(zip(ROWS, _sheet_rows(idle, cell)))
        frames = {}
        for d, fs in raw.items():
            k = info[d][0] / float(fs[_action_setting(cfg, "match", "recover", d)].height) * _action_setting(cfg, "match_scale", 1.0, d)
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
            for anim in ("Idle", "Walk", "Sleep"):
                path = os.path.join(root, anim + ".png")
                if os.path.exists(path):
                    _regrow(Image.open(path), cell, need).save(path)
            print("%-13s %s cells %d -> %d px (Idle / Walk regrown)" % (name, kind, cell, need))
            cell = need
        for anim, poses in cfg["actions"]["sheets"].items():
            if kind == "pixel":
                pack_action(frames, poses, cell, rows, air).save(os.path.join(root, anim + ".png"))
            else:
                smooth_art.pack([[frames[d][p] for p in poses] for d in rows], cell, len(poses), lambda row, ci: row[ci], air=air).save(os.path.join(root, anim + ".png"))
    dims = ", ".join("%s %dx%d" % (d, f.width, f.height) for d, f in frames[rows[0]].items())
    print("%-13s on its own sheets: %s" % (name, dims))


def build(name: str, cfg: dict) -> None:
    if "src" not in cfg:
        build_actions_on_sheets(name, cfg)
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
    actions = cut_actions(cfg, full) if "actions" in cfg else {}
    factor = full["Idle"]["front"].height / float(round(cfg["tiles"] * DENSITY))
    small = {a: {d: shrink(f, factor) for d, f in fs.items()} for a, fs in full.items()}
    small_act = {d: {p: shrink(f, factor) for p, f in fs.items()} for d, fs in actions.items()}
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


def main() -> None:
    names = sys.argv[1:] or list(BOARDS)
    for n in names:
        build(n, BOARDS[n])


if __name__ == "__main__":
    main()
