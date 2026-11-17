#!/usr/bin/env python3
"""Cut the designer's painted card art out of its sources.

Sources: assets/sprites/paintings/card_art_*.webp / .jpg (.gdignore'd source art).

Boards (BOARDS): a row of square paintings, each in a thin black panel
border; the box is the painting just inside that border (measured: the black
columns and rows run to mean luminance < 12). Each is centre-cropped square
and shrunk to SIZE x SIZE.
  2026-11-15: Basic Attack (a sword through a target) and Block (a sword
  turned on a lion-crest shield).

Single paintings (SINGLES): one landscape painting per card, cropped to a
band about twice as wide as it is tall round the faces and the point of
impact (the box), then shrunk to WIDTH wide.
  2026-11-15: Berserker's Tithe, Momentous Slam, Fan of Knives, Down Town,
  Premeditated.
  The same day: Exacerbate Wounds, Blade Barrage, Exposed Artery, Heavy
  Swing, Oops.

Fitted paintings (FITTED): one object to be seen whole, fitted to the
window's height with its own ground carried out to the sides.

The card's art window is wider than it is tall (about 2.3:1 on the Attack
frame), so CardUI shows these "covered": scaled to the window's width and
cropped about the middle. The boxes below put the action in that middle.

Output: assets/textures/cards/art/<card_id>.png, which
scripts/ui/skill_icon_art.gd maps in CARD_PAINTINGS.
Run: python3 tools/cut_card_art.py   (Pillow)
"""
import os

from PIL import Image

SRC = "assets/sprites/paintings/%s"
OUT = "assets/textures/cards/art/%s.png"
SIZE = 384    # boards' squares: about four times the art window's width
WIDTH = 512   # singles' width: sharp on the hovered and close-up card

# board -> {card_id: (left, top, right, bottom)}
BOARDS = {
    "card_art_attack_block_board.webp": {
        "basic_attack": (9, 8, 873, 879),
        "block": (903, 8, 1768, 879),
    },
}

# card_id -> (source, (left, top, right, bottom))
SINGLES = {
    # The whole of the berserker's roaring head down to the bloodied blade.
    "berserkers_tithe": ("card_art_berserkers_tithe.webp", (0, 70, 1536, 800)),
    # Up high enough to keep the struck man's helmet; down to the charger's fist.
    "momentous_slam": ("card_art_momentous_slam.webp", (0, 0, 1448, 690)),
    # The thrower's face and all four knives.
    "fan_of_knives": ("card_art_fan_of_knives.webp", (0, 130, 1536, 860)),
    # The archer's draw, the castle and the rider thrown from his horse.
    "down_town": ("card_art_down_town.webp", (0, 120, 1536, 850)),
    # Both faces and the knife at the throat.
    "premeditated": ("card_art_premeditated.webp", (0, 80, 1536, 810)),
    # Both faces and the shuriken in the chest (the cut shin falls below).
    "exacerbate_wounds": ("card_art_exacerbate_wounds.webp", (0, 0, 1536, 730)),
    # Both faces, the knives in the chest and the thrower's hand.
    "blade_barrage": ("card_art_blade_barrage.webp", (0, 40, 1536, 770)),
    # The axeman's face and the kneeling man bleeding (the axe head is cut).
    "exposed_artery": ("card_art_exposed_artery.webp", (0, 60, 1536, 790)),
    # The roar, the hammer head and the shield buckling under it.
    "heavy_swing": ("card_art_heavy_swing.webp", (0, 90, 1536, 820)),
    # The punch thrown and the rake in the face; the tines are below.
    "oops": ("card_art_oops.jpg", (0, 0, 1000, 475)),
    # 2026-11-15: the knight's helm, the jabbing finger and the struck face.
    "poke": ("card_art_poke.webp", (0, 0, 1536, 730)),
    # The axe raised, the roar and the blade in the shoulder.
    "savage_strike": ("card_art_savage_strike.webp", (0, 0, 1536, 730)),
    # The sword overhead, the roar and the spear through the chest.
    "reckless_strike": ("card_art_reckless_strike.jpg", (0, 0, 1264, 601)),
    # Both faces and the shield breaking.
    "shield_slam": ("card_art_shield_slam.webp", (0, 0, 1536, 730)),
    # The lunge, the rapier and the knight's thrown-back face.
    "specific_strike": ("card_art_specific_strike.webp", (0, 0, 1536, 730)),
    # 2026-11-15: the spin, the roar and the swords flying from the hands.
    "sweeping_disarm": ("card_art_sweeping_disarm.webp", (0, 80, 1448, 770)),
    # Both faces, the whip down to the ankle it wraps.
    "trip": ("card_art_trip.webp", (0, 90, 1536, 820)),
    # The shrug: the face, the open hand and the hammer head.
    "worst_that_could_happen": ("card_art_worst_that_could_happen.webp", (0, 0, 1536, 730)),
    # The horned charger and the shield wall braced for him.
    "charge": ("card_art_charge.webp", (0, 0, 1536, 730)),
    # The scythe, the reaper's face and the soul pulled from the soldier.
    "harvest": ("card_art_harvest.webp", (0, 110, 1536, 840)),
    # 2026-11-16: the hammer high over the leaper's roar, the soldiers below.
    "heroic_leap": ("card_art_heroic_leap.webp", (0, 0, 1536, 690)),
    # A tall painting: the archer's face and drawing hand, the bow rising.
    "sky_fall": ("card_art_sky_fall.jpg", (0, 300, 896, 727)),
    # The archer above, the arrow drawn on the crowd below.
    "sky_attack": ("card_art_sky_attack.webp", (0, 60, 1536, 790)),
    # The masked eyes and the star held up to them.
    "shuriken": ("card_art_shuriken.webp", (0, 130, 1536, 860)),
    # The hooded snapper, the purple slashes and the struck faces.
    "consecutive_snap": ("card_art_consecutive_snap.webp", (0, 80, 1536, 810)),
    # 2026-11-16: the thrower's face, the outflung hand, the dagger and its mark.
    "dagger_throw": ("card_art_dagger_throw.webp", (0, 100, 1536, 830)),
    # The fallen fighter, the spirit lunging from him and the brute beyond.
    "exhausted_assault": ("card_art_exhausted_assault.webp", (0, 80, 1536, 888)),
    # The archer, eyes closed, the bow drawn and glowing.
    "last_breath": ("card_art_last_breath.webp", (0, 60, 1448, 750)),
    # The loosed arrow and the charging brute (Quick Arrow and Quick Shot).
    "quick_arrow": ("card_art_quick_arrow.webp", (0, 30, 1536, 760)),
    # The throw, the stone in the face and the second one struck.
    "thrown_stone": ("card_art_thrown_stone.webp", (0, 40, 1672, 835)),
    # The archer's draw and the arrow bending through both soldiers.
    "trick_shot": ("card_art_trick_shot.webp", (0, 60, 1448, 822)),
    # The three-arrow draw and the brute charging in.
    "multishot": ("card_art_multishot.webp", (0, 120, 1448, 882)),
    # The glowing arrow through the near man, the second and on to the third.
    "spirit_arrow": ("card_art_spirit_arrow.webp", (0, 40, 1448, 802)),
    # The winged pig, fuse lit, flying at the army.
    "if_pigs_could_fly": ("card_art_if_pigs_could_fly.webp", (0, 60, 1448, 822)),
    # The wall of fire and the burning soldier reaching out.
    "peshtigos_kiss": ("card_art_peshtigos_kiss.webp", (0, 40, 1672, 920)),
    # 2026-11-16: the knight's face, the hand and the wall of stone flung out.
    "approach": ("card_art_approach.webp", (0, 60, 1448, 822)),
    # The knight's upturned face and the glowing vine-veined armour.
    "living_armor": ("card_art_living_armor.webp", (0, 0, 1448, 762)),
    # The healed ally, the knight's face and the shield taking the skeleton's blow.
    "fortify_alliance": ("card_art_fortify_alliance.webp", (0, 120, 1448, 882)),
    # The face, the shield turning the sword, the attacker's helm.
    "parry": ("card_art_parry.jpg", (0, 0, 1264, 665)),
    # The raised sword, the shield wall and the cavalry coming on.
    "hold_the_line": ("card_art_hold_the_line.webp", (0, 40, 1448, 802)),
    # The roar and the soldiers blown off their feet.
    "roar": ("card_art_roar.webp", (0, 80, 1536, 888)),
    # The two-shield knight braced.
    "best_offense": ("card_art_best_offense.webp", (0, 30, 1536, 838)),
    # The duck under the swing. The board's painted title sits above y 110:
    # the box starts below it, so the title is left out.
    "bob_and_weave": ("card_art_bob_and_weave.webp", (0, 115, 1536, 923)),
    # The knight, his shield and the foes round him; the painted title
    # (above y 130) left out the same way.
    "defensive_awareness": ("card_art_defensive_awareness.webp", (0, 135, 1199, 766)),
    # The grimace, the glowing hand and the arrow pulled from the thigh.
    "down_but_not_out": ("card_art_down_but_not_out.webp", (0, 0, 1536, 808)),
    # The mage's face and outspread hands in the sphere, arrows sparking off it.
    "energy_barrier": ("card_art_energy_barrier.webp", (0, 40, 1536, 848)),
    # Both faces and the blade stopped on the bare forearm.
    "harden": ("card_art_harden.webp", (0, 0, 1536, 808)),
    # The eyes over the shield rim, the sword, and the foes either side.
    "hunker_down": ("card_art_hunker_down.webp", (0, 0, 1536, 808)),
    # The braced shield, the shock rings and the brute thrown back.
    "repelled_block": ("card_art_repelled_block.webp", (0, 60, 1536, 868)),
    # The snarl, the glowing gauntlet and the sword sparking off the shield.
    "shield_of_growth": ("card_art_shield_of_growth.webp", (0, 80, 1448, 842)),
    # Tall paintings from here: a strip across the face and the action.
    # Her face and the blade sparking on the shield's rim.
    "shield_ready": ("card_art_shield_ready.webp", (0, 160, 1194, 788)),
    # The raised hands, the red-and-blue vortex, her upturned face and the
    # glowing armour (replaced 2026-11-16).
    "smith_thy_soul": ("card_art_smith_thy_soul.webp", (0, 30, 1195, 659)),
    # The tower shield on his back, arrows in it, climbing the slope.
    "tower_shield": ("card_art_tower_shield.jpg", (0, 60, 976, 574)),
    # The hands pulling the helm down, and the glare beneath it.
    "turtle_up": ("card_art_turtle_up.webp", (0, 190, 1195, 819)),
    # The glowing draught poured and the turtle roaring under it (the monk's
    # face is above: the painting cannot fit both).
    "summon_battle_turtle": ("card_art_summon_battle_turtle.webp", (0, 420, 1254, 1080)),
    # The masks, all five.
    "turtle_power": ("card_art_turtle_power.webp", (0, 0, 1774, 887)),
    # The plumed helm, the beckoning hand and the brutes coming on.
    "taunt": ("card_art_taunt.webp", (0, 0, 1536, 808)),
    # The bloodied, glaring face.
    "grit": ("card_art_grit.webp", (0, 0, 1536, 808)),
    # Two scenes side by side (designer): the throw, then the shiv driven in.
    "pocket_shiv": ("card_art_pocket_shiv.webp", (0, 60, 1536, 868)),
    # Her face, the shield taking the axe, the wounded man behind her.
    "cover": ("card_art_cover.webp", (0, 120, 1448, 882)),
    # The backbend under the spear, her face turned up to it.
    "spider_senses": ("card_art_spider_senses.webp", (0, 120, 1448, 882)),
    # The lightning palm, her shout and the brute convulsing.
    "not_so_fast": ("card_art_not_so_fast.webp", (0, 40, 1536, 848)),
    # The grin, the green eyes and the poisoned hand.
    "spiteful_sting": ("card_art_spiteful_sting.webp", (0, 40, 1536, 848)),
    # The snarl behind the spiked shield and the attacker thrown back.
    "vengeful_shield": ("card_art_vengeful_shield.webp", (0, 120, 1448, 882)),
    # The axeman's soul torn out and drawn to the sorceress's hand.
    "soul_consumption": ("card_art_soul_consumption.webp", (0, 60, 1448, 822)),
    # The hooded mage's ward and the brute's axe sparking off it.
    "magic_barrier": ("card_art_magic_barrier.webp", (0, 0, 1536, 808)),
    # The healer's raised arms and the faces lifted in the red light.
    "healthy_bliss": ("card_art_healthy_bliss.webp", (0, 40, 1536, 848)),
    # The phoenix spread over the burning man and the foes he scorches.
    "gift_from_the_phoenix": ("card_art_gift_from_the_phoenix.webp", (0, 40, 1536, 848)),
    # The burning man's scream and the foes caught in the embers.
    "ember_heart": ("card_art_ember_heart.webp", (0, 30, 1448, 792)),
    # Her face, the knife and the cut palm with the red magic rising.
    "cultish_wounds": ("card_art_cultish_wounds.webp", (0, 80, 1448, 842)),
    # The scream and the molten metal poured on his chest.
    "armored_discipline": ("card_art_armored_discipline.webp", (0, 60, 1536, 868)),
    # A tall painting: the well's bucket and water, the sword, shield, potion and staff.
    "fountain_of_life": ("card_art_fountain_of_life.webp", (0, 420, 1199, 1051)),
    # The swordsman's glare and the two snarling wolves.
    "the_wolfs_howl": ("card_art_the_wolfs_howl.webp", (0, 30, 1536, 838)),
    # 2026-11-17: the caster's raised arms, the spirit shields and the warded soldiers.
    "spirit_armor": ("card_art_spirit_armor.webp", (0, 60, 1448, 822)),
    # The goblin's ear, the sketched tally and the fight he is recording.
    "the_ledger": ("card_art_the_ledger.webp", (0, 160, 1448, 922)),
    # His face and the thorns tearing through him.
    "barbed_exterior": ("card_art_barbed_exterior.jpg", (0, 0, 1264, 665)),
    # Small tall paintings: a strip across the subject.
    # The bowed face over the glowing sword hilt.
    "forever_armor": ("card_art_forever_armor.webp", (0, 100, 524, 376)),
    # The red halo and its rays.
    "halo": ("card_art_halo.webp", (0, 140, 530, 419)),
    # The hound's snarl over the fallen man and the warden's blade above.
    "wardens_hound": ("card_art_wardens_hound.webp", (0, 230, 747, 623)),
    # The two spires, her glowing eyes and the lightning through the dead.
    "lodestone_field": ("card_art_lodestone_field.webp", (0, 40, 1536, 848)),
    # The chain drawn taut and the hooked ghoul pulled in.
    "grapple_chain": ("card_art_grapple_chain.webp", (0, 120, 1536, 928)),
    # The necromancer, the risen corpse with its knife and the grieving man.
    "summon_skeleton": ("card_art_summon_skeleton.webp", (0, 40, 1536, 848)),
    # The skeleton family's portrait by the lake.
    "skeleton_army": ("card_art_skeleton_army.webp", (0, 40, 1448, 802)),
    # The shout, the arms flung wide and the purple arcs hurling the dead.
    "deliberate_arch": ("card_art_deliberate_arch.webp", (0, 0, 1774, 887)),
    # The snarl, the shield slam and the foe flung back with his gear.
    "bastion_battle": ("card_art_bastion_battle.webp", (0, 0, 1440, 720)),
    # The grinning thief, the knife and the shopkeeper unaware.
    "internal_sickness": ("card_art_internal_sickness.webp", (0, 160, 1448, 922)),
    # The jabbing finger, the spark and the wool socks (designer: slid up to
    # show them; the shocked man's face may lose its top).
    "static_sting": ("card_art_static_sting.webp", (0, 200, 1448, 962)),
    # The spear lunge and the brute bracing with his axe.
    "lunge": ("card_art_lunge.webp", (0, 40, 1672, 920)),
    # The scream and the thorned vines wrapping him.
    "vines": ("card_art_vines.webp", (0, 0, 1448, 762)),
    # The skeleton's lightning and the man it strikes.
    "mana_surge": ("card_art_mana_surge.webp", (0, 60, 1447, 822)),
}

# card_id -> (source, box): a single object to be seen whole (a gem, a
# stone, a necklace). The box is fitted to the window's height, centred,
# and the sides carry the painting's own edge colour outward, darkening a
# little, so its dark ground runs on to the window's edges. 2026-11-15
# (no cards with these ids yet; the art waits for them).
FITTED = {
    "energy_gem": ("card_art_energy_gem.png", (0, 0, 230, 327)),
    "fumbleitis": ("card_art_fumbleitis.png", (0, 0, 322, 355)),
    "stone_patch": ("card_art_stone_patch.webp", (0, 100, 1448, 1000)),
    "life_from_resource": ("card_art_life_from_resource.webp", (0, 0, 1448, 960)),
    "lemon_drop": ("card_art_lemon_drop.webp", (0, 30, 1448, 1086)),
    "brawn_gem": ("card_art_brawn_gem.webp", (0, 20, 1448, 1000)),
    "feather_foot": ("card_art_feather_foot.webp", (0, 0, 1448, 1010)),
    # 2026-11-16: the bandage with the shield set in it.
    "armor_patch": ("card_art_armor_patch.webp", (60, 150, 1476, 870)),
    # 2026-11-17: her face, the glowing hands and the dog's whole head
    # (designer) — a wide crop fitted to the window's height.
    "summon_shadow_hound": ("card_art_summon_shadow_hound.webp", (80, 100, 1448, 1040)),
}
FIT_ASPECT = 1.9    # the Attack frame's art window, about the widest (2026-11-16: taller)
FIT_FEATHER = 0.08  # the fitted picture's sides fade into the fill over this much of its width


def fitted(source, box, aspect=None):
    piece = Image.open(SRC % source).convert("RGB").crop(box)
    h = round(WIDTH / (aspect or FIT_ASPECT))
    w_in = round(piece.width * h / piece.height)
    if w_in > WIDTH:   # already wider than the window: shrink to its width
        w_in, h_in = WIDTH, round(piece.height * WIDTH / piece.width)
    else:
        h_in = h
    inner = piece.resize((w_in, h_in), Image.LANCZOS)
    # The fill: each side carries the picture's own edge colour outward,
    # row by row (smoothed down the rows), darkening a little toward the
    # window's edges, so the seam matches and the ground runs on.
    import numpy as np
    a = np.asarray(inner).astype(np.float32)
    k = max(2, w_in // 40)
    left = a[:, :k].mean(axis=1)
    right = a[:, -k:].mean(axis=1)
    from scipy.ndimage import gaussian_filter1d
    left = gaussian_filter1d(left, h_in * 0.06, axis=0)
    right = gaussian_filter1d(right, h_in * 0.06, axis=0)
    x0 = (WIDTH - w_in) // 2
    canvas = np.zeros((h, WIDTH, 3), np.float32)
    top = (h - h_in) // 2
    for x in range(WIDTH):
        if x < x0 + w_in // 2:
            col, t = left, (x0 - x) / max(1, x0)
        else:
            col, t = right, (x - (x0 + w_in)) / max(1, WIDTH - x0 - w_in)
        dim = 1.0 - 0.35 * min(1.0, max(0.0, t))
        canvas[top:top + h_in, x] = col * dim
    back = Image.fromarray(canvas.clip(0, 255).astype(np.uint8))
    # The picture over it, its sides feathered in.
    mask = Image.new("L", (w_in, h_in), 255)
    fw = max(1, round(w_in * FIT_FEATHER))
    for x in range(fw):
        a = round(255 * (x + 1) / (fw + 1))
        for xx in (x, w_in - 1 - x):
            mask.paste(a, (xx, 0, xx + 1, h_in))
    back.paste(inner, ((WIDTH - w_in) // 2, (h - h_in) // 2), mask)
    return back


def grow_to_aspect(box, size):
    """A single's box made as tall as FIT_ASPECT asks (the art window grew
    taller on 2026-11-16): grown evenly about its middle, kept inside the
    painting (shifted, not cut, at an edge). The boxes above were placed for
    the old, wider window; the action stays at their middle."""
    l, t, r, b = box
    want = round((r - l) / FIT_ASPECT)
    if b - t >= want:
        return box
    want = min(want, size[1])
    mid = (t + b) / 2.0
    t = round(mid - want / 2.0)
    t = max(0, min(t, size[1] - want))
    return (l, t, r, t + want)


def main() -> None:
    os.makedirs(os.path.dirname(OUT % "x"), exist_ok=True)
    for board, cuts in BOARDS.items():
        src = Image.open(SRC % board).convert("RGB")
        for card_id, box in cuts.items():
            piece = src.crop(box)
            # A few pixels off square: centre-crop to the shorter side.
            side = min(piece.size)
            l = (piece.width - side) // 2
            t = (piece.height - side) // 2
            piece = piece.crop((l, t, l + side, t + side)).resize((SIZE, SIZE), Image.LANCZOS)
            piece.save(OUT % card_id, optimize=True)
            print("wrote", OUT % card_id)
    for card_id, (source, box) in SINGLES.items():
        src = Image.open(SRC % source).convert("RGB")
        piece = src.crop(grow_to_aspect(box, src.size))
        h = round(piece.height * WIDTH / piece.width)
        piece.resize((WIDTH, h), Image.LANCZOS).save(OUT % card_id, optimize=True)
        print("wrote", OUT % card_id, (WIDTH, h))
    for card_id, spec in FITTED.items():
        # (source, box) or (source, box, aspect): an aspect for a card whose
        # frame's art window is wider than FIT_ASPECT, so the window does not
        # trim the fitted painting's top and bottom.
        fitted(*spec).save(OUT % card_id, optimize=True)
        print("wrote", OUT % card_id, "(fitted)")


if __name__ == "__main__":
    main()
