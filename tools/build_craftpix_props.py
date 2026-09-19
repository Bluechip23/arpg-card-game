#!/usr/bin/env python3
"""Cut ground props out of the Craftpix packs for the billboard prop system.

The tilesets ship every prop as its own PNG (Objects_separat*/), padded to a
power-of-two cell and, for most, in two shadow strengths. The game's prop
MultiMeshes want a tight sprite per texture with a known pixel size. This
tool crops each chosen source to its opaque bounding box (the painted light
shadow stays — under the fixed top-down camera it IS the prop's contact
shadow), writes it to assets/textures/craftpix/props/, and generates
scripts/core/craftpix_props.gd: a manifest of role -> variants with sizes
and a base scale, which DungeonManager reads to scatter them.

Roles are per biome (field = World 1 grassland pack, forest = Greenwood,
cave, undead = World 5 barrow land, cursed = World 4 hell) plus a few
shared ones (chests, icons). Pack art is only cropped, never repainted.

    python3 tools/build_craftpix_props.py
"""
import os
from PIL import Image

SRC = "assets/sprites/craftpix"
OUT = "assets/textures/craftpix/props"
MANIFEST = "scripts/core/craftpix_props.gd"

F = "tileset_forest/Objects_separated"
G = "tileset_grassland/Objects_separated"
C = "tileset_cave/Objects_separately"
U = "tileset_undead_land/Objects_separately"
X = "tileset_cursed_land/Objects_separetely"
T = "treasure_32x32"
A = "armor_weapons_icons"

# role -> {"scale": base scale applied to every variant, "src": [paths]}
# 128px trees are drawn for 16px tiles; at the game's 32-texel unit they
# would stand four cells tall, so the big canopies get a 0.7 base.
ROLES = {
    # --- World 1 field (grassland pack) ---
    "field_tree": {"scale": 0.7, "src": [f"{G}/Tree1.png", f"{G}/Tree2.png", f"{G}/Tree4.png"]},
    "field_tree_fruit": {"scale": 0.7, "src": [f"{G}/Tree3.png"]},
    "field_tree_small": {"scale": 1.0, "src": [f"{G}/Tree5.png"]},
    "field_stump": {"scale": 1.0, "src": [f"{G}/Broken_tree1.png", f"{G}/Broken_tree2.png", f"{G}/Broken_tree4.png", f"{G}/Broken_tree5.png"]},
    "field_rock": {"scale": 1.0, "src": [f"{G}/Stone1_grass_shadow.png", f"{G}/Stone2_grass_shadow.png", f"{G}/Stone3_grass_shadow.png", f"{G}/Stone4_grass_shadow.png", f"{G}/Rpck_grass1.png", f"{G}/Rpck_grass2.png", f"{G}/Rpck_grass3.png", f"{G}/Rpck_grass4.png"]},
    "field_bush": {"scale": 1.0, "src": [f"{G}/Bush2.png", f"{G}/Bush3.png", f"{G}/Bush4.png", f"{G}/Bush5.png", f"{G}/Bush7.png", f"{G}/Bush9.png"]},
    "field_berry": {"scale": 1.0, "src": [f"{G}/Bush1.png", f"{G}/Bush6.png", f"{G}/Bush8.png", f"{G}/Bush14.png", f"{G}/Bush15.png", f"{G}/Bush17.png"]},
    "field_fern": {"scale": 1.0, "src": [f"{G}/Bush12.png", f"{G}/Bush13.png", f"{G}/Bush18.png", f"{F}/Bush8.png", f"{F}/Bush10.png"]},
    "field_flower": {"scale": 1.0, "src": [f"{G}/Flower{i}.png" for i in range(1, 12)]},
    "field_tuft": {"scale": 1.0, "src": [f"{G}/grass_element1.png", f"{G}/grass_element2.png", f"{G}/grass_element3.png", f"{G}/Bush10.png", f"{G}/Bush16.png", f"{G}/Bush19.png"]},
    "field_shroom": {"scale": 1.0, "src": [f"{F}/Brown_mushroom1.png", f"{F}/Brown_mushroom2.png", f"{F}/Red_mushroom1.png"]},
    "field_pebble": {"scale": 1.0, "src": [f"{G}/ground_element20.png", f"{G}/ground_element21.png", f"{G}/ground_element22.png", f"{G}/ground_element23.png", f"{G}/Rock_grass_element13.png"]},
    "field_ruin": {"scale": 0.8, "src": [f"{G}/Ruin1_grass_shadow.png", f"{G}/Ruin2_grass_shadow.png", f"{G}/Ruin3_grass_shadow.png", f"{G}/Ruin4_grass_shadow.png", f"{G}/Ruin5_grass_shadow.png"]},
    # --- Greenwood (forest pack) ---
    "forest_tree": {"scale": 1.0, "src": [f"{F}/Tree4.png", f"{F}/Tree7.png", f"{F}/Tree8.png", f"{F}/Tree9.png", f"{F}/Tree10.png", f"{F}/Tree12.png", f"{F}/Tree13.png", f"{F}/Tree14.png"]},
    "forest_tree_big": {"scale": 0.7, "src": [f"{F}/Tree1.png", f"{F}/Tree2.png", f"{F}/Tree3.png", f"{F}/Tree6.png", f"{F}/Tree11.png"]},
    "forest_tree_climb": {"scale": 0.75, "src": [f"{F}/Tree5.png"]},
    "forest_stump": {"scale": 1.0, "src": [f"{F}/Broken_tree2.png", f"{F}/Broken_tree3.png", f"{F}/Broken_tree4.png", f"{F}/Broken_tree5.png"]},
    "forest_log": {"scale": 1.0, "src": [f"{F}/Broken_tree1.png", f"{F}/Broken_tree6.png"]},
    "forest_rock": {"scale": 1.0, "src": [f"{F}/Light_stone_grass1.png", f"{F}/Light_stone_grass2.png", f"{F}/Light_stone_grass3.png", f"{F}/Brown_stone_grass1.png", f"{F}/Brown_stone_grass2.png", f"{F}/Beige_stone_grass1.png", f"{F}/Beige_stone_grass4.png", f"{F}/Beige_stone_grass8.png"]},
    "forest_bush": {"scale": 1.0, "src": [f"{F}/Bush1.png", f"{F}/Bush2.png", f"{F}/Bush3.png", f"{F}/Bush4.png", f"{F}/Bush5.png", f"{F}/Bush11.png", f"{F}/Bush13.png"]},
    "forest_fern": {"scale": 1.0, "src": [f"{F}/Bush6.png", f"{F}/Bush8.png", f"{F}/Bush10.png", f"{F}/Layer7.png"]},
    "forest_shroom": {"scale": 1.0, "src": [f"{F}/Brown_mushroom1.png", f"{F}/Brown_mushroom2.png", f"{F}/Red_mushroom1.png", f"{F}/Red_mushroom2.png", f"{F}/Red_mushroom3.png"]},
    "forest_reeds": {"scale": 1.0, "src": [f"{F}/reeds1.png", f"{F}/reeds2.png", f"{F}/reeds3.png"]},
    "forest_pebble": {"scale": 1.0, "src": [f"{F}/Beige_stone_ground5.png", f"{F}/Beige_stone_ground6.png", f"{F}/Beige_stone_ground7.png", f"{F}/Beige_stone_ground9.png", f"{F}/Brown_stone_ground5.png"]},
    "forest_ruin": {"scale": 0.8, "src": [f"{F}/Ruin_grass1.png", f"{F}/Ruin_grass2.png", f"{F}/Ruin_grass3.png", f"{F}/Ruin_grass4.png", f"{F}/Ruin_grass5.png"]},
    # --- Caves ---
    "cave_stalagmite": {"scale": 1.0, "src": [f"{C}/gray_stalagmites_light_shadow{i}.png" for i in range(1, 6)] + [f"{C}/black_stalagmites_light_shadow{i}.png" for i in (2, 4, 5)]},
    "cave_rock": {"scale": 1.0, "src": [f"{C}/Walls_elements{i}.png" for i in (1, 2, 6, 10, 11, 16, 17, 18, 19, 20)]},
    "cave_shroom": {"scale": 1.0, "src": [f"{C}/small_mushrooms_white_light_shadow1.png", f"{C}/small_mushrooms_white_light_shadow2.png", f"{C}/small_mushrooms_gray_light_shadow1.png", f"{C}/small_mushrooms_gray_light_shadow2.png", f"{C}/Slime_musroom_light_shadow2.png", f"{C}/Slime_musroom_light_shadow3.png", f"{C}/Long_mushrooms_light_shadow2.png", f"{C}/Long_mushrooms_light_shadow3.png"]},
    "cave_crystal": {"scale": 1.0, "src": [f"{C}/{c}_stone_light_shadow{i}.png" for c in ("Blue", "Green", "Red", "Yellow", "Orange") for i in (1, 2, 3)]},
    "cave_pebble": {"scale": 1.0, "src": [f"{C}/Black_stone_light_shadow3.png", f"{C}/Black_stone_light_shadow4.png", f"{C}/Blue_stone_light_shadow4.png", f"{C}/Green_stone_light_shadow4.png", f"{C}/Walls_elements19.png"]},
    "cave_web": {"scale": 1.0, "src": [f"{C}/web1.png", f"{C}/web2.png"]},
    "cave_gate": {"scale": 0.8, "src": [f"{C}/gates1.png"]},
    # --- World 5 barrow land (undead pack) ---
    "undead_tree": {"scale": 0.8, "src": [f"{U}/Dead_tree_shadow1_1.png", f"{U}/Dead_tree_shadow1_2.png", f"{U}/Dead_tree_shadow1_3.png", f"{U}/Tree_shadow1_1.png", f"{U}/Tree_shadow1_2.png"]},
    "undead_stump": {"scale": 1.0, "src": [f"{U}/Broken_tree_shadow1_2.png", f"{U}/Broken_tree_shadow1_3.png", f"{U}/Broken_tree_shadow1_4.png", f"{U}/Broken_tree_shadow1_5.png"]},
    "undead_rock": {"scale": 1.0, "src": [f"{U}/Rock_shadow1_{i}.png" for i in range(1, 6)]},
    "undead_bush": {"scale": 1.0, "src": [f"{U}/Plant_shadow1_{i}.png" for i in range(1, 6)] + [f"{U}/Thorn_plant_shadow1_{i}.png" for i in (1, 2, 3)]},
    "undead_bones": {"scale": 1.0, "src": [f"{U}/Bones_shadow1_{i}.png" for i in (2, 3, 5, 7, 8, 9, 12, 13, 16, 17, 18)]},
    "undead_grave": {"scale": 1.0, "src": [f"{U}/Grave_shadow1_{i}.png" for i in range(1, 12)]},
    "undead_ruin": {"scale": 0.8, "src": [f"{U}/Ruin_shadow1_{i}.png" for i in range(1, 6)]},
    "undead_skulls": {"scale": 1.0, "src": [f"{U}/Pile_sculls_shadow1.png"]},
    "undead_crystal": {"scale": 1.0, "src": [f"{U}/Crystal_shadow1_{i}.png" for i in range(1, 5)]},
    # --- World 4 hell (cursed land pack) ---
    "cursed_rock": {"scale": 1.0, "src": [f"{X}/Rock1_shadow1_{i}.png" for i in range(1, 6)] + [f"{X}/Rock3_shadow1_{i}.png" for i in (3, 4, 5)]},
    "cursed_plant": {"scale": 1.0, "src": [f"{X}/Eye_plant_shadow1_1.png", f"{X}/Eye_plant_shadow1_2.png", f"{X}/Many_eyes_plant_shadow1_1.png", f"{X}/Tubular_plant_shadow1_1.png", f"{X}/Tubular_plant_shadow1_2.png", f"{X}/Spike_plant_shadow1_3.png", f"{X}/Spike_plant_shadow1_4.png", f"{X}/Pustules_shadow1_1.png", f"{X}/Pustules_shadow1_2.png"]},
    "cursed_tree": {"scale": 0.8, "src": [f"{X}/Tentacle_plant_shadow1_1.png", f"{X}/Meat_flower_shadow1_1.png", f"{X}/Jaws_plant_shadow1_1.png", f"{X}/Spike_plant_shadow1_2.png"]},
    "cursed_bones": {"scale": 1.0, "src": [f"{X}/Bones_shadow1_{i}.png" for i in (2, 3, 5, 7, 8, 9, 10, 11)]},
    "cursed_ruin": {"scale": 0.8, "src": [f"{X}/Ruins_shadow2_1.png", f"{X}/Ruins_shadow2_2.png", f"{X}/Ruins_shadow2_3.png", f"{X}/Ruins_shadow2_4.png"]},
    "cursed_eye": {"scale": 1.0, "src": [f"{X}/Rock_eyes_shadow1_1.png", f"{X}/Rock_eyes_shadow1_2.png"]},
}

# Atlas cells (sheet, x, y, w, h) cropped straight out of a packed sheet.
CELLS = {
    # Building / stores dressing from the treasure objects sheet.
    "goods_barrel": {"scale": 1.0, "cells": [(f"{T}/Objects.png", 240, 96, 32, 32), (f"{T}/Objects.png", 256, 96, 32, 32)]},
    "goods_sack": {"scale": 1.0, "cells": [(f"{T}/Objects.png", 192, 96, 32, 32), (f"{T}/Objects.png", 208, 96, 32, 32), (f"{T}/Objects.png", 32, 192, 32, 32)]},
    "goods_crate": {"scale": 1.0, "cells": [(f"{T}/Objects.png", 272, 96, 32, 32), (f"{T}/Objects.png", 288, 96, 32, 32)]},
    "goods_pile": {"scale": 1.0, "cells": [(f"{T}/Objects.png", 0, 192, 32, 32)]},
    # Armoury furniture (32 wide, up to 64 tall).
    "goods_rack": {"scale": 1.0, "cells": [(f"{A}/Furniture.png", 0, 64, 32, 64), (f"{A}/Furniture.png", 0, 128, 32, 64), (f"{A}/Furniture.png", 0, 256, 32, 64)]},
    "goods_table": {"scale": 1.0, "cells": [(f"{A}/Furniture.png", 64, 32, 32, 64), (f"{A}/Furniture.png", 64, 160, 32, 64)]},
    # Chests: column = design, row 0 closed, row 2 open with loot.
    "chest_wood_closed": {"scale": 1.0, "cells": [(f"{T}/chests.png", 0, 0, 32, 32)]},
    "chest_wood_open": {"scale": 1.0, "cells": [(f"{T}/chests.png", 0, 64, 32, 32)]},
    "chest_rare_closed": {"scale": 1.0, "cells": [(f"{T}/chests.png", 96, 0, 32, 32)]},
    "chest_rare_open": {"scale": 1.0, "cells": [(f"{T}/chests.png", 96, 64, 32, 32)]},
    "chest_mythic_closed": {"scale": 1.0, "cells": [(f"{T}/chests.png", 224, 0, 32, 32)]},
    "chest_mythic_open": {"scale": 1.0, "cells": [(f"{T}/chests.png", 224, 64, 32, 32)]},
}


# Equipment-slot icons for the inventory UI (32px cells of the icon packs).
# Written to assets/textures/craftpix/ui/. Picks are (sheet, col, row).
UI_OUT = "assets/textures/craftpix/ui"
UI_ICONS = {
    # Armour/weapon sheet: the icons are packed as big/small pairs, not on a
    # clean 32px grid, so these are pixel boxes (x0, y0, x1, y1) of the big
    # icon, found by connected components (see git history for the survey).
    "slot_helm": (f"{A}/Icons.png", (457, 39, 470, 56)),
    "slot_chest": (f"{A}/Icons.png", (359, 7, 376, 24)),
    "slot_gauntlets": (f"{A}/Icons.png", (194, 18, 206, 30)),
    "slot_boots": (f"{A}/Icons.png", (120, 7, 134, 24)),
    "slot_sword": (f"{A}/Icons.png", (311, 199, 328, 216)),
    "slot_bow": (f"{A}/Icons.png", (71, 231, 88, 248)),
    "slot_shield": (f"{A}/Icons.png", (24, 327, 39, 344)),
    "slot_dagger": (f"{A}/Icons.png", (311, 231, 328, 248)),
    "slot_axe": (f"{A}/Icons.png", (167, 295, 184, 312)),
    "slot_hammer": (f"{A}/Icons.png", (215, 295, 232, 312)),
    "slot_polearm": (f"{A}/Icons.png", (359, 263, 376, 280)),
    "slot_staff": (f"{A}/Icons.png", (407, 263, 424, 280)),
    "slot_tome": (f"{A}/Icons.png", (314, 327, 326, 344)),
    "slot_orb": (f"{A}/Icons.png", (216, 327, 231, 344)),
    "slot_wand": (f"{A}/Icons.png", (530, 274, 542, 286)),
    # Treasure sheet is a clean 32px grid: (col, row).
    "slot_ring": (f"{T}/Icons.png", 14, 1),
    "icon_key": (f"{T}/Icons.png", 0, 0),
    "icon_coins": (f"{T}/Icons.png", 1, 1),
    "icon_bag": (f"{T}/Icons.png", 8, 2),
    "icon_crown": (f"{T}/Icons.png", 1, 4),
}


def build_ui_icons():
    os.makedirs(UI_OUT, exist_ok=True)
    for name, spec in UI_ICONS.items():
        sheet = Image.open(os.path.join(SRC, spec[0])).convert("RGBA")
        if len(spec) == 3:
            col, row = spec[1], spec[2]
            cell = sheet.crop((col * 32, row * 32, col * 32 + 32, row * 32 + 32))
        else:
            x0, y0, x1, y1 = spec[1]
            icon = sheet.crop((x0, y0, x1, y1))
            # Centre the icon in a 32px cell so every slot draws at one size.
            cell = Image.new("RGBA", (32, 32))
            cell.paste(icon, ((32 - icon.width) // 2, (32 - icon.height) // 2), icon)
        cell.save(os.path.join(UI_OUT, name + ".png"))
    print(f"{len(UI_ICONS)} UI icons -> {UI_OUT}")


def crop_bbox(img):
    bb = img.getbbox()
    return img.crop(bb) if bb else img


def main():
    os.makedirs(OUT, exist_ok=True)
    manifest = {}
    for role, cfg in ROLES.items():
        variants = []
        for i, rel in enumerate(cfg["src"]):
            path = os.path.join(SRC, rel)
            if not os.path.exists(path):
                raise SystemExit(f"{role}: missing {rel}")
            img = crop_bbox(Image.open(path).convert("RGBA"))
            name = f"{role}_{i}.png"
            img.save(os.path.join(OUT, name))
            variants.append((name, img.width, img.height))
        manifest[role] = (cfg["scale"], variants)
    for role, cfg in CELLS.items():
        variants = []
        for i, (rel, x, y, w, h) in enumerate(cfg["cells"]):
            sheet = Image.open(os.path.join(SRC, rel)).convert("RGBA")
            img = crop_bbox(sheet.crop((x, y, x + w, y + h)))
            name = f"{role}_{i}.png"
            img.save(os.path.join(OUT, name))
            variants.append((name, img.width, img.height))
        manifest[role] = (cfg["scale"], variants)

    lines = [
        "class_name CraftpixProps",
        "extends RefCounted",
        "",
        "## GENERATED by tools/build_craftpix_props.py — do not edit by hand.",
        "## role -> {scale: base scale, variants: [{path, w, h}]}; sizes in texels.",
        "## The sprites live in assets/textures/craftpix/props/ (cropped pack art).",
        "",
        'const DIR := "res://assets/textures/craftpix/props/"',
        "",
        "const PROPS := {",
    ]
    for role, (scale, variants) in manifest.items():
        vs = ", ".join('{"path": DIR + "%s", "w": %d, "h": %d}' % v for v in variants)
        lines.append('\t"%s": {"scale": %.2f, "variants": [%s]},' % (role, scale, vs))
    lines += ["}", "", "",
              "static func has(role: String) -> bool:",
              "\treturn PROPS.has(role)", ""]
    with open(MANIFEST, "w") as f:
        f.write("\n".join(lines))
    print(f"{sum(len(v[1]) for v in manifest.values())} sprites in {len(manifest)} roles -> {OUT}, manifest {MANIFEST}")


if __name__ == "__main__":
    main()
    build_ui_icons()
