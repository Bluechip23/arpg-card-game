# Phase 4 — the town-building end-game, removed

Designer, 2026-11-07: delete all town-building end-game functionality, keep the Town Hall as a visual only, and make sure old saves still load. The end game is being redesigned from scratch. Scope chosen: **everything** in the city loop, including the resource satchel that filled during the story, with `CLAUDE.md` and `STORY.md` updated to drop the base-builder pillar.

## Files deleted
| File | What it was |
|---|---|
| `scripts/city/city_state.gd` (+ `.uid`) | The city: resources, building levels and upgrade costs, production, storage cap, power, defense log, save/load |
| `scripts/city/city_bridge.gd` (+ `.uid`) | Carried the city, the satchel and the pending trial inside `player_progression` between scenes and into saves |
| `scripts/city/expedition_system.gd` (+ `.uid`) | Habitat resource yields per kill; hero power for trial defense |
| `scripts/city/raid_system.gd` (+ `.uid`) | Rival-city generation, raid resolution, defense log |
| `scripts/city/trial_system.gd` (+ `.uid`) | Trial scheduling on leaving town, the kill countdown, the strike, resolution on reaching town |
| `tests/test_city_loop.gd` (+ `.uid`) | Data-loop test of the above |
| `tests/test_city_wiring.gd` (+ `.uid`) | Game-wiring test of the above |

No art was deleted. The Town Hall's mesh, door sprite and banner are still built, in `town.gd`.

## Code removed from files that stay
| File | Removed |
|---|---|
| `scripts/menus/town.gd` | The Town Hall's entry in `vendor_info` and its interaction branch; the city panel (`_open_town_hall_ui`, building rows, upgrades, cost formatting); coming home (`_arrive_home`: banking the satchel, resolving struck trials, the Olorin's-flute hand-off); arming a trial on leaving town; `data.city` in the save; the "Lumber Mill and a field depot" and "garrison's respect" reward texts. **The Town Hall stays** (`_build_town_hall`): the same building, now outside the interactable `$Vendors` group and without its floating name, so it is scenery. |
| `scripts/core/main.gd` | The kill hook (satchel yields, trial countdown); `_announce_trial` (the flute alarm); the rescued woodcutter's Lumber Depot post and its "send satchel home" interaction; the city keys carried into the town hand-off and the save. The region is renamed "QUEST NPCS: RESCUES, FOLLOWERS". |
| `scripts/battle/rescue_npc.gd` | The `depot` mode (a rescued NPC as a standing satchel post) |
| `scripts/core/quest_manager.gd` | The Trial Warning quest, its `trial_answered` objective type, and the `calamity_warning` → `trial_warning` id migration |
| `scripts/core/save_data.gd` | The `city` export |
| `scripts/core/progression_io.gd` | Carrying the city keys to and from disk; the `city_calamity` → `city_trial` migration |
| `scripts/menus/load_character.gd` | Loading `SaveData.city` into the town |
| Tests | `test_quests` (Trial Warning checks → "Trial Warning is gone"), `test_escort_quests` (depot checks → "nothing stays on the surface"), `test_game_menu_actions` (the city hand-off on load) |
| Docs | `CLAUDE.md` (the base-builder pillar and the Home Base pillar), `docs/STORY.md` (§6 rewritten as "End-Game: being redesigned"; the city's references in §4, §5, §8 and §9), `docs/ASSET_PACKS.md` (city as an intended use of six packs) |

## Old saves
`SaveData` loses its `city` field, and a save written before the change carries one. Godot drops the unknown property when it loads the resource. `ProgressionIO.to_live` drops the old progression keys (`RETIRED_CITY_KEYS`: `city`, `city_satchel`, `city_trial`, `city_calamity`). The quest loader skips ids that no longer exist, such as an accepted or finished Trial Warning. `tests/test_retired_city_saves.gd` writes a save in the old shape and proves all three. That key list is the only trace of the old system left, and it exists so old saves load cleanly.

## Progression
- **Trial Warning** was the only quest that needed the city. Nothing listed it as a prerequisite, so no quest chain dead-ends.
- **The Missing Woodcutter** still rewards gold, XP and its `woodcutter_rescued` flag. The flag used to place the Lumber Depot; now it only records the rescue.
- The `garrison_veteran` flag, granted only by Trial Warning, is gone. Nothing read it.

## Tests
- `test_retired_city_saves` (new) passes.
- `test_escort_quests` now passes. It failed on `main` because it assumed the field Olorin was not in the quest-NPC list.
- `test_quests`, `test_game_menu_actions`, `test_progression_io`, `test_crows_quest`, `test_keeper_intros` and the other town, save and quest tests pass.
- Search after removal (`grep -ri "CityBridge|CityState|TrialSystem|ExpeditionSystem|RaidSystem|city_satchel|trial_answered|trial_warning|depot"` over `scripts/`): only `ProgressionIO.RETIRED_CITY_KEYS` remains.
