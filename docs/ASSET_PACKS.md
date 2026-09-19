# ASSET_PACKS — purchased art staged for integration

Inventory of third-party packs that have been imported into the repo but are
**not yet wired into any scene or script**. This is the "arsenal": when a pack
gets used, note where in the last column and, if it replaces a placeholder,
strike the matching row in `docs/ART_TODO.md`.

Conventions for every pack staged here:

- Only runtime files are committed: PNG sheets, per-layer PNG parts, shadow
  masks and the vendor `License.txt`. Source files (`.psd`, `.aseprite`,
  Tiled `.tmx`/layer exports) stay in the original zips — they are not tracked.
- Godot `.import` metadata is generated headless and committed alongside, same
  as the existing packs (lossless, no mipmaps, no filter).
- Sheets are used 1:1 — see `docs/STYLE_GUIDE.md` §1/§5 for texel density and
  the feet-anchored billboard rule. All Craftpix character packs draw their
  own soft shadow; use the `Without_shadow/` sheets and let the blob shadow
  (`assets/textures/blob_shadow.png`) do that job.
- Craftpix license: <https://craftpix.net/file-licenses/> (copy in each folder).

## Craftpix character packs (`assets/sprites/craftpix/`)

All Craftpix character packs share one format: **square cells (64×64, or
128×128 for the rats, demons and golems — cell = sheet height ÷ 4), 4
direction rows, one sheet per animation**, three colour/gear variants per
pack. Frame count = sheet width ÷ cell size. `Parts/` holds the same sheets split into layers (body, head,
weapon, shadow, "red" = hit/blood overlay, spell FX, etc.) for recolouring
or paper-doll work.

**Direction row order** (checked on idle frame 0 of every row, all nine
character packs): *front (faces the camera), back, left, right* — the same
in every pack. An earlier eyeball pass had the rats and liches reversed; it
was wrong. The rig keeps a per-pack map anyway (`SpriteEnemyFigure.CP_ROWS`)
so a future pack that differs is a one-line fix.

| Folder | Contents | Animations (frames) | Extras | Candidate use | Status |
|---|---|---|---|---|---|
| `giant_rat/Rat1..3` | **128×128 cells** (small bodies, ~30 px). 3 rat colour/size variants, top-down 4-dir | Idle 6 · Walk 6 · Run 6 · Attack 8 · Hurt 4 · Death 5 | `Parts/` incl. `*_Attack_swing` overlay; `Shadow_single`, `Shadow__attack` masks | **Sewers, Act 1** — Wererat / Archer Rat / Swarm bodies; Rat King base body (crown + scale as boss variant, ART_TODO #3) | **in game**: `rat` = Rat1, `archer_rat` = Rat1 (dark tint), `rat_king` = Rat3 ×1.7 (`SpriteEnemyFigure`); Rat2 (the winged black rat) is unused so far |
| `lich/Lich1..3` | 3 robed skeletal casters with staff, cyan magic | Idle 4 · Walk 6 · Run 6 · Attack 8 · Hurt 4 · Death 10 | `Fire.png` = 48×48 × 9 frames × 4 dirs cyan spell projectile/burst; `Parts/*_Attack_fire` | **Graveyard / Act 2 (Hell)** undead casters; necromancer elites; the `Fire.png` burst as a standalone spell VFX sheet | **in game**: `necromancer` = Lich2 (crowned), `spirit_collector` = Lich1 (cold tint); Lich3 (gilded) is free for a boss |
| `swordsman_lvl4_6/Swordsman_lvl4..6` | Armoured human swordsman, 3 gear tiers (lvl4 → lvl6 increasingly heavy) | Idle 12 · Walk 6 · Run 8 · Attack 7 · Walk_Attack 6 · Run_Attack 8 · Hurt 5 · Death 7 | Each attack has a `_nornal` (sic) variant without the yellow slash arc; `Parts/` splits body / head / sword / sword_back / red / shadow | Town guards & City defenders (`docs/STORY.md` §7, Sellsword raids); human bandit/knight enemies; possibly a paper-doll reference for Brad/Stephen combat outfits (ART_TODO #4). The slash-arc-free `_nornal` sheets + the arc-only difference are a route to the standalone slash VFX in ART_TODO #9 | staged |
| `demons/Demon1..3` | **128×128 cells.** Horned purple imps with pitchforks / spears, 3 variants | Idle 4 · Walk 6 · Run 8 · Attack 10 · Hurt 4 · Death 13 | `Parts/*_Attack_fire` spell overlay, `*_Death_Death_effects`; `Shadow.png` | **Act 2 (Hell)** — Demon / Pit Fiend / Ifrit placeholders in ART_TODO #1; twice the cell size of the 64-px packs, so a natural "big enemy" tier | **in game**: `demon` = Demon1, `ifrit` = Demon2 (fire tint), `pit_fiend` = Demon3 |
| `golem/Golem1..3` | **128×128 cells.** Hulking rock / clay / crystal golems, 3 variants | Idle 4 · Walk 8 · Run 8 · Attack 9 · Hurt 4 · Death 8 | `shadow.png` 64×48 | Caves; Granite Colossus boss body (ART_TODO #3) and grave-titan / troll stand-ins (ART_TODO #1) | **in game**: `granite_colossus` = Golem1 (brown rock) ×1.6, `grave_titan` = Golem2 (bone-white crystal) ×1.35; Golem3 (blue armoured, fire core) is free |
| `ghost/Ghost1..3` | Floating blue spirits, 3 variants. Attack is a two-phase dive: shrouds into a black shade, then bursts | Idle 4 · Walk 6 · Run 6 · Attack 12 · Hurt 4 · Death 9 | `Shadow_single`, `Shadow_death` | Wraith / harpy-type flyers (ART_TODO #1); Graveyard & Cemetery haunts; Act 3 (Heaven) lost souls | **in game**: `specter` = Ghost1, `snow_wraith` = Ghost2 (ice tint) |
| `gnolls/Gnoll1..3` | Hyena-men brawlers, 3 fur variants. **Gnoll1's Death sheet is misnamed `Gnoll_Death_*`** (no variant number) | Idle 4 · Walk 6 · Run 8 · Attack 10 · Hurt 4 · Death 6 | `Shadow_single`, `Shadow_death` | Greenwood / wilds beast-men; weregoat stand-in (ART_TODO #1); raid attackers on the City | **in game**: `bugbear` = Gnoll2 (dark, armoured), `weregoat` = Gnoll3 (white-furred) |
| `zombie/Zombie1..3` | Shambling undead, 3 variants | Idle 4 · Walk 6 · Run 8 · Attack 10 · Hurt 4 · Death 9 | `Shadow.png` | Graveyard (Act 1 Part 2) fodder alongside the existing Skeleton; Hell footsoldiers | **in game**: `zombie` = Zombie1, `infected_hunter` = Zombie3 |
| `lizardmen/Lizardman1..3` | Sword-armed lizardfolk, 3 scale colours | Idle 4 · Walk 6 · Run 8 · Attack 7 · Hurt 5 · Death 7 | `Shadow_single`, `Shadow_death` | Sewer / cave depths (the "croc" tier after the Rat King); swamp encounters | staged |
| `slime/Slime1..3` | Blob slimes with an ice-shard spit attack, 3 colours | Idle 6 · Walk 8 · Run 8 · Attack 10 · Hurt 5 · Death 10 | — (no separate shadow masks) | **Sludge Being** (Sewer ranged ooze) body; cave slimes | Variants are ice (1), lightning (2) and fire (3) slimes. **in game**: `sludge` = Slime1 ×1.6 tinted to a green ooze |

Per-variant sheet widths in px (height = 4 rows × cell; 64-px packs are
256 tall, the two 128-px packs are 512 tall):

| Anim | Rat | Lich | Swordsman | Ghost | Gnoll | Zombie | Lizardman | Slime | Demon (128) | Golem (128) |
|---|---|---|---|---|---|---|---|---|---|---|
| Idle | 384 | 256 | 768 | 256 | 256 | 256 | 256 | 384 | 512 | 512 |
| Walk | 384 | 384 | 384 | 384 | 384 | 384 | 384 | 512 | 768 | 1024 |
| Run | 384 | 384 | 512 | 384 | 512 | 512 | 512 | 512 | 1024 | 1024 |
| Attack | 256 | 512 | 448 | 768 | 640 | 640 | 448 | 640 | 1280 | 1152 |
| Walk_Attack | — | — | 384 | — | — | — | — | — | — | — |
| Run_Attack | — | — | 512 | — | — | — | — | — | — | — |
| Hurt | 256 | 256 | 320 | 256 | 256 | 256 | 320 | 320 | 512 | 512 |
| Death | 512 | 640 | 448 | 576 | 384 | 576 | 448 | 640 | 1664 | 1024 |

## Craftpix object / icon packs

| Folder | Sheet | Grid | Contents | Candidate use | Status |
|---|---|---|---|---|---|
| `treasure_32x32/` | `chests.png` 320×128 | 32×32, 10 cols × 4 rows | 10 chest designs (wood, iron, gold, ornate, teal-crystal…) × 4 states per column (closed → open/lit) | Dungeon loot chests; act-themed chest tiers | staged |
| | `Icons.png` 480×224 | 32×32, 15 × 7 | Keys, coins, coin piles, gem shards, bags, sacks, pouches, jars, rings, orbs, potions, feathers, scrolls | Inventory / vendor / resource icons (base-builder resources sent home, currency, keys); card cost glyphs | staged |
| | `Objects.png` 320×240 | 16-px tile grid, most objects 32×32 | Chests, chains & hooks, ore / gem / gold piles, sacks, barrels of loot, candles & censers, coloured keys, key racks | Treasure-room and vault dressing (terrain decoration, ART_TODO #6); City treasury props | staged |
| | `Funiture.png` 96×256 | 32×32 grid, pieces up to 96×64 | Wooden shelves / display tables stocked with loot (5 variants + empty) | Vendor stall / shop interior dressing in Town; City buildings | staged |
| `armor_weapons_icons/` | `Icons.png` 576×352 | 32×32, 18 × 11 | ~200 equipment icons: helms, chests, gloves, boots, capes (rows 1–5), swords, daggers, bows, staves, axes, maces (rows 6–10), shields & orbs (row 11) | Equipment item icons for the inventory / vendor / loot UI — a consistent set to replace or complement the hand-made `assets/items/` art | staged |
| | `Armor.png` 896×160 | 32×32, 28 × 5 | Same armour pieces shown worn on a mannequin bust, front / side / back (paper-doll preview strips) | Equipment preview panel; reference for combat paper-doll outfits (ART_TODO #4) | staged |
| | `Weapons.png` 384×96 | 32×32, 12 × 3 | Weapons drawn at rest angle (blades, polearms, bows, shields) | Weapon-slot icons; drop sprites on the ground | staged |
| | `Furniture.png` 96×320 | 32×32 grid, pieces up to 96×64 | Armour stands, weapon racks, display tables | Blacksmith / armoury interior dressing in Town and the City | staged |

## Craftpix top-down tilesets (`assets/sprites/craftpix/tileset_*/`)

All six use a **16×16 tile grid** (their Tiled maps are 16 px; most props
occupy 32×32 or larger). Each ships a `Ground*.png` terrain sheet, an
`Objects.png` prop atlas, `Water_coasts.png` shoreline transitions, and a
pack-tinted `water_detilazation(.v2).png` 688×576 animated water sheet (the
water sheets are recoloured per pack, not duplicates). `Objects_separat*/`
holds every prop as its own PNG, most in two shadow strengths
(`*_light_shadow` / `*_dark_shadow`) and animated props as `_frameN` series
— the easiest source for billboard props under the current 3D-scene
architecture (STYLE_GUIDE §1). Terrain sheets are 1 world unit = 32 texels in
the project, so 16-px tiles need pairing 2×2 or an authored 32-px re-cut.

Note the project's rule (STYLE_GUIDE §4) that props get the blob shadow, not
a baked one: prefer the `light_shadow` variants or the source atlases and
budget for masking the painted shadow out when a prop is promoted to a
billboard.

| Folder | Key sheets | Contents | Candidate use | Status |
|---|---|---|---|---|
| `tileset_cave/` | `ground_source` 1088×128 · `Objects_source` 976×416 · `Objects_animated*_source` · `water_n_lava_coasts_source` 384×768 · `lava_detilazation_source` · `bubbles_source` · `spots_source` · 259 separate props | Dark cave floor & wall pieces, stalagmites (grey / black), coloured crystal clusters (blue, green, red, orange, yellow), glowing mushrooms, giant spider & webs, **animated volcano vents / lava, water rocks**, iron gates, and a 6-frame animated **demon head / hands / tail** emerging from the ground | **The Caves** (Act 1 Part 3, already built as mesh stand-ins) — cave crystal tile variant (ART_TODO #7), decoration sprites (ART_TODO #6); lava + demon fixtures for the **Act 2 Hell** threshold | **in game**: cave floor + cave walls (`floor_cave`, `wall_cave`) |
| `tileset_glowing_cave/` | `Ground` 304×384 · `Objects` 560×288 · `Details` 160×592 · `Water_coasts` 288×480 · `Shinies_animation` 480×192 · `Totem_animation` 576×176 · `Wisp1..3` · 60 separate props | Bioluminescent cave: teal / violet fungi, glowing eggs & pods, coiled crystal serpent, lizard, hanging vines, **animated wisps and glowing totem**, sparkle overlay | Deeper cave biome / Heaven-adjacent luminous zones; the wisps double as ambient critters (`sewer_critter.gd` pattern) | staged |
| `tileset_cursed_land/` | `Ground` 720×560 · `Objects` 784×704 · `Water_coasts` 416×960 · `bridges` 672×304 · `details` · `spots` · 138 separate props | Flesh-and-vein hellscape: eye-plants, jaw plants, meat flowers, pustules, tentacle plants, fetus pods, bone piles, veins, cursed rocks, ruins, flesh bridges | **Act 2 — Hell** ground & set dressing (hell basalt tile variant, ART_TODO #7); calamity "corruption" spreading toward the City | **in game**: World 4 Emberfall floor (`floor_cursed`) |
| `tileset_undead_land/` | `Ground_rocks` 496×592 · `Objects` 768×704 · `Water_coasts` 1056×256 · `Details` 576×176 · `Animation1..6` · 240 separate props | Graveyard / barrow land: crowned giant skeleton half-buried (3 poses), iron fences & gates, dead trees (**Animation1 = 6-frame swaying dead tree**, others: candles, ghostfire, bones), skull piles, ribcages, rocks, candles, grave markers | **Graveyard / Cemetery** (Act 1 Part 2 `[TBD]` in STORY.md) — graveyard soil + headstones (ART_TODO #7); Lich / Zombie / Ghost habitat | **in game**: World 5 Umbral Expanse floor (`floor_undead`) |
| `tileset_forest/` | `Ground_grass` 304×368 · `Objects` 816×272 · `Water_coasts` 238×768 · `Water_lilis` 240×192 · `spots_lianas` 336×544 · 89 separate props | Temperate forest: 14 tree types incl. climbable-looking canopies, bushes, stones (beige / brown / light), ruins (grass / orange), broken trees, mushrooms, reeds, lily pads, lianas | **The Greenwood** (Act 1 Part 3, built) — replaces generated billboard trees / shrubs / mushrooms / logs / reeds, climbable tree variant; forest ruins for quest sites | **in game**: Greenwood floor + trails (`floor_grass_forest`, `floor_dirt_forest`) |
| `tileset_grassland/` | `ground_grasss` 336×256 · `Trees_rocks` 256×544 · `Water_coasts` 272×576 · `Details` 192×224 · 76 separate props | Open glades: 5 trees (incl. fruit tree), 19 bushes, 11 flowers, rock outcrops, and **overgrown stone ruins / walls / arches** | World 1 overworld around Town; the ruin walls are a strong fit for **City walls & expansion plots** (base builder) | **in game**: World 1 floor + trails (`floor_grass_field`, `floor_dirt_field`) |

## Integration notes

- **Terrain fills.** `tools/extract_craftpix_tiles.py` cuts each tileset's
  interior 16-px fill tiles and composes them into 4×4 × 32-px variant
  sheets (`assets/textures/craftpix/`). The autotiled ground
  (`DungeonManager._build_autotile_ground`) assembles its runtime atlas from
  those sheets — 16 plain variants per terrain for open ground, plus 16
  edge-mask tiles whose transition bands are still painted from the
  palette. Cutting the packs' own edge pieces, coasts and prop atlases into
  those mask columns is the next step, as is scattering the `Details.png`
  grass overlays (the pack grass fills are two flat tiles).
- **Enemy rigs.** `SpriteEnemyFigure` plays the Craftpix sheets with real
  frames (idle / walk / run / attack / hurt / death). The direction row map
  is `SpriteEnemyFigure.CP_ROWS`. The `Without_shadow` sheets are used with
  the project's blob shadow (style guide §4). Variant picks and scales are
  in the `KINDS` table; `tests/_capture_sprite_bestiary.gd` renders them
  for review.
- **Camera.** The fixed top-down three-quarter view (`CameraView`) is what
  all of this is drawn for; see the style guide §0.

## Staging log

| Batch | Packs |
|---|---|
| 1 | giant_rat, lich, swordsman_lvl4_6, treasure_32x32 |
| 2 | demons, ghost, gnolls, zombie, lizardmen, slime, golem, tileset_cave, tileset_glowing_cave, tileset_cursed_land, tileset_undead_land, tileset_forest, tileset_grassland, armor_weapons_icons |

## Not yet staged

Packs the user has still to upload go here as they arrive. When the set is
complete, the integration pass starts (see the *Candidate use* columns above
and `docs/ART_TODO.md` for what each one is meant to replace). Cross-pack
groundwork to do first: a per-pack direction row map (see above) and a
16-px → 32-px tile re-cut convention for the tilesets.
