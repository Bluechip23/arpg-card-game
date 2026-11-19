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
    # The jabbing finger, the spark and the shocked faces.
    "static_sting": ("card_art_static_sting.webp", (0, 0, 1448, 762)),
    # The spear lunge and the brute bracing with his axe.
    "lunge": ("card_art_lunge.webp", (0, 40, 1672, 920)),
    # The scream and the thorned vines wrapping him.
    "vines": ("card_art_vines.webp", (0, 0, 1448, 762)),
    # The skeleton's lightning and the man it strikes.
    "mana_surge": ("card_art_mana_surge.webp", (0, 60, 1447, 822)),
    # The glowing drop falling from the glass to the blue-eyed upturned face.
    "spark": ("card_art_spark.webp", (0, 40, 1447, 802)),
    # The glowing eyes and the orbs circling him.
    "harness_lightning": ("card_art_harness_lightning.webp", (0, 40, 1448, 802)),
    # The scream and the thorns bursting out into the soldiers.
    "spine_release": ("card_art_spine_release.jpg", (0, 40, 1195, 669)),
    # The burning library, its statues, banners and the armillary sphere.
    "flames_of_alexandria": ("card_art_flames_of_alexandria.webp", (0, 220, 1448, 982)),
    # The glare, the staff's gem and the green magic in the open hand.
    "arcane_tide": ("card_art_arcane_tide.webp", (0, 40, 1448, 802)),
    # Her face and the glass shield conjured beside her.
    "ward_of_hallow_glass": ("card_art_ward_of_hallow_glass.webp", (0, 40, 1448, 802)),
    # Her glowing hands and the ice spikes hurling the soldiers.
    "surrounding_ice": ("card_art_surrounding_ice.webp", (0, 40, 1448, 802)),
    # The swordsman's glare and the knight burning from within.
    "internal_combustion": ("card_art_internal_combustion.webp", (0, 0, 1448, 762)),
    # The floating caster and the light drawn from the army.
    "absorb_essence": ("card_art_absorb_essence.webp", (0, 0, 1672, 880)),
    # The hooded reach and the goblin clutching his throat.
    "choke": ("card_art_choke.webp", (0, 40, 1672, 920)),
    # The hammer, her roar and the bolt into the giant.
    "god_of_thunder": ("card_art_god_of_thunder.webp", (0, 40, 1672, 920)),
    # The burning caster's face, his hands and the fire swirling round him.
    "fireball": ("card_art_fireball.webp", (0, 80, 1448, 842)),
    # The glowing eyes and the orb held between her hands.
    "energy_ball": ("card_art_energy_ball.webp", (0, 0, 1672, 880)),
    # The flaming worm, jaws open, coiled round its burning rock.
    "worms_armageddon": ("card_art_worms_armageddon.webp", (0, 0, 1671, 880)),
    # The fire-breath, the melting snowman and the horde behind.
    "snowballs_chance": ("card_art_snowballs_chance.webp", (0, 80, 1448, 842)),
    # 2026-11-18: the man leaning on his rock, watching the sunset.
    "petey_the_pet_rock": ("card_art_petey_the_pet_rock.webp", (0, 60, 1671, 940)),
    # The dazed face and the stars circling his head.
    "lightly_dazed": ("card_art_lightly_dazed.webp", (0, 0, 1312, 690)),
    # The grimace and the hand clutching the cut arm.
    "minor_wounds": ("card_art_minor_wounds.webp", (0, 0, 1536, 808)),
    # The elephant stepping into the glowing quiver.
    "bottomless_quiver": ("card_art_bottomless_quiver.webp", (0, 80, 1536, 888)),
    # The boy's grin, the case of arrows and the warrior pondering them.
    "collect_arrows": ("card_art_collect_arrows.webp", (0, 40, 1536, 848)),
    # The grimace and the soiled cloth held over the bin.
    "discard": ("card_art_discard.webp", (0, 40, 1536, 848)),
    # The goggled alchemist and the snake biting the glowing arm.
    "elixir": ("card_art_elixir.webp", (0, 100, 1448, 862)),
    # The caster's shout, the ice shard and the glowing arrow.
    "enchanted_quiver": ("card_art_enchanted_quiver.webp", (0, 0, 1672, 880)),
    # The jailer on the balcony over the prisoners (Self Admission: a card jailed).
    "self_admission": ("card_art_self_admission.webp", (0, 0, 1672, 880)),
    # The lit bomb in one hand, the knife in the other.
    "reverse_reverse": ("card_art_reverse_reverse.webp", (0, 30, 1672, 910)),
    # The outstretched arms among the flowers and the glowing butterflies.
    "clarity": ("card_art_clarity.webp", (0, 30, 1672, 910)),
    # The blissful grin and the imp whispering at his ear.
    "succumb": ("card_art_succumb.webp", (0, 0, 1671, 880)),
    # Her scream, the box flung open and the horrors pouring out.
    "pandora_panic": ("card_art_pandora_panic.webp", (0, 0, 1672, 880)),
    # The two caught mid-swap in the swirl of light.
    "swap": ("card_art_swap.webp", (0, 30, 1671, 910)),
    # The smirk and the syringe dripping red.
    "adrenaline_shot": ("card_art_adrenaline_shot.webp", (0, 0, 1672, 880)),
    # The glare, the blade on the grindstone and the sparks.
    "stone_wheel": ("card_art_stone_wheel.webp", (0, 100, 1448, 862)),
    # The three glasses poured into the swirling beaker.
    "gulped_potion": ("card_art_gulped_potion.webp", (0, 60, 1448, 822)),
    # The head thrown back and the purple spray.
    "gargle_and_spit": ("card_art_gargle_and_spit.webp", (0, 0, 1536, 808)),
    # The roar, the red eyes and the burning veins.
    "raged_circulation": ("card_art_raged_circulation.webp", (0, 40, 1536, 848)),
    # Her leap, the scream and the two flaming blades.
    "both_sides_of_the_candle": ("card_art_both_sides_of_the_candle.webp", (0, 30, 1536, 838)),
    # Her smile, the flipped coin and his open hand (designer: Try This!).
    "try_this": ("card_art_try_this.webp", (0, 40, 1536, 848)),
    # The hilt and the four-leaf clover tied to the blade.
    "lady_luck": ("card_art_lady_luck.webp", (0, 230, 1448, 992)),
    # The pourer on the ledge covering their eyes (designer: must show), the
    # potion and the fighter below (designer: Hope This Works).
    "hope_this_works": ("card_art_hope_this_works.webp", (0, 0, 1448, 900)),
    # Her face, the outthrust palm and the brute blown back.
    "push": ("card_art_push.webp", (0, 60, 1536, 868)),
    # The monk's upturned calm and the light flowing into the goblin.
    "release_tension": ("card_art_release_tension.webp", (0, 80, 1536, 888)),
    # The purple vortex pulling the foes in.
    "round_em_up": ("card_art_round_em_up.webp", (0, 40, 1536, 848)),
    # The roar inside the rolling cage and the fleeing goblin.
    "roll": ("card_art_roll.webp", (0, 60, 1536, 868)),
    # The shadow on the crate and the goblins puzzling over it.
    "surprise_pick_up": ("card_art_surprise_pick_up.webp", (0, 60, 1536, 868)),
    # The goblin's fright and the shapes lost in the fog.
    "thickened_nature": ("card_art_thickened_nature.webp", (0, 0, 1448, 762)),
    # The archer behind the crates and the goblins charging.
    "barricade": ("card_art_barricade.webp", (0, 60, 1536, 868)),
    # The druid's reach and the ground rising up.
    "rise": ("card_art_rise.webp", (0, 40, 1448, 802)),
    # The hooded dash and the purple after-image.
    "blink": ("card_art_blink.webp", (0, 80, 1536, 888)),
    # The goggled alchemist, the bubbling flask and the goblins round him.
    "volatile_mixture": ("card_art_volatile_mixture.webp", (0, 60, 1448, 822)),
    # The spirit lion's roar and the orc thrown back.
    "stoked_pride": ("card_art_stoked_pride.webp", (0, 40, 1536, 848)),
    # The target sigil in the misty glade.
    "mark": ("card_art_mark.webp", (0, 80, 1536, 888)),
    # The two strategists and the hand moving a piece on the map.
    "anticipation": ("card_art_anticipation.webp", (0, 40, 1536, 848)),
    # The hammer blow and the armour flying off the startled man.
    "armor_break": ("card_art_armor_break.webp", (0, 40, 1536, 848)),
    # The red-eyed, bloody grin.
    "bloodlust": ("card_art_bloodlust.webp", (0, 40, 1536, 848)),
    # Her calm upturned face and the sabres circling her.
    "composed_response": ("card_art_composed_response.webp", (0, 0, 1448, 762)),
    # The bulging pouches and the puzzled giant.
    "deep_pockets": ("card_art_deep_pockets.webp", (0, 120, 1448, 882)),
    # The smirk and the whetstone on the blade.
    "empower": ("card_art_empower.webp", (0, 120, 1536, 928)),
    # The belt traded for the glowing blue potion (Short Term Fix).
    "give_in": ("card_art_give_in.webp", (0, 80, 1536, 888)),
    # The hooded mage with his vials, the smoothie blended behind.
    "healthy_habit": ("card_art_healthy_habit.webp", (0, 40, 1536, 848)),
    # The handspring, the vanish and the strike through the after-image.
    "lethal_recall": ("card_art_lethal_recall.webp", (180, 160, 1448, 827)),   # slid left: the speared one central
    # The jeweled fangs on the apothecary's table.
    "life_steal": ("card_art_life_steal.webp", (0, 160, 1448, 922)),
    # The hooded glare and the fans of knives in both hands.
    "meister_of_faustmesser": ("card_art_meister_of_faustmesser.webp", (0, 80, 1448, 842)),
    # His upturned face, the blue flame and the red-and-blue drip in his arm.
    "life_swap": ("card_art_life_swap.webp", (0, 40, 1448, 802)),
    # The two capsules, one spilling its powder.
    "morphine": ("card_art_morphine.webp", (0, 160, 1536, 968)),
    # The goblin's snake spitting venom into the holy cauldron.
    "poisoned_blood": ("card_art_poisoned_blood.webp", (0, 40, 1536, 848)),
    # The man pointing at himself in the mirror.
    "preparation": ("card_art_preparation.webp", (0, 40, 1536, 848)),
    # The two commanders rallying the army below the castle.
    "prepare": ("card_art_prepare.webp", (0, 0, 1672, 880)),
    # Her aim down the triple-loaded crossbow.
    "reload": ("card_art_reload.webp", (0, 80, 1536, 888)),
    # A six-panel strip: its last two panels, the "?" and the peek (the punchline).
    "reposition": ("card_art_reposition.webp", (516, 512, 1536, 1024)),
    # The baker sliding the biscuits into the oven (Risk It: the Biscuit).
    "risk_it": ("card_art_risk_it.webp", (0, 60, 1536, 868)),
    # The hooded cutter bleeding onto the open book, foes closing in.
    "self_infliction": ("card_art_self_infliction.webp", (0, 80, 1536, 888)),
    # A very wide board: the fading after-images and the baffled goblin.
    "shadows": ("card_art_shadows.webp", (780, 0, 2000, 667)),
    # The star jump, arms flung up.
    "shed_weight": ("card_art_shed_weight.webp", (0, 0, 1448, 762)),
    # The bow bent to string it.
    "tighten_string": ("card_art_tighten_string.webp", (0, 40, 1536, 848)),
    # The apple and the training ground watched from the ridge.
    "understanding": ("card_art_understanding.webp", (0, 60, 1672, 940)),
    # The grin and the fist driven into the orc.
    "wear_down": ("card_art_wear_down.webp", (0, 60, 1536, 868)),
    # Her shout and the kick bursting the straw dummy.
    "cadence": ("card_art_cadence.webp", (0, 40, 1448, 802)),
    # The two goblins at cards, one sneaking a stack of coins.
    "foresight": ("card_art_foresight.webp", (0, 120, 1448, 882)),
    # The archer's draw and the troll lunging.
    "back_pedal": ("card_art_back_pedal.webp", (0, 0, 1672, 880)),
    # The war horn raised to his lips (designer: Inspiring Whistle).
    "inspiring_whistle": ("card_art_inspiring_whistle.webp", (0, 0, 1672, 880)),
    # The roar and the beasts charging round him (designer: War Shout).
    "war_shout": ("card_art_war_shout.webp", (0, 40, 1672, 920)),
    # The goblin banker counting notes, feet on the desk.
    "house_money": ("card_art_house_money.webp", (0, 40, 1448, 802)),
    # The puffed cheeks, the arms flung out and the swirling air.
    "deep_breaths": ("card_art_deep_breaths.webp", (0, 0, 1536, 808)),
    # The grin and the crystal heart crushed in her bleeding hand.
    "demonic_rage": ("card_art_demonic_rage.webp", (0, 60, 1448, 822)),
    # The ally encased in ice, the orc and the leaping fighter beyond.
    "cryonics": ("card_art_cryonics.webp", (0, 0, 1672, 880)),
    # The laughing high five and its burst of light.
    "friendship": ("card_art_friendship.webp", (0, 0, 1536, 808)),
    # The floating monk in his ring of glowing runes.
    "meditate": ("card_art_meditate.webp", (0, 0, 1536, 808)),
    # The cleric's blood streaming out to the wounded allies.
    "communal_donation": ("card_art_communal_donation.jpg", (0, 0, 1365, 718)),
    # The blood shield thrown round the screaming ally against the shieldman.
    "shepherds_mark": ("card_art_shepherds_mark.jpg", (0, 80, 1195, 709)),
    # The thief slammed into the cracking mirror, his reflections behind.
    "mirror_mirror": ("card_art_mirror_mirror.webp", (0, 0, 1672, 880)),
    # The monk drawing the gloom from the goblin and the orc with their signs.
    "misery_loves_company": ("card_art_misery_loves_company.webp", (0, 0, 1671, 880)),
    # The knight's hand pouring green light into the wounded mage.
    "acro_medic": ("card_art_acro_medic.webp", (0, 0, 1672, 880)),
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
    # 2026-11-18: the field-medic's bag, seen whole.
    "heal": ("card_art_heal.webp", (60, 60, 1536, 1000)),
    # The mana drop with the caster inside it, seen whole on its black (Energy).
    "gain_mana": ("card_art_gain_mana.webp", (230, 0, 1090, 1199)),
    # The red potion with its cross tag, seen whole.
    "healing_potion": ("card_art_healing_potion.png", (240, 130, 784, 870)),
    # The buttered biscuit and the jam, seen whole.
    "biscuit": ("card_art_biscuit.webp", (160, 60, 1536, 960)),
    # The d20 showing 20, seen whole.
    "loaded_die": ("card_art_loaded_die.webp", (260, 0, 1280, 960)),
    # The leather pouch spilling its shuriken, seen whole.
    "shuriken_pouch": ("card_art_shuriken_pouch.webp", (40, 40, 1536, 900)),
    # A tall painting fitted to the window: her grin and slash below, the
    # troll's scream in the top corner.
    "feint": ("card_art_feint.webp", (0, 0, 1122, 880)),
    # The golem of weapons, crowned head to claws, fitted to the window.
    "item_mastery": ("card_art_item_mastery.webp", (0, 0, 1312, 900)),
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
