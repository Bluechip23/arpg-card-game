# Phase 6 — self-validation

Checked on `audit/full-pass-1` after Phases 0–5. The headline: the code checks came out clean, but the Phase 2 wiring audit was not as reliable as its tables claimed. An independent re-read of a fifth of its CORRECT rows found **9 of 108 (8%) wrong**. Six are fixed below. Two are BLOCKED on one shared cause. One was already a designer question, so it stays flagged. The rest of the CORRECT rows get the same re-read in Phase 7 (`audit/full-pass-2`).

## 1. Full test suite

`tests/run_all.sh -j 3`: **227 tests, 224 pass, 3 fail.** All three fail the same way on the commit before the audit started (`00c00b22~1`). The audit did not cause them:

| Test | Why it fails (unchanged since before the audit) |
|---|---|
| `test_item_forge` | "copies holding enchanted cards are not fodder", "not enough clean copies -> blocked". Forge fodder rules. |
| `test_sprite_imports` | 8 hero attack/block sheets under `smooth/heroes/` have import settings the test does not allow. |
| `test_turtle_armor_anim` | The Battle Turtle has no Armor sheet in the smooth set. |

After the Phase 6 fixes below, the 25 tests that touch the changed code were re-run, plus the new `test_recheck_fixes.gd`. All pass.

## 2. Errors and warnings

- **Game boot:** `main.tscn`, headless, 600 frames. 0 errors, 0 warnings.
- **Test logs:** every remaining line is one of these:
  - teardown noise: "ObjectDB instances leaked", "resources still in use at exit", RID leaks;
  - the synthetic "Minion" enemy in `test_enemy_action_keywords`, whose made-up actions log "Unknown action" on purpose;
  - the two enemies that are design mock-ups and say so (Pit Fiend, Corrupted Archangel).

  The six tests with RID-leak lines were run on the pre-audit commit and print the same lines in the same numbers. No warning is new.
- **One new error, now fixed:** `test_wiring_cards_a.gd`, a Phase 2 test, printed "String formatting error" twice. Two check messages had a bare `50%` inside a `%`-formatted string. The checks still ran, but their messages were lost. Fixed (`50%%`).

## 3. Moved files resolve, duplicates are gone

- Every `res://` path named in `scripts/`, `scenes/`, `tests/`, `tools/` and `project.godot` exists, except two:
  - `sim_out/sphere_grid.json` is an output file the dump writes;
  - `generated/npcs/ninja.png` is named by `test_pack_art_only` only to check that it is gone.
- The Phase 0 inventory re-run shows 0 dead functions. The only duplicated bodies left are the two accepted idioms in `restructure.md` (`toggle_panel`, `_refresh`).

## 4. No town-building code remains

A grep of every script, scene and resource finds no city/satchel/trial/calamity/expedition/raid/depot code. What still mentions the town loop:
- `progression_io.gd`: `RETIRED_CITY_KEYS`, which erases the old save keys so old saves load;
- `test_retired_city_saves.gd`, which proves that;
- two tests that check the removed pieces stay removed (`test_quests`: Trial Warning is gone; `test_escort_quests`: no depot appears).

The Town Hall is scenery (`town.gd _build_town_hall`).

## 5. Re-check of the CORRECT rows

**Method.**
- 108 of the 505 CORRECT rows (21%) were drawn at random (Python `random.sample`, seed `20261107`): 48 cards, 34 items, 15 enemies, 8 passives, 3 summons.
- Three verifiers worked on a third each.
- None could open `docs/audit/` or the `test_wiring_*` tests. Each found the entity's player-facing text, traced its code path from scratch and gave a verdict.

**Result: 91 agree, 9 disagree, 8 unclear.** I checked every disagreement against the code before acting on it.

| Entity | What was wrong | Now |
|---|---|---|
| Petey the Pet Rock | "While in hand: Slowed 2". The slow only went on at a cycle boundary, fell to 1 stack between cycles, and stayed after Petey left the hand. | **FIXED.** `main._sync_held_slow` follows the card in and out of the hand, the same way Release Soul's Drain works. |
| Premeditated | "your next card targeting that enemy deals +15". A second Premeditated didn't count as that card. | **FIXED** |
| Vined Encasing | "lose X thorns whenever you receive X damage". Merged with thorns already up (Spiked Mitts…), it lost that rule. Ordinary thorns gained afterwards picked it up instead. | **FIXED.** `Buff.vined_value` keeps the two shares apart inside one Thorns buff. |
| Mend | "Allies within 4 squares restore 20%…". It skipped every summon except Frankenstein's Monster. | **FIXED.** Every friendly summon in range is restored. |
| Cryonics | "Encase an ally". Picking a summon encased and stunned the caster. | **FIXED** (a summon pick is refused, nothing spent) + **FLAGGED** (see below). |
| Friendship | "Choose two allies". Picking a summon made the caster the first ally. | **FIXED** (refused, nothing spent) + **FLAGGED** |
| Life Steal (passive) | "All attacks life steal". It heals at least 1 even when the attack hits nothing, and an area attack steals from only one hit. | **BLOCKED** (below) |
| Fire Book | "Your damaging offensive cards apply 1 Burn". Area and point cards get the +1 damage but never the Burn. | **BLOCKED** (below) |
| Bow of Budding Blasts | "+2 damage and +5% crit per living bow summon". Damage counts the other bows, crit counts every bow. | **Already FLAGGED** in Phase 2 (`wiring/enemies_b.md`): counting the bow itself would break the Spirit Bow card's "10-damage shot". The designer has to pick one. I briefly changed it and reverted. |

`tests/test_recheck_fixes.gd` proves each fix. The Cryonics/Friendship check was confirmed to fail with the guard taken out.

**BLOCKED: Life Steal and Fire Book.**
- Cards aimed at one enemy resolve in `card.gd` and record `last_damage_dealt`. The item and passive riders read it.
- Area and point cards resolve in `main.gd`, each in its own hit loop, with no record of what they hit. So the riders either fall back to the printed damage (Life Steal) or are skipped (Fire Book).
- Fixing one card at a time would leave the rest wrong.
- **Plan:** give `Card` a per-play hit log, `record_hit(enemy, dealt)`, called from each `main.gd` area loop. Run the on-hit riders (Burn and the other spell-weapon riders, Life Steal from the summed damage) once per logged enemy, and skip them when the log is empty. Gate it with the full sim sweep, because it changes area-card numbers.

**New FLAGGED questions** from the unclear verdicts:
1. **Cryonics / Friendship.** Is a summon an "ally" for these two? Both act on a hero's stats, so summons are refused for now. Also: in solo play with no partner, Friendship has no second ally.
2. **Now You See Me.** "blinking, being swapped, or other non-standard movement": Roll and Heroic Leap count; Charge and the Repelled Block push do not. Should they?
3. **Hallowed Trunk.** "Every 10 armor removed": only armor that hits take counts, not the 2-per-cycle armor decay. Should decay count?
4. **Whispers of the Flock.** "When you heal an ally": only cards with a printed heal count. Communal Donation, Mend and Halo's per-cycle heals never grant the Mark. Should every heal count?
5. **Mana units in card text** (Bloodlust, Anticipation, Fountain of Health, Armored Discipline, Cultish Wounds, Halo). "Gain 3 mana" adds 30 on the bar. This was already flagged in `wiring/cards_a.md`; the re-check found more cards with the same split.

Smaller notes the verifiers made, which agree with the text:
- Release Soul's "1 damage per tempo" lands as 5 once per cycle.
- Mend at item level 3 restores 40% (the item's own text says so).
- Hard Helmet reads the raw Utility card type, not the `utility` tag (only Healthy Bliss differs).
- Cover's "within 2 spaces" is a straight-line distance, so a square two steps diagonally away is out of range.
- The Ice Totem's code comment still says it Slows each cycle; it doesn't, and neither does its text.

## 6. What I got wrong the first time

1. **The wiring audit's CORRECT rows had about an 8% miss rate.** The slice audits mostly proved the main path of each description (one target, one hit, a fresh state). The misses are all edge paths: a buff merging with one already up, a summon as the "ally", area cards, the card leaving the hand, a second copy. Phase 7 re-reads every CORRECT row not sampled here, looking for exactly those paths.
2. **Bow of Budding Blasts.** While fixing, I "fixed" a row that Phase 2 had correctly flagged as two texts in conflict. I caught it when updating the report and reverted it. Where two texts disagree, the designer decides.
3. **`test_wiring_cards_a.gd`** shipped two unescaped `%` signs (§2).
4. **`tools/audit/inventory.py` drops passive ids with an apostrophe** (`a_mage's_favor`, `let's_dance`). So `inventory.md` counts 58 passives, not 60. Both passives were still audited, because Phase 2 worked from the passive reference itself. To be fixed in Phase 7.
5. **The Phase 2 agents' worktrees started from a stale commit** (`5c733a40`, before Phase 1.1). Each agent noticed and reset to `a803f829` before working. Every merge was re-tested on the audit branch.
6. **The first environment dumps (Phase 3) were wrong**, before `environment.md` was written:
   - headless runs lose multimesh transforms, so whole maps read as bare; the dump now runs under xvfb/OpenGL;
   - fog-hidden nodes were skipped;
   - large flat meshes and tall sprites were counted as one cell.
   All were fixed before any finding was recorded.
7. **Phase 4 first broke `test_escort_quests`**: the field Olorin counted as a quest NPC once the depot was gone. Fixed inside Phase 4.
8. **Phase 1:**
   - removing `Enemy.debuff_expired` left 16 empty branches, so it was reverted and the signal kept;
   - a pixel-raster helper shadowed its own loop variable. Both were caught by the gate and by `--check-only` before committing.
