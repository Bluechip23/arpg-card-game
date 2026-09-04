# ART_TODO — hand-drawn art genuinely required

Everything below needs a human pixel artist; programmatic conformance can't
produce it. Specs follow the style guide (`docs/STYLE_GUIDE.md`): master
palette only, ≤15 colors/sprite, upper-left light, hue-shifted ramps,
selective colored outlines, feet-anchored.

| # | Asset | Spec | Why |
|---|---|---|---|
| 1 | Bespoke battlers for placeholder variants: minotaur, hydra (multi-head), troll (×2: armored, ice), manticore, cerberus (3 heads), wyvern, bone dragon, grave titan, demon, ifrit, pit fiend, sabertooth, weregoat, harpy, wraith | 64×64/cell, single frame (battler convention), painted contact shadow only if flying, feet line ≈ row 56, anchor bottom-center | Currently tinted/hue-shifted reuses of other battlers (e.g. minotaur = red boar). Readable but not literal. |
| 2 | Fire goblin trio (soldier / mage / shaman) | 32×32 NPC-format walk sheets (4 dir × 4 frames, S/W/N/E rows) or 64×64 battlers | Currently hue-shifted frog battler. |
| 3 | Boss-scale battlers (Rat King crown variant, Corrupted Archangel, Granite Colossus) | multiples of 16 up to 96×96, bottom-center anchor | Tint/scale reuse today; bosses deserve silhouettes. |
| 4 | Knight/Merchant/Guard combat paper-doll outfits for the Mana Seed base | 512×512 sheets matching `char_a_p1`/`char_a_pONE1..3` layer format (1out layer), palette per NPC models | Would give Brad/Cory/Stephen true attack frames instead of the weapon-overlay mimic. (Or buy the full Character Base + armor add-ons.) |
| 5 | Staff & dual-dagger weapon layers (6tla) for pONE pages | 512×512, frame-aligned to `char_a_pONE3`, includes swing arcs (white crescent, `#f2fdff → #b6c5c5` fade) | Jeremy/Ryan currently swing sword/axe only. Available as paid Mana Seed add-ons. |
| 6 | Terrain decoration sprites: sewer pipes/grates/doors, torch (3–4 frame flame cycle), water tiles (3-frame cycle), bear-trap + dart-shooter hazards | 32×32 tiles / 32×48 props, environment ramps (mid-value band), painted top-light | Ground props (crates, barrels, rocks, shrubs, tufts, mushrooms, logs, reeds, trees incl. the climbable variant) are generated billboards now; the remaining mesh stand-ins are the sewer fixtures and trap hardware. |
| 7 | Themed tile variants: graveyard soil+headstones, sewer water edge, cave crystal, heaven marble, hell basalt | 128×128 sheets of 4×4 variant 32px tiles, grayscale ladder (≤8 values) if runtime-tinted, or ≤15 palette colors if authored in color | Current four generic sheets (grass/dirt/rock/brick) cover every act. |
| 8 | Bitmap font (UI milestone) + 9-slice pixel panels + card frame art & per-card artwork | font: 8×8 or 8×12 monospaced, 1× only; panels: 24×24 9-slice, palette colors | UI pass prerequisite. |
| 9 | Slash-arc directional VFX sheet (standalone) | 64×64 × 4 frames × 4 directions, additive-safe (white core `#ffffff` → `#f2fdff` → transparent), no outline | Pack crescents are welded to weapon frames; a standalone sheet unlocks VFX on NPC-model attacks. |
