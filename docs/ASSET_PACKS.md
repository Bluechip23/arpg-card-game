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

All three share one format: **64×64 cells, 4 direction rows, one sheet per
animation**. Row order as observed on the Idle sheets is *up (back view),
down (front view), left, right* — confirm per sheet before hard-coding a
rig. Frame count = sheet width ÷ 64. `Parts/` holds the same sheets split
into layers (body, head, weapon, shadow, "red" = hit/blood overlay, etc.) for
recolouring or paper-doll work.

| Folder | Contents | Animations (frames) | Extras | Candidate use | Status |
|---|---|---|---|---|---|
| `giant_rat/Rat1..3` | 3 rat colour/size variants, top-down 4-dir | Idle 6 · Walk 6 · Run 6 · Attack 4 · Hurt 4 · Death 8 | `Parts/` incl. `*_Attack_swing` overlay; `shadow_single`, `shadow_death` masks | **Sewers, Act 1** — Wererat / Archer Rat / Swarm bodies; Rat King base body (crown + scale as boss variant, ART_TODO #3) | staged |
| `lich/Lich1..3` | 3 robed skeletal casters with staff, cyan magic | Idle 4 · Walk 6 · Run 6 · Attack 8 · Hurt 4 · Death 10 | `Fire.png` = 48×48 × 9 frames × 4 dirs cyan spell projectile/burst; `Parts/*_Attack_fire` | **Graveyard / Act 2 (Hell)** undead casters; necromancer elites; the `Fire.png` burst as a standalone spell VFX sheet | staged |
| `swordsman_lvl4_6/Swordsman_lvl4..6` | Armoured human swordsman, 3 gear tiers (lvl4 → lvl6 increasingly heavy) | Idle 12 · Walk 6 · Run 8 · Attack 7 · Walk_Attack 6 · Run_Attack 8 · Hurt 5 · Death 7 | Each attack has a `_nornal` (sic) variant without the yellow slash arc; `Parts/` splits body / head / sword / sword_back / red / shadow | Town guards & City defenders (`docs/STORY.md` §7, Sellsword raids); human bandit/knight enemies; possibly a paper-doll reference for Brad/Stephen combat outfits (ART_TODO #4). The slash-arc-free `_nornal` sheets + the arc-only difference are a route to the standalone slash VFX in ART_TODO #9 | staged |

Per-variant sheet dimensions (all 256 px tall = 4 rows):

| Anim | Rat | Lich | Swordsman |
|---|---|---|---|
| Idle | 384 | 256 | 768 |
| Walk | 384 | 384 | 384 |
| Run | 384 | 384 | 512 |
| Attack | 256 | 512 | 448 |
| Walk_Attack | — | — | 384 |
| Run_Attack | — | — | 512 |
| Hurt | 256 | 256 | 320 |
| Death | 512 | 640 | 448 |

## Craftpix object / icon packs

| Folder | Sheet | Grid | Contents | Candidate use | Status |
|---|---|---|---|---|---|
| `treasure_32x32/` | `chests.png` 320×128 | 32×32, 10 cols × 4 rows | 10 chest designs (wood, iron, gold, ornate, teal-crystal…) × 4 states per column (closed → open/lit) | Dungeon loot chests; act-themed chest tiers | staged |
| | `Icons.png` 480×224 | 32×32, 15 × 7 | Keys, coins, coin piles, gem shards, bags, sacks, pouches, jars, rings, orbs, potions, feathers, scrolls | Inventory / vendor / resource icons (base-builder resources sent home, currency, keys); card cost glyphs | staged |
| | `Objects.png` 320×240 | 16-px tile grid, most objects 32×32 | Chests, chains & hooks, ore / gem / gold piles, sacks, barrels of loot, candles & censers, coloured keys, key racks | Treasure-room and vault dressing (terrain decoration, ART_TODO #6); City treasury props | staged |
| | `Funiture.png` 96×256 | 32×32 grid, pieces up to 96×64 | Wooden shelves / display tables stocked with loot (5 variants + empty) | Vendor stall / shop interior dressing in Town; City buildings | staged |

## Not yet staged

Packs the user has still to upload go here as they arrive. When the set is
complete, the integration pass starts (see the *Candidate use* columns above
and `docs/ART_TODO.md` for what each one is meant to replace).
