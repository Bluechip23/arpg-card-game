#!/usr/bin/env python3
"""Cut the designer's world-prop boards (bushes, trees, rocks... drawn on
black) into the prop sprites that replace the pack ones.

Each board lists its pieces in the order of the role's variants. A piece is
lifted off the black (the black reached from the crop's edge, and any big
enclosed pool of it — the board seen through a gap; smaller black the piece
encloses is its own deep shading and stays; the outer rim's alpha is
soft, from its brightness, so its blend into black does not become a dark
line), shrunk with a sharp (Lanczos)
filter on premultiplied colour to its height in texels, then given on/off
alpha like the heroes and the creature boards.

The props are cut at 64 texels a tile, twice the packs' 32 and the
fineness of the designer's creature boards (2026-10-24: err on the side of
under-pixelating what we make), so the role draws at scale 0.5 in
tools/build_craftpix_props.py (DESIGNER). A piece's height is the height
the pack variant it replaces had, doubled: the world keeps its sizes.

Output: assets/textures/props/boards/<role>_<i>.png
Run: python3 tools/cut_prop_boards.py [role ...]; then
     python3 tools/build_craftpix_props.py (the manifest).
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage as nd

SRC = "assets/sprites/paintings/%s"
OUT = "assets/textures/props/boards/%s_%d.png"
BLACK = 10      # brightness (max channel) at or below this is the board's black
RAMP = 40       # ...and alpha ramps to full over this many levels above it
SPECK = 40      # pieces of a cut-out smaller than this (source px) are dropped
HOLE = 1000     # enclosed black bigger than this (source px) is the board seen
                # through the piece (under the ruin ring's vine arch), not shading

# role -> board and pieces: (crop box (x0, y0, x1, y1) in source px, height
# in texels at 64 a tile). The boxes come from the board's own layout.
BOARDS = {
    # 2026-10-29: the designer's seven forest bushes (forest_bushes_board.webp,
    # two rows on black), each in the place of the pack bush it most
    # resembles; heights are the pack bushes' (34, 27, 28, 31, 22, 38, 32
    # texels at 32 a tile), doubled.
    "forest_bush": {
        "src": "forest_bushes_board.webp",
        "pieces": [
            ((526, 552, 995, 924), 68),     # the fan of long leaves (was the pack's star-leaf bush)
            ((1051, 552, 1450, 928), 54),   # bottom right
            ((27, 153, 357, 468), 56),      # top left
            ((375, 101, 780, 474), 62),     # the wide dome
            ((796, 218, 1121, 468), 44),    # the smallest
            ((1134, 107, 1518, 478), 76),   # the biggest
            ((68, 523, 442, 921), 64),      # the tall one, bottom left
        ],
    },
    # 2026-10-29: the designer's Greenwood trees (forest_trees_board.webp, 18
    # trees on black in three rows: conifers and a great oak; broadleaf trees,
    # two on pale roots; small round trees). Each takes the place of the pack
    # tree it most resembles at its height (doubled); the small round trees
    # past the eighth are new variants, sized as drawn beside the first.
    "forest_tree": {
        "src": "forest_trees_board.webp",
        "pieces": [
            ((1300, 507, 1512, 748), 84),   # broadleaf on pale roots, the smaller
            ((8, 8, 288, 423), 124),        # the big conifer
            ((304, 28, 541, 417), 118),     # the tall conifer
            ((311, 429, 515, 753), 128),    # the tall broadleaf
            ((554, 157, 726, 414), 78),     # the small conifer
            ((517, 526, 710, 759), 94),     # the small broadleaf
            ((720, 460, 988, 764), 124),    # the wide broadleaf
            ((48, 828, 200, 993), 74),      # small round trees, the smallest first
            ((244, 769, 475, 995), 101),
            ((511, 822, 657, 983), 72),
            ((693, 772, 948, 1000), 102),
            ((968, 769, 1252, 997), 102),
            ((1271, 772, 1511, 997), 101),
        ],
    },
    "forest_tree_big": {
        "src": "forest_trees_board.webp",
        "pieces": [
            ((740, 97, 934, 416), 148),     # the yellow-green conifer
            ((951, 64, 1127, 412), 156),    # the columnar broadleaf
            ((20, 442, 300, 766), 156),     # the round broadleaf
            ((1003, 418, 1296, 758), 150),  # broadleaf on pale roots, the bigger
        ],
    },
    # The climbable / landmark tree: the great oak.
    "forest_tree_climb": {
        "src": "forest_trees_board.webp",
        "pieces": [((1145, 23, 1527, 423), 154)],
    },
    # 2026-10-29: the fallen log, the stump and three ferns
    # (forest_logs_ferns_board.webp, on black).
    "forest_log": {
        "src": "forest_logs_ferns_board.webp",
        "pieces": [
            ((35, 59, 967, 459), 74),       # the fallen, splintered log
            ((1029, 144, 1479, 465), 44),   # the stump (the pack's log set had a small one)
        ],
    },
    "forest_stump": {
        "src": "forest_logs_ferns_board.webp",
        "pieces": [((1029, 144, 1479, 465), 56)],
        # 2026-10-29: a second stump and a snapped trunk, from the ruins
        # board (as the pack's stump set had both), the trunk as tall
        # beside the stump as drawn.
        "more": [
            ("forest_ruins_shrooms_board.webp", (49, 302, 296, 501), 56),
            ("forest_ruins_shrooms_board.webp", (348, 248, 569, 502), 71),
        ],
    },
    # 2026-10-29: the designer's mushrooms and ruins
    # (forest_ruins_shrooms_board.webp, on black: brown and red toadstool
    # clumps; a ring of ruined walls, broken walls among trees, a pillar on
    # its steps, a broken pillar, and a small stone ruin). Each in the place
    # of the pack piece it redraws, at its height (doubled).
    "forest_shroom": {
        "src": "forest_ruins_shrooms_board.webp",
        "pieces": [
            ((333, 51, 509, 230), 52),      # brown, three
            ((576, 67, 776, 216), 42),      # brown, two
            ((854, 49, 1068, 250), 50),     # red, three
            ((1141, 49, 1289, 251), 50),    # red, two
            ((1358, 84, 1486, 242), 38),    # red, one
        ],
    },
    "forest_ruin": {
        "src": "forest_ruins_shrooms_board.webp",
        "pieces": [
            ((21, 518, 500, 982), 216),     # the ring of ruined walls
            ((544, 579, 874, 972), 148),    # broken walls among trees
            ((906, 560, 1210, 975), 130),   # the pillar on its steps
            ((1255, 581, 1502, 945), 96),   # the broken pillar
            ((53, 44, 262, 245), 64),       # the small stone ruin
        ],
    },
    # 2026-10-29: the designer's forest rocks (forest_rocks_board.webp, 12 on
    # black in three rows: rock clusters; cracked stone pillars, big to
    # small, and a low block; mossy clusters). Each of the first eight takes
    # the place of the pack rock it most resembles at its height (doubled);
    # the other four are new variants, sized like the clusters beside them.
    "forest_rock": {
        "src": "forest_rocks_board.webp",
        "pieces": [
            ((32, 343, 405, 662), 126),     # the big pillar
            ((471, 411, 756, 663), 94),     # the middle pillar
            ((872, 441, 1105, 655), 68),    # the small pillar
            ((27, 686, 403, 972), 70),      # mossy cluster, left
            ((1230, 741, 1486, 947), 58),   # mossy cluster, small
            ((440, 113, 792, 327), 56),     # the wide cluster
            ((842, 96, 1213, 337), 64),     # the slab cluster
            ((1271, 113, 1486, 288), 40),   # the lone pointed stone
            ((51, 77, 384, 319), 65),       # new: the tall pointed cluster
            ((1218, 473, 1489, 647), 47),   # new: the low block
            ((438, 701, 792, 963), 71),     # new: mossy cluster, middle
            ((828, 702, 1175, 972), 73),    # new: mossy cluster, right
        ],
    },
    # 2026-10-29: the designer's cave rocks and crystals
    # (cave_rocks_crystals_board.webp, on black: orange, blue, green, red and
    # yellow crystal clusters, three sizes each; four tall rock columns).
    # The crystals take the places of the pack's five colours x three sizes
    # at their heights (doubled); the columns are the stalagmites (the
    # pack's grey spikes), sized as drawn beside the crystals.
    "cave_crystal": {
        "src": "cave_rocks_crystals_board.webp",
        "pieces": [
            ((37, 387, 320, 650), 94), ((351, 460, 546, 646), 66), ((580, 503, 736, 636), 50),       # blue
            ((799, 399, 1062, 652), 84), ((1089, 456, 1307, 653), 66), ((1336, 505, 1499, 645), 40), # green
            ((36, 674, 324, 984), 102), ((359, 743, 552, 965), 76), ((583, 799, 739, 963), 50),      # red
            ((808, 671, 1077, 986), 118), ((1130, 742, 1332, 978), 82), ((1365, 797, 1508, 948), 62),# yellow
            ((33, 52, 318, 342), 100), ((340, 126, 553, 342), 82), ((573, 189, 726, 340), 56),       # orange
        ],
    },
    # 2026-10-29: the designer's stalagmites, mushrooms and webs
    # (cave_spikes_shrooms_webs_board.webp, on black: eight grey-green spikes,
    # five dark ringed spikes; five corner webs; pale, blue, spiral-capped and
    # dripping ember-capped mushrooms). The spikes take the places of the
    # pack's five grey and three black stalagmites, the rest are new; all at
    # one scale, as drawn relative to each other. The tall rock columns from
    # the crystals board stand among them.
    "cave_stalagmite": {
        "src": "cave_spikes_shrooms_webs_board.webp",
        "pieces": [
            ((34, 5, 235, 262), 108),       # grey, tall and short
            ((487, 64, 606, 260), 82),      # grey, single
            ((267, 19, 435, 260), 101),     # grey cluster
            ((670, 113, 814, 260), 62),     # grey pair
            ((1265, 120, 1358, 260), 59),   # grey, small
            ((34, 262, 235, 453), 80),      # dark pair
            ((495, 277, 608, 452), 74),     # dark single
            ((869, 313, 965, 452), 58),     # dark, small
            ((883, 113, 1014, 260), 62),    # new: grey pair
            ((1077, 63, 1233, 260), 83),    # new: grey, tall and short
            ((1407, 171, 1489, 260), 37),   # new: grey, smallest
            ((296, 268, 439, 451), 77),     # new: dark pair
            ((666, 297, 785, 452), 65),     # new: dark pair
        ],
        "more": [
            ("cave_rocks_crystals_board.webp", (808, 18, 967, 358), 100),    # the rock columns
            ("cave_rocks_crystals_board.webp", (1013, 18, 1149, 360), 92),
            ("cave_rocks_crystals_board.webp", (1191, 28, 1325, 359), 108),
            ("cave_rocks_crystals_board.webp", (1378, 27, 1511, 359), 84),
        ],
    },
    # The stalactites: the grey spikes hanging point-down from the dark.
    "cave_stalactite": {
        "src": "cave_spikes_shrooms_webs_board.webp",
        "flip": True,
        "pieces": [
            ((34, 5, 235, 262), 108), ((487, 64, 606, 260), 82), ((267, 19, 435, 260), 101),
            ((670, 113, 814, 260), 62), ((1265, 120, 1358, 260), 59), ((883, 113, 1014, 260), 62),
            ((1077, 63, 1233, 260), 83), ((1407, 171, 1489, 260), 37),
        ],
    },
    "cave_shroom": {
        "src": "cave_spikes_shrooms_webs_board.webp",
        "pieces": [
            ((58, 648, 209, 809), 48),      # pale clump
            ((385, 710, 462, 796), 36),     # pale, small
            ((610, 636, 781, 809), 64),     # blue clump
            ((833, 685, 941, 815), 52),     # blue pair
            ((1093, 642, 1266, 820), 86),   # spiral caps, two
            ((1291, 668, 1431, 818), 64),   # spiral caps, the smaller two
            ((111, 811, 397, 1010), 98),    # ember caps, the big pair
            ((691, 861, 810, 1000), 60),    # ember cap, single
            ((247, 686, 348, 799), 40),     # new: pale, middle
            ((974, 720, 1031, 806), 34),    # new: blue, tiny
            ((457, 840, 615, 1003), 80),    # new: ember caps, pair
            ((962, 880, 1091, 1003), 60),   # new: ember caps
            ((1184, 857, 1309, 1003), 70),
            ((1359, 905, 1446, 1003), 48),
        ],
    },
    # The webs: drawn as thin strands, so a low alpha cut keeps them through
    # the shrink. (DungeonManager sizes a web to a tile across.)
    "cave_web": {
        "src": "cave_spikes_shrooms_webs_board.webp",
        "alpha_cut": 40,
        "open_black": True,
        "pieces": [
            ((40, 464, 375, 630), 45),
            ((439, 464, 696, 663), 70),
            ((744, 463, 1007, 647), 63),
            ((1131, 464, 1319, 625), 77),
            ((1324, 464, 1499, 666), 104),
        ],
    },
    # 2026-10-29: the designer's cave rocks and pebbles
    # (cave_rocks_pebbles_board.webp, on black: brown rock chunks, two
    # drip-stained; blue and green stones). The chunks take the places of the
    # pack's rock chunks (nine for its ten), the stones of its pebbles, each
    # at the height of the piece it redraws (doubled).
    "cave_rock": {
        "src": "cave_rocks_pebbles_board.webp",
        "pieces": [
            ((645, 718, 881, 962), 60),     # drip-stained
            ((68, 744, 292, 931), 48),
            ((968, 718, 1179, 976), 60),    # drip-stained
            ((1238, 756, 1481, 943), 48),
            ((798, 138, 1052, 336), 50),    # the low slab
            ((81, 42, 322, 343), 64),       # stacked, tall
            ((447, 42, 696, 336), 64),      # stacked, tall
            ((368, 784, 591, 927), 36),     # the smallest
            ((1175, 113, 1464, 330), 50),   # the cluster
        ],
    },
    "cave_pebble": {
        "src": "cave_rocks_pebbles_board.webp",
        "pieces": [
            ((74, 393, 314, 660), 56),      # blue, pointed
            ((440, 425, 635, 649), 30),     # blue pair
            ((816, 481, 1057, 643), 28),    # blue boulder
            ((1175, 421, 1430, 665), 26),   # green
            ((368, 784, 591, 927), 36),     # a brown chunk (the pack's was one of its rock chunks too)
        ],
    },
    # 2026-10-29: the designer's town stalls (town_stalls_board.webp, on
    # black: two coin sacks; the smith's workbench with its anvil; the
    # armorer's bench with fabric, shears and a fitting dummy; three goods
    # shelves; a shelf of cards; the card table; two card players at their
    # table). All at one scale, as drawn relative to each other (0.27 a
    # board px, ~2.2 tiles for the card table), the sacks a little smaller.
    "goods_sack": {
        "src": "town_stalls_board.webp",
        "pieces": [((43, 29, 279, 243), 48), ((1263, 24, 1499, 243), 48)],
    },
    "town_bench": {
        "src": "town_stalls_board.webp",
        "pieces": [
            ((322, 12, 720, 242), 62),      # the smith's workbench
            ((778, 25, 1206, 255), 62),     # the armorer's bench
        ],
    },
    "town_shelf": {
        "src": "town_stalls_board.webp",
        "pieces": [
            ((48, 267, 472, 615), 94),      # swords, armour, helm, gauntlets
            ((532, 266, 976, 615), 94),     # spear, shield, hammer, boots, belt, cloak
            ((1060, 267, 1511, 615), 94),   # wand, tome, cloaks, rings, trident, arrows
        ],
    },
    "town_card_shelf": {
        "src": "town_stalls_board.webp",
        "pieces": [((31, 620, 453, 977), 96)],
    },
    "town_card_table": {
        "src": "town_stalls_board.webp",
        "pieces": [((473, 632, 1013, 978), 93)],
    },
    "town_card_players": {
        "src": "town_stalls_board.webp",
        "pieces": [((1047, 656, 1507, 985), 89)],
    },
    # 2026-10-29: the designer's stash, a vault door set into the plaza
    # (stash_vault_board.webp): laid flat on the ground by town.gd, 2.4
    # tiles across.
    # 2026-10-29: the designer's forge (blacksmith_forge_board.webp, on
    # black): the forge, the bellows, the anvil on its stump, the rack of
    # tongs and weapon molds, a workbench, a box of coal, a water bucket, a
    # coal bucket, a stool, a sword rack, a log pile and a grindstone. Sized
    # to the smith (about 2.3 tiles tall), 64 texels a tile.
    "smith_forge": {"src": "blacksmith_forge_board.webp", "own_alpha": 230, "main_only": True, "pieces": [((15, 0, 548, 502), 140)]},
    "smith_bellows": {"src": "blacksmith_forge_board.webp", "own_alpha": 230, "main_only": True, "pieces": [((511, 88, 1016, 467), 62)]},
    "smith_anvil": {"src": "blacksmith_forge_board.webp", "own_alpha": 230, "pieces": [((1022, 80, 1512, 504), 54)]},
    "smith_molds": {"src": "blacksmith_forge_board.webp", "own_alpha": 230, "main_only": True, "pieces": [((25, 505, 770, 735), 58)]},
    "smith_table": {"src": "blacksmith_forge_board.webp", "own_alpha": 230, "pieces": [((785, 520, 1272, 728), 52)]},
    "smith_coal_box": {"src": "blacksmith_forge_board.webp", "own_alpha": 230, "pieces": [((1276, 505, 1508, 722), 42)]},
    "smith_water": {"src": "blacksmith_forge_board.webp", "own_alpha": 230, "pieces": [((20, 740, 262, 992), 44)]},
    "smith_coal_bucket": {"src": "blacksmith_forge_board.webp", "own_alpha": 230, "pieces": [((330, 780, 502, 972), 32)]},
    "smith_stool": {"src": "blacksmith_forge_board.webp", "own_alpha": 230, "pieces": [((524, 788, 716, 988), 34)]},
    "smith_sword_rack": {"src": "blacksmith_forge_board.webp", "own_alpha": 230, "pieces": [((730, 735, 964, 994), 52)]},
    "smith_logs": {"src": "blacksmith_forge_board.webp", "own_alpha": 230, "pieces": [((990, 740, 1252, 988), 48)]},
    "smith_grindstone": {"src": "blacksmith_forge_board.webp", "own_alpha": 230, "pieces": [((1254, 724, 1532, 994), 54)]},
    "town_stash_vault": {
        "src": "stash_vault_board.webp",
        "pieces": [((196, 45, 1339, 985), 126)],
    },
    "forest_fern": {
        "src": "forest_logs_ferns_board.webp",
        "pieces": [
            ((33, 628, 448, 930), 28),      # the low fern, left
            ((1078, 533, 1496, 931), 32),   # the upright fern, right
            ((496, 503, 1024, 925), 74),    # the great fern, middle
        ],
    },
}


def turn45(img, squeeze=0.72, drop=0.45):
    """A long piece turned 45 degrees on the ground, as far as a flat drawing
    can be: narrowed (its length now runs into the depth) and sheared so
    its right end comes forward (lower on screen) - nearest-neighbour, so
    the texels stay crisp. No pack or board draws it turned."""
    w, h = img.size
    W = max(1, round(w * squeeze))
    H = h + round(W * drop)
    # inverse map: source x = X / squeeze, source y = Y - X * drop
    return img.transform((W, H), Image.AFFINE, (1.0 / squeeze, 0, 0, -drop, 1, 0), resample=Image.NEAREST)


def cut_piece(board, box, height, alpha_cut=128, flip=False, open_black=False, main_only=False,
              rim_floor=1e-3, own_alpha=0):
    rgb = np.asarray(board.crop(box).convert("RGB")).astype(np.float32)
    if own_alpha:
        # A board that comes cut out (its own transparency, a soft painted
        # halo round each piece): the piece is where its alpha is at least
        # own_alpha; the halo and the black are both board.
        a = np.asarray(board.crop(box).convert("RGBA"))[..., 3]
        solid = a >= own_alpha
        lab, n = nd.label(solid)
        if n:
            sizes = nd.sum(solid, lab, range(1, n + 1))
            solid = (lab == 1 + int(np.argmax(sizes))) if main_only else np.isin(lab, 1 + np.nonzero(sizes >= SPECK)[0])
        ys, xs = np.nonzero(solid)
        rgb = rgb[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        solid = solid[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        img = Image.fromarray(np.dstack([rgb, solid * 255.0]).astype(np.uint8), "RGBA")
        k = height / float(img.height)
        size = (max(1, round(img.width * k)), height)
        small = np.asarray(img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")).copy()
        small[..., 3] = np.where(small[..., 3] >= alpha_cut, 255, 0)
        small[small[..., 3] == 0, :3] = 0
        out = Image.fromarray(small, "RGBA")
        return out.transpose(Image.FLIP_TOP_BOTTOM) if flip else out
    bright = rgb.max(axis=2)
    # The background is the black reached from the crop's edge; black
    # enclosed by the piece is its own deep shading (the designer shades
    # foliage nearly to black) and stays.
    black = bright <= BLACK
    lab, n = nd.label(black)
    edge_labels = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    sizes = nd.sum(black, lab, range(1, n + 1)) if n else []
    see_through = {i + 1 for i, sz in enumerate(sizes) if sz > HOLE}
    solid = ~np.isin(lab, list(edge_labels | see_through))
    if open_black:
        solid &= ~black   # a piece with no dark paint of its own (the webs): every black is the board
    lab, n = nd.label(solid)
    if n:
        sizes = nd.sum(solid, lab, range(1, n + 1))
        solid = np.isin(lab, 1 + np.nonzero(sizes >= SPECK)[0])
        if main_only:   # only the piece itself: a neighbour reaching into its box goes
            solid = lab == 1 + int(np.argmax(sizes))
    # The outermost rim is blended into the black: soft there (RAMP), so
    # the shrink does not draw a dark line round the piece.
    rim = solid & ~nd.binary_erosion(solid, iterations=2)
    alpha = np.where(rim, np.clip((bright - BLACK) / RAMP, 0.0, 1.0), solid.astype(np.float32))
    ys, xs = np.nonzero(solid)
    rgb = rgb[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    alpha = alpha[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    # Colour stays as painted inside; the rim's blend with black is taken
    # back out (unpremultiply) where its alpha is soft.
    # (rim_floor > 0: a board whose blacks carry a colour cast would turn
    # that cast into a coloured fringe when brightened all the way.)
    col = np.clip(rgb / np.maximum(alpha, rim_floor)[..., None], 0, 255)
    img = Image.fromarray(np.dstack([col, alpha * 255]).astype(np.uint8), "RGBA")
    k = height / float(img.height)
    size = (max(1, round(img.width * k)), height)
    small = np.asarray(img.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")).copy()
    small[..., 3] = np.where(small[..., 3] >= alpha_cut, 255, 0)
    small[small[..., 3] == 0, :3] = 0
    out = Image.fromarray(small, "RGBA")
    return out.transpose(Image.FLIP_TOP_BOTTOM) if flip else out


def build(role, cfg):
    board = Image.open(SRC % cfg["src"])
    os.makedirs(os.path.dirname(OUT % (role, 0)), exist_ok=True)
    # "more": pieces from other boards, (board, box, height), after the rest.
    pieces = [(board, box, h) for box, h in cfg["pieces"]] + \
             [(Image.open(SRC % src), box, h) for src, box, h in cfg.get("more", [])]
    for i, (b, box, height) in enumerate(pieces):
        img = cut_piece(b, box, height, cfg.get("alpha_cut", 128), cfg.get("flip", False),
                        cfg.get("open_black", False), cfg.get("main_only", False),
                        cfg.get("rim_floor", 1e-3), cfg.get("own_alpha", 0))
        if cfg.get("turn45"):
            img = turn45(img)
        img.save(OUT % (role, i))
        print("%s_%d: %dx%d" % (role, i, img.width, img.height))


def main():
    for role in sys.argv[1:] or list(BOARDS):
        build(role, BOARDS[role])


if __name__ == "__main__":
    main()
