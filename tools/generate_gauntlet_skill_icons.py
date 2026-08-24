#!/usr/bin/env python3
"""Gauntlet skill icons: one 32x32 sprite per ACTIVE gauntlet skill, drawn
from the skill's icon description in the gauntlets design sheet.

Output: assets/items/gauntlet_skills/<effect_id>.png — shown inside the
circular skill button (GauntletSkillUI) instead of the skill's letter.

Reuses the mythic icon toolkit (Canvas, material ramps, mechanical lighting)
so the skill icons share the house style: master-palette colors, upper-left
key light, colored outlines.

Usage: python3 tools/generate_gauntlet_skill_icons.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from generate_mythic_icons import (  # noqa: E402
    Canvas, render, _stroke, _taper, _crescent, _d20, _mask, _rect_mask,
)

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "items", "gauntlet_skills")


def three_count():
    ## "A pair of black boxing mits with laces." (Mits of Chingiz — passive.)
    c = Canvas()
    # Two mitts side by side, angled inward, cuffs at the bottom.
    for (cx, tilt) in ((10, -1), (22, 1)):
        c.ellipse((cx - 6, 4, cx + 6, 20), "dark")
        c.ellipse((cx - 6 + tilt * 2, 3, cx + 2 + tilt * 4, 12), "dark", "hi")
        c.rect((cx - 4, 19, cx + 4, 27), "blood")
        # The laces: white cross-stitching down the inner face.
        for ly in (8, 12, 16):
            c.line([(cx - 2, ly), (cx + 2, ly + 3)], "bone", "hi")
            c.line([(cx + 2, ly), (cx - 2, ly + 3)], "bone", "hi")
    return c


def chain_guard():
    ## "A small breast plate."
    c = Canvas()
    c.poly([(6, 5), (26, 5), (25, 15), (22, 24), (16, 28), (10, 24), (7, 15)], "steel")
    # Collar scoop and the center ridge catching the light.
    _crescent(c, (11, 2, 21, 9), 0, "dark", "sh")
    c.line([(16, 8), (16, 26)], "steel", "hi")
    # Rivets along the shoulder line.
    for x in (9, 16, 23):
        c.dot(x, 7, "gold", "hi")
    return c


def band_aid():
    ## "A band aid with a green + on it."
    c = Canvas()
    # The strip runs diagonally with rounded ends; pad in the middle.
    _stroke(c, [(6, 24), (26, 8)], "leather", r_end=5.5)
    c.ellipse((11, 10, 21, 20), "bone")
    # The green cross on the pad.
    c.rect((15, 11, 17, 19), "leaf")
    c.rect((12, 14, 20, 16), "leaf")
    return c


def future_is_bright():
    ## "Sun rising over grass."
    c = Canvas()
    # Rays fan up from the horizon sun.
    for a_deg in (-160, -135, -110, -90, -70, -45, -20):
        a = math.radians(a_deg)
        c.line([(16, 20), (16 + math.cos(a) * 13, 20 + math.sin(a) * 13)], "gold", "hi")
    c.ellipse((9, 13, 23, 27), "gold")
    # The grass line the sun rises over.
    c.rect((2, 21, 29, 25), "leaf")
    for x in (4, 8, 12, 16, 20, 24, 28):
        c.line([(x, 21), (x - 1, 18)], "leaf", "hi")
    c.rect((2, 26, 29, 29), "leaf", "sh")
    return c


def coming_in():
    ## "Hands tilted down, shooting web out."
    c = Canvas()
    # Web lines spraying down first, so the hand reads on top of them.
    for tx in (4, 10, 16, 22, 28):
        c.line([(16, 12), (tx, 29)], "bone", "hi")
    c.line([(9, 22), (23, 22)], "bone", "hi")
    c.line([(11, 26), (21, 26)], "bone", "hi")
    # The tilted red glove, fingers angled downward.
    c.poly([(9, 3), (23, 3), (24, 10), (20, 14), (12, 14), (8, 10)], "blood")
    for fx in (11, 15, 19):
        _taper(c, (fx, 13), (fx + 1, 17), 1.6, 1.0, "blood")
    return c


def suck():
    ## "A black hole / vortex."
    c = Canvas()
    c.ellipse((3, 3, 28, 28), "dark")
    # Spiral arms winding into the hole.
    for k in range(3):
        pts = []
        for i in range(20):
            t = i / 19.0
            a = math.tau * k / 3.0 + t * 3.6
            r = 12.5 - t * 10.0
            pts.append((16 + math.cos(a) * r, 16 + math.sin(a) * r))
        c.line(pts, "spark", "hi" if k == 0 else None)
    c.ellipse((12, 12, 20, 20), "dark", "sh")
    c.ellipse((14, 14, 18, 18), "dark", "core")
    return c


def well_placed_guard():
    ## "Gauntlets with spikes."
    c = Canvas()
    # Spikes first so the fist plates overlap their bases.
    for (sx, sy, ex, ey) in ((8, 9, 4, 3), (14, 7, 13, 1), (20, 8, 24, 2), (25, 13, 30, 9)):
        c.poly([(sx - 2, sy + 1), (sx + 2, sy + 1), (ex, ey)], "steel", "hi")
    # The clenched gauntlet: cuff, back plate, knuckle row.
    c.rect((8, 20, 24, 28), "iron")
    c.ellipse((6, 8, 26, 24), "steel")
    for kx in (9, 14, 19):
        c.rect((kx, 10, kx + 3, 14), "steel", "hi")
    return c


def continue_to_move():
    ## "Mittens with lightning bolts on them."
    c = Canvas()
    # The mitten: rounded body, thumb, knit cuff.
    c.ellipse((7, 4, 25, 22), "cloth")
    c.ellipse((3, 12, 11, 20), "cloth")
    c.rect((10, 21, 24, 28), "leather")
    c.line([(12, 22), (12, 27)], "leather", "sh")
    c.line([(17, 22), (17, 27)], "leather", "sh")
    c.line([(22, 22), (22, 27)], "leather", "sh")
    # The bolt stitched across the back.
    c.poly([(18, 5), (13, 13), (16, 13), (12, 20), (20, 11), (17, 11), (21, 5)], "gold", "hi")
    return c


def defense_one():
    ## "An uppercut with a blade riding up." Simplified to icon scale: the
    ## katar blade punching upward out of a clenched fist.
    c = Canvas()
    c.poly([(16, 1), (20, 9), (18, 17), (14, 17), (12, 9)], "steel")
    c.line([(16, 3), (16, 16)], "steel", "hi")
    # Cross-guard and the fist driving it.
    c.rect((9, 16, 23, 19), "gold")
    c.ellipse((9, 18, 23, 30), "leather")
    for kx in (11, 15, 19):
        c.rect((kx, 19, kx + 2, 22), "leather", "hi")
    return c


def house_rule():
    ## "A gaming table with cards and dice on it."
    c = Canvas()
    # The felt tabletop seen at an angle, wooden rail below.
    c.poly([(4, 8), (28, 8), (30, 22), (2, 22)], "leaf")
    c.rect((2, 22, 30, 26), "wood")
    # Two cards fanned on the felt...
    c.poly([(7, 11), (13, 10), (14, 19), (8, 20)], "bone")
    c.poly([(12, 12), (18, 11), (19, 20), (13, 21)], "bone", "hi")
    # ...and the d20 beside them.
    _d20(c, 23, 16, 4.5, "rose")
    return c


def imbue_tree():
    ## "A glowing tree with thorny vines."
    c = Canvas()
    # Canopy glowing green, trunk below.
    c.ellipse((6, 2, 26, 18), "leaf")
    c.ellipse((10, 4, 22, 12), "leaf", "hi")
    _taper(c, (16, 14), (16, 28), 2.6, 1.6, "wood")
    _taper(c, (15, 18), (9, 24), 1.6, 0.8, "wood")
    _taper(c, (17, 18), (23, 24), 1.6, 0.8, "wood")
    # The thorned vine winding across the trunk.
    c.line([(6, 27), (12, 24), (18, 26), (24, 22), (28, 24)], "teal")
    for (tx, ty) in ((9, 25), (15, 24), (21, 23), (26, 22)):
        c.poly([(tx - 1, ty + 1), (tx + 1, ty + 1), (tx, ty - 2)], "teal", "hi")
    return c


def zeet():
    ## "Someone getting struck by lightning."
    c = Canvas()
    # The bolt forking down from the top edge...
    c.poly([(14, 0), (20, 0), (16, 8), (19, 8), (13, 17), (15, 10), (12, 10)], "spark", "hi")
    # ...into a stick figure knocked back by the hit.
    c.ellipse((13, 16, 19, 22), "cloth")
    _stroke(c, [(16, 22), (17, 27)], "cloth", r_end=1.4)
    _stroke(c, [(16, 23), (11, 21)], "cloth", r_end=1.1)
    _stroke(c, [(16, 23), (21, 20)], "cloth", r_end=1.1)
    _stroke(c, [(17, 27), (13, 30)], "cloth", r_end=1.1)
    _stroke(c, [(17, 27), (22, 30)], "cloth", r_end=1.1)
    # Shock sparks off the shoulders.
    c.dot(10, 17, "spark", "hi")
    c.dot(23, 16, "spark", "hi")
    c.dot(20, 25, "spark", "hi")
    return c


def lethal_poke():
    ## "A hand poking a fat belly."
    c = Canvas()
    # The belly fills the right side, navel dimple included.
    c.ellipse((13, 4, 31, 28), "leather", None)
    c.ellipse((16, 7, 28, 19), "leather", "hi")
    c.dot(22, 20, "leather", "sh")
    c.dot(23, 20, "leather", "sh")
    # The poking hand: folded fist, index finger extended into the squish.
    c.ellipse((2, 12, 12, 22), "rose")
    _stroke(c, [(10, 16), (17, 16)], "rose", r_end=1.6)
    # Squish lines where the finger lands.
    c.line([(18, 12), (20, 14)], "leather", "sh")
    c.line([(18, 20), (20, 18)], "leather", "sh")
    return c


def slurp_and_pad():
    ## "A potion and a pillow."
    c = Canvas()
    # The pillow: a plump slab with pinched corners.
    c.poly([(3, 18), (29, 18), (27, 28), (5, 28)], "bone")
    c.line([(4, 19), (2, 16)], "bone", "sh")
    c.line([(28, 19), (30, 16)], "bone", "sh")
    c.line([(6, 27), (4, 30)], "bone", "sh")
    c.line([(26, 27), (28, 30)], "bone", "sh")
    # The potion bottle resting on it: round flask, neck, cork.
    c.ellipse((10, 6, 22, 18), "teal")
    c.ellipse((12, 8, 18, 13), "teal", "hi")
    c.rect((14, 2, 18, 7), "teal", "sh")
    c.rect((14, 1, 18, 3), "wood")
    return c


def slice():
    ## "An orange (the fruit) slice."
    c = Canvas()
    # Half-disc of rind, flat side up, pith ring inside.
    c.stamp(_half_disc(), "leather")
    c.rect((4, 12, 28, 13), "bone")
    # Segments fanning from the center of the flat edge.
    for a_deg in (20, 55, 90, 125, 160):
        a = math.radians(a_deg)
        c.line([(16, 14), (16 + math.cos(a) * 10.5, 14 + math.sin(a) * 10.5)], "bone")
    return c


def _half_disc():
    return _mask(lambda d: d.pieslice((3, 1, 29, 27), 0, 180, fill=255))


def clang():
    ## "A copper musical triangle."
    c = Canvas()
    # The open triangle (a gap at the bottom-left corner) hung from a loop.
    c.line([(16, 4), (27, 26)], "leather", "hi", width=3)
    c.line([(27, 26), (9, 26)], "leather", None, width=3)
    c.line([(16, 4), (6, 24)], "leather", "sh", width=3)
    c.carve(_rect_mask((5, 23, 9, 28)))  # the sound gap at the open corner
    c.dot(16, 2, "gold", "hi")
    # The beater mid-strike.
    c.line([(24, 8), (30, 2)], "steel", "hi", width=2)
    return c


def fan_save():
    ## "Bracers with fanned wings by the wrists."
    c = Canvas()
    # The bracer: a banded forearm guard up the middle.
    c.rect((12, 8, 20, 28), "leather")
    c.rect((12, 12, 20, 14), "gold", "hi")
    c.rect((12, 20, 20, 22), "gold", "hi")
    # Wing feathers fanning off both sides at the wrist.
    for (sgn, lvl) in ((-1, "hi"), (1, None)):
        for i, ang in enumerate((-70, -45, -20, 5)):
            a = math.radians(ang)
            ln = 11 - i * 1.5
            x0 = 16 + sgn * 5
            _taper(c, (x0, 11 + i * 2),
                   (x0 + sgn * math.cos(a) * ln, 11 + i * 2 + math.sin(a) * ln * -0.4 + 4),
                   1.7, 0.7, "bone")
    return c


ICONS = {
    "three_count": three_count,
    "chain_guard": chain_guard,
    "band_aid": band_aid,
    "future_is_bright": future_is_bright,
    "coming_in": coming_in,
    "suck": suck,
    "well_placed_guard": well_placed_guard,
    "continue_to_move": continue_to_move,
    "defense_one": defense_one,
    "house_rule": house_rule,
    "imbue_tree": imbue_tree,
    "zeet": zeet,
    "lethal_poke": lethal_poke,
    "slurp_and_pad": slurp_and_pad,
    "slice": slice,
    "clang": clang,
    "fan_save": fan_save,
}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for effect_id, fn in sorted(ICONS.items()):
        img = render(fn())
        img.save(os.path.join(OUT_DIR, "%s.png" % effect_id))
        print("wrote %s.png" % effect_id)
    print("%d gauntlet skill icons -> %s" % (len(ICONS), os.path.normpath(OUT_DIR)))


if __name__ == "__main__":
    main()
