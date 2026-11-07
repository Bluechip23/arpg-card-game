# Full audit — final report

Branches:
- `audit/full-pass-1`: Phases 0–6, one commit per phase.
- `audit/full-pass-2`: the second pass (Phase 7) and this report.

Detail pages:

| Page | What it holds |
|---|---|
| [`inventory.md`](inventory.md), [`inventory_generated.md`](inventory_generated.md) | Phase 0: the map of every script, scene, card, item, enemy, summon and passive |
| [`restructure.md`](restructure.md) | Phase 1: tech debt removed, and what is BLOCKED |
| [`wiring.md`](wiring.md) (+ [`wiring/`](wiring/)) | Phase 2: all 594 entities, each with a status and a test |
| [`environment.md`](environment.md) | Phase 3: collision vs art, and reachability on 13 maps |
| [`removed_town_building.md`](removed_town_building.md) | Phase 4: everything removed |
| [`needs_update.md`](needs_update.md) | Phase 5: outstanding content per enemy, character, summon and NPC |
| [`validation.md`](validation.md) | Phase 6: self-validation, and what I got wrong first |
| [`pass2.md`](pass2.md) | Phase 7: new findings from the second pass |

## Summary of changes

**Phase 1 — restructure (safe parts only, your call).**
- The sim is deterministic again: swing hold ran on a wall-clock timer.
- Added `scripts/shared/` with five helpers that replace copied code:
  - `status_badge_ui.gd`;
  - `pixel_raster.gd`;
  - `lab_menu_base.gd`;
  - `mesh_util.gd`;
  - `camera_pan.gd`.
- Removed 16 uncalled functions, 5 unused constants and one unused script.
- Gave every ranged enemy action's reach a named constant.
- Every step was byte-compared against the sim baseline. Behaviour is unchanged.

**Phase 2 — wiring audit.**
- All 594 entities were read against their text and traced: 255 cards, 189 items, 74 enemies, 60 passives, plus summons.
- Pass 1 ended with 493 CORRECT, 55 FIXED, 1 MISSING (built), 43 FLAGGED, 2 BLOCKED (both fixed in pass 2). The changes came with 12 new test files.
- Phases 6 and 7 then showed pass 1's CORRECT was too generous. See "Quality of the audit" below.

**Phase 3 — environment.**
- All 13 walkable maps were checked by script; caves and buildings were skipped.
- Found: no invisible blockers, no unreachable pockets, POIs or spawns, and no dead-end corridors.
- Flagged:
  - 48 open-sand wall cells in the World 4 desert;
  - 205 walk-through decorative props;
  - 13 procedural placeholder props.
- No collision was changed.

**Phase 4 — town-building end-game removed.** The city, its resources, buildings, satchel, expeditions, raids and trials are gone. The Town Hall stands as scenery, old saves load, and docs and `CLAUDE.md` are updated. The deletions are listed below.

**Phase 5 — outstanding content.** Per enemy, character, summon and NPC: art source, missing sheets, mock-ups and TODO actions.

**Phase 6 — self-validation.**
- Suite: 224/227. The 3 failures predate the audit.
- Clean boot, no new warnings, every moved file resolves, no town code left.
- An independent re-read of 21% of CORRECT rows found 9 wrong. 6 were fixed, with `test_recheck_fixes.gd`:
  - Petey the Pet Rock;
  - Premeditated;
  - Vined Encasing;
  - Mend;
  - Cryonics;
  - Friendship.

**Phase 7 — second pass.**
- Re-running Phases 1, 3 and 5 found nothing new in the code. The inventory now counts all 60 passives.
- An edge-path re-read of the other 396 CORRECT rows found 106 disagreements and 20 unclear. Four shared causes were fixed in shared code, with `test_pass2_fixes.gd`:
  1. **Point and area plays lost their on-hit item riders and life steal.** These now follow the enemies the play actually hit. This also fixes Phase 6's two BLOCKED rows, Life Steal and Fire Book.
  2. **A summon picked as the "ally" landed the effect on the caster.** Only the cards that handle a summon accept one now.
  3. **Summons took one step for a multi-tempo advance, and banked attacks while walking.**
  4. **"Drop below X%" triggers read the hit before armor.**
- Single fixes: Exhausted Assault, Communal Donation, Donate Cleats (the loan no longer saves), Frankenstein's Screws.
- **Suite after pass 2:** 226/229 pass. The same 3 failures predate the audit (`test_item_forge`, `test_sprite_imports`, `test_turtle_armor_anim`); the sim is still deterministic.

### Deleted

| What | Why |
|---|---|
| `scripts/city/city_state.gd`, `city_bridge.gd`, `expedition_system.gd`, `raid_system.gd`, `trial_system.gd` (each with its `.uid`) | Town-building end-game (Phase 4) |
| `tests/test_city_loop.gd`, `tests/test_city_wiring.gd` (+ `.uid`) | Tests of the removed city |
| `scripts/core/sheet_anim_sprite.gd` | Provably unreferenced (Phase 1): no script or scene uses it |

**No art, sound or scene was deleted.**

## Quality of the audit

The most important finding about the audit itself: **pass 1's CORRECT verdicts held up on the main path but not on the paths around it.**
- An 8% miss rate in the Phase 6 sample.
- 27% in the Phase 7 edge-path re-read (106 of 396).

The misses are concentrated in a few systems:
- point and area cards;
- summons as allies;
- co-op Player 2;
- buffs meeting themselves;
- bonuses written to fields a card never reads.

Those are listed below as BLOCKED and FLAGGED with plans. 22 confirmed single bugs from the re-read are not fixed yet; they are listed in `pass2.md` under OPEN and are the next work item.

## Every FLAGGED and BLOCKED item

### BLOCKED

| Item | Why | Plan | Where |
|---|---|---|---|
| Enemy behaviour as data (66 creatures) | Your call: safe parts only. It would rewrite all combat AI. | `EnemyActionDef` resources; generic shapes first, gated by the sim | `restructure.md` |
| Card effects as reusable effect scripts | Same call. One card's behaviour is split between `card.gd` and `main.gd`. | Effect-primitive resources; data-only cards first | `restructure.md` |
| Splitting `main.gd` (17.6k lines) | Large, though behaviour-neutral | Lift self-contained regions into child scripts, one gated commit each | `restructure.md` |
| One status system for player and enemies | Changes timing edge cases (Wither, Mark) | Decide what a "charge" means first | `restructure.md` |
| Point/area plays: riders that still read the single `target` (12 rows + 3 halves) | Each check sits in a different place | Move each to the per-enemy hit list, one item per commit | `pass2.md` |
| Co-op: Player 2 / the inactive hero (16 rows) | Inventory ticks, per-cycle passives and ring / deck / damage signals are wired for Player 1 or the controlled hero only | Route every per-hero tick and signal through both heroes, with a co-op test per item | `pass2.md` |
| Generic bonuses a card never reads (6 rows) | +block, +damage, +heal written to fields some executors ignore | Executors read effective values; decide "+block on a card that blocks nothing" with you | `pass2.md` |
| Card faces don't show item-level numbers (3 rows), and Lv.2 item text 1 low (~10 items) | Display text is static | Card and item text read the item's level | `pass2.md` |
| Girdle of Aphrodite's +15 on a summon heal | The rider reads hero stats only | Part of the generic-bonus plan | `pass2.md` |

### FLAGGED (questions for you)

**Wiring, pass 1** (`wiring.md`, by slice):
- **Cards:**
  - Whirling Weapon, Death Vortex, the Overcharge-only overflow;
  - Element Pollination, Mana Surge, Last Breath, Life Swap, Hope This Works, Mark, Misery Loves Company, Morphine;
  - Push, Quick Arrow, Return Cut, Rise's procedural pillar;
  - Smith Thy Soul, Song of a Sword's Sing, Wear Down.
- **Enemies:**
  - Fire Goblin Soldier, Mini Bear, Screecher;
  - Granite Colossus's empty kit;
  - Spirit Bow (does a bow count itself?);
  - the manifest spirit/golem;
  - flat sheet numbers vs the level-band note.
- **Items:**
  - Bessy, Bloodbound Plate, Boomerang;
  - Laurentius' Lost Spear, Nine Ruins of Sanguine;
  - quivers in the off hand, Wrist Rocket's quiver pairing, Rope Half Sleeve's +3.
- **Passives:** Vines Codependence, Wither, Expel Negativity, Regrowth, Mana Surge, Mad Scientist, Elemental Conclusion.

**Re-check, Phase 6** (`validation.md`):
- Cryonics / Friendship and summons;
- Now You See Me (Charge, the Repelled push);
- Hallowed Trunk (armor decay);
- Whispers of the Flock (which heals count);
- mana units in card text.

**Pass 2** (`pass2.md`):
- **Buff meeting itself** (one rule, 8 rows): Shield Ready, Best Offense, Protection From Alnitak, Tight Rope, Belt of Wumbology, Understanding, Endured Tolerance, Dominate.
- **Mana units:** Energy, Give In, Enchantment: Mana Regen, Specific Strike.
- **Level-band note:** Bugbear, Earth Totem, Sabertooth, Sewer Cobra, Succubus, Weregoat.
- **Co-op inactive-hero pausing:** Close is Favored, Defensive Sacrifice, Enchantment: Attack / Movement.
- **Ambiguous text:** Enchanted Quiver, Sky Attack, Smoke Bomb, Hydra, Shepherd's Crook, Side Card Sabre, Smithed Excellence, Easy Target, Let's Dance, Territorial Death, Turtle Power.

**Environment** (`environment.md`):
- the World 4 desert's open-sand edges;
- walk-through decorative props;
- walkable fountains;
- the Boneyard arch.

**Restructure** (`restructure.md`): unused exported fields kept because saves serialise them: `fire_resistance_percent`, `movement_per_tempo_bonus`, `sprite_sheet_path`.

## Outstanding content

[`needs_update.md`](needs_update.md) lists what is still a mock-up or missing, per entity:
- the bosses with no kit (Granite Colossus, Pit Fiend, Corrupted Archangel);
- enemies whose actions have no animation board;
- art from outside the packs;
- characters, summons and NPCs.

---

## Suggestions (new ideas, not built)

Each idea is based on something the audit found in the code.

### Five new enemy moves

The roster has 10 Async actions and 11 Trigger actions, but **only one Channel action and one Disruptable action**: the Ifrit's Fire Wall (`channel: 4, disrupt: 8`). And **no card interacts with an enemy's wind-up**. The tempo design's most interesting levers are barely used. These moves use them.

| Enemy | Move | Tempo | What it does | Counterplay |
|---|---|---|---|---|
| **Granite Colossus** (boss, empty kit today) | *Tectonic Slam* | 6 wind-up, **Channel 3**, **Disrupt 25** | Raises a 3×3 of high ground under itself, then slams it; anyone on the ring is knocked off and Staggered | Burst 25 damage into it during the channel to break it, or step off the ring before it lands. It rewards saving a big card. |
| **Grave Titan** | *Bury* | 8, **Channel 4** | Every other clock pauses while it sinks a gravestone onto the player's tile; the stone becomes an obstacle with a Gravestone's hits | Move off the tile during the channel. Its pause also freezes its attack clock, a window to hit it freely. |
| **Cerberus** | *Three Heads Watch* | **Trigger: player plays a card costing 5+ tempo** | One head snaps for 8 the moment a long card is queued (once per cycle per head) | Play short cards while he's close, or bait the trigger with a cheap 5-tempo card first. It pressures the slow-card build. |
| **Sabertooth Tiger** | *Stalk* | Async, 10 | Its clock fills 1 faster for each tile the player walks; at the end it pounces from up to 5 tiles | Stand and block instead of kiting; the clock fills on its own pace when you don't move. Punishes running, not fighting. |
| **Mind Eater** | *Thought Leech* | Async, 6, **Disrupt 10** | Adds +1 tempo to the most expensive card in the player's hand, up to +3 per card, until the Mind Eater dies | Kill it fast, or hit it for 10 to restart its clock. It fits a Trash-tier caster that taxes tempo rather than health. |

### Five new cards

| Card | Tempo | Effect | Gap it fills |
|---|---|---|---|
| **Feint** | 2 | An enemy within 3 restarts the clock of the action it's winding up | No card touches an enemy's wind-up today; the methodical enemies make reading wind-ups the key skill |
| **Counter-Clock** | 4 | Deal 6 damage, +2 for each tempo left on the target's current wind-up | Rewards hitting an enemy early in its wind-up instead of late, a tempo decision with no card today |
| **Cut the Channel** | 3 | Deal 10; against a channeling enemy, the hit counts double toward Disruptable and the channel ends | Gives every hero a way to answer Channel actions, which the new moves above would need |
| **Web Cutter** | 1 | Clear every hazard tile within 2 (floor webs, Bear Traps, flame zones) and gain 1 movement | Floor webs, traps and zones are now common (Crypt Crawler webs land on the floor) and nothing removes them |
| **Patient Guard** | 3, Maintain | While maintained: each tempo you don't move, gain 1 armor (cap 10); moving drops it to 0 | Supports the "stand and block" counterplay the Stalk and slam moves ask for, without a new mechanic |

### Five quests gated on an item or ability

Each sits in an existing region and rewards a new option, not a number.

| Quest | Region | Gate | Reward |
|---|---|---|---|
| **The Ridgeline Cache** | World 1 Mountains | **Climbing gear.** The climbing rule already checks `PlayerStats.climbs_cliffs` (`player.gd`, `main.gd`), but no item sets it. A vendor's climbing harness would. | A cliff-top cache with the **Sky Attack** high-ground card line, and climbing kept as a permanent traversal option on every map |
| **Low Tide at the Drowned Shrine** | World 1, the Drowned Shrine (already a quest site, `main.gd` "The Drowned Shrine") | **Poseidon's Trident.** Its Wrath of the Sea shoves every enemy to the burst's edge; used on the shrine's sluice it drains the flooded nave. | Access to the shrine's lower room and a water-themed enchantment card |
| **The Thread Through the Maze** | World 2, the Labyrinth | **Heroic Leap** or a Blink card: a collapsed corridor only a leap crosses | A shortcut waypoint inside the Labyrinth (world continuity) and a Minotaur-horn trinket that adds Knockback to one slotted card |
| **The Bound Ones** | World 1, the Boneyard | **Release Soul** (the Spirit Collector's card) played beside three bound spirits | The spirits become Seance Specters you can call once per cycle: a permanent summon option for every hero |
| **Ember Walk** | World 2, the lava court (`water_lava.png` pools at Hell's threshold) | **Fire-resistant gear.** `ItemData.fire_resistance_percent` is an exported field nothing reads; 50%+ would let you wade lava. | A path through the court to a forge that can add a Burn rider to one weapon slot |
