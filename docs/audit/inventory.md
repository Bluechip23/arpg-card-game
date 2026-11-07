# Inventory — Phase 0 map

Branch `audit/full-pass-1`, from `b67b134b`. This is the map every later phase works from.

- **Raw map (generated):** [`inventory_generated.md`](inventory_generated.md). It lists every script, scene and resource, the reference counts, every card, item, enemy, passive and status effect with the files and lines that name it, plus dead-code candidates, duplicated bodies, orphans and cycles.
- **Regenerate:** `python3 tools/audit/inventory.py --md docs/audit/inventory_generated.md` (about 40 s). Pass `--json OUT` for the machine-readable form the later phases query.
- **Earlier audits this builds on:** `AUDIT.md` and `PLAN.md` (2026-10). Most of their refactors were carried out: cards and items moved to `.tres`, summon base classes, `EnemyDefs`, panels lifted out of `main.gd`. Findings they already closed are not repeated here.

## 1. Shape of the project

| | |
|---|---|
| Engine | Godot 4.6, GDScript only. Battle and town are `Node3D` scenes with pixel art on `Sprite3D` billboards; only the UI is 2D. |
| Game code | 161 scripts under `scripts/` (about 95,000 lines), 27 scenes, 2 autoloads |
| Data | 255 cards (`data/cards/*.tres`), 189 items (`data/items/*.tres`). Enemy base stats are a GDScript table (`scripts/battle/enemy_defs.gd`). |
| Tests | 217 SceneTree tests (`tests/test_*.gd`, run by `tests/run_all.sh`), a headless combat sim (`tests/sim/`), and the refactor gate `tools/refactor_gate.sh` |
| Entry | `scenes/menus/title_menu.tscn` → load / new character → `scenes/core/main.tscn` (overworld, dungeons, battles) or `scenes/menus/town.tscn` (town). Autoloads: `UiTheme` (`scripts/ui/ui_theme.gd`) and `Palette` (`resources/palette/palette.gd`). |

### Who owns what (runtime)

`Main` (`scripts/core/main.gd`, 17,564 lines, 79 `#region`s) is the hub. It creates and holds the `EnemySpawner`, `DungeonManager`, `TempoManager`, `DeckManager` (through the player), the UI panels and the per-card world effects, and most systems reach each other through it. The tempo clock lives in `scripts/battle/tempo_manager.gd`. Tempo spent by the player calls `Enemy.on_tempo_advanced` and the action clocks (`Enemy._tick_action_clocks`: Sync, Async, Channel, Trigger, per `docs/ENEMY_ACTION_KEYWORDS.md`).

The class-reference graph is a single tangle: **98 game scripts are in one strongly connected group**. Almost every system can reach every other through `class_name` references; the list is in the generated map. There are no preload cycles, so nothing fails to compile. But no system can be tested or moved without loading most of the game, and this is the main structural debt.

## 2. Where each kind of content is defined and where its behaviour lives

| Content | Defined | Behaviour lives in | Notes |
|---|---|---|---|
| **Cards** (255) | `data/cards/<id>.tres` (`Card` resource) | `scripts/cards/card.gd`: `execute()` → `_execute_card()`, a `match card_id` (line ~1816) with 131 `_execute_*` helpers. World effects (AOE, summons, zones, projectiles) are in `main.gd` §CARD WORLD EFFECTS (PER-CARD MATCH), 1,242 lines. Riders and passives react in `progression/progression_triggers.gd`. | One card's behaviour is often split between `card.gd` and `main.gd`. Every card id is named by some game code (0 orphans). 54 cards are named by no test. |
| **Items** (189) | `data/items/<id>.tres` (`ItemData`) | Mostly **data fields** read by shared code: `PlayerStats` equipment fields (`equipment_*`), `Inventory`, `OnSelfRules`, `Card.get_on_self_bonus`. Bespoke ones are keyed by `special_id` or name strings in `main.gd` and `card.gd`. | Field-driven is the right shape. 23 items are named by no test. |
| **Enemies** (74 enum entries: 66 creatures, 5 totems, structures, dummy, 2 mock-ups) | `scripts/battle/enemy_defs.gd` (base numbers) | `scripts/battle/enemy.gd`: **six parallel tables keyed by `EnemyType`** — `actions_for_type` (:661), compendium `_actions` and `_specials` in `get_all_enemy_data` (:1126/:1206), the chooser `match` in `_choose_action` (:2316), the executor `match` in `_run_action` (:3406), and `NON_MELEE_ACTIONS` / `MOVEMENT_ACTIONS` (:351/:376). Art in `sprite_enemy_figure.gd` `KINDS` (:96). | Adding an enemy touches 6–8 places in two files. The full data conversion is out of scope (designer, 2026-11-07); see Phase 1. |
| **Characters** (5: Ryan, Jeremy, Stephen, Cory, Brad) | `scripts/character/character_data.gd` `create_<name>()` | Stats in `player_stats.gd`, skill trees in `progression/skill_tree_data.gd`, sphere grid in `progression/sphere_grid.gd`, art in `character/sprite_figure.gd`. Per-character string checks across 11 files (AUDIT D6). | |
| **Summons** (8 scripts) | `scripts/battle/summon.gd` (base), `healable_summon.gd`, `markable_summon.gd` and 6 concrete summons | Spawned and steered from `main.gd` regions: RANGED PASS, WOLVES, FRANKENSTEINS MONSTER, SANGUINE THE PENGUIN, ALASKAN BULL WORMS. | The base classes exist (AUDIT D1 done). Spawning and AI driving still live in `main.gd`. |
| **Passives** (58 in `docs/PASSIVE_REFERENCE.md`) | Rows in `progression/skill_tree_data.gd`; ids are derived from names (`name.to_lower().replace(" ", "_")`) | `progression/progression_triggers.gd` (2,427 lines), `passive_scaling.gd` (rank tables), `passive_cooldowns.gd`, plus hooks in `main.gd` | Ids derived from names are fragile: a rename silently changes the id (see `PlayerStats.RENAMED_PASSIVES`). |
| **Status effects** (29 debuffs, 29 buffs) | `effects/debuff.gd` `DebuffType`, `effects/buff.gd` `BuffType`; 5 retired slots kept for save compatibility | Player side: `DebuffManager` and `BuffManager` objects. **Enemy side: a separate, string-keyed system** (`Enemy.apply_debuff(name, value)` :7480, `Enemy.debuff_key_for_effect`), with its own clocks inside `enemy.gd`. | Two status systems with the same names and different rules. A known source of drift (see the Wither note in CLAUDE.md). |
| **Quests, NPCs, world** | `core/quest_manager.gd`, `core/dungeon_manager.gd` (7,833 lines: every map, interior, prop and trap), `core/waypoint_manager.gd`, `battle/rescue_npc.gd` | | |
| **City / town building** (removed in Phase 4) | `scripts/city/*` (`CityState`, `CityBridge`, `ExpeditionSystem`, `RaidSystem`, `TrialSystem`) | Hooks in `menus/town.gd`, `core/main.gd`, `core/save_data.gd`, `core/progression_io.gd`, `progression/inventory.gd`, `cards/deck_manager.gd`, `core/quest_manager.gd`, `core/dungeon_manager.gd` | |

## 3. Debt and hazards found

### 3.1 The sim is no longer deterministic (blocks the refactor gate)
`tests/test_sim_determinism.gd` fails. Two runs of the same seed play out differently, and which seed diverges changes from run to run. This was checked at `5c733a40` (before any work on this branch) and at `b67b134b`. It passed when the gate was built (PLAN.md Phase E). Every behaviour-neutral refactor in Phase 1 relies on byte-identical sim output, so **this is fixed first** (Phase 1, step 0).

### 3.2 God objects
| File | Lines | What it mixes |
|---|---|---|
| `core/main.gd` | 17,564 | Input, camera, HUD, card play, per-card world effects, loot, boss rooms, waypoints, summons, sandbox, debug UI, co-op |
| `core/dungeon_manager.gd` | 7,833 | Map generation for every region, interiors, props, traps, lighting |
| `battle/enemy.gd` | 8,200 | Every enemy's actions, choosers and passives, plus status, health bars and tempo bars |
| `cards/card.gd` | 4,783 | Card resource, damage pipeline, 131 executors |
| `menus/town.gd` | 4,052 | Town scene, NPCs, vendors, the city UI (Phase 4) |

The largest `main.gd` regions that no other system calls into could each be moved into their own node script (PLAN.md follow-ups): CARD WORLD EFFECTS (1,242), RANGED PASS (979), LOOT DROP SYSTEM (588), BOSS ROOMS (575), WAYPOINT TRAVEL (317), SANDBOX MODE (251), COMMUNAL DONATION UI (248), FRANKENSTEINS MONSTER (203), WOLVES (158), SANGUINE THE PENGUIN (148).

### 3.3 Dead code (heuristic list, hand-checked in Phase 1)
16 functions whose names appear nowhere else in the repository: the 10 unused `OverflowEffect.create_*` factories, `Buff.create_focused`, `EnemySpawner.spawn_fire_goblin_pack`, `DeckManager.get_total_deck_room`, `Inventory.can_rack_exchange` and `SkillTreeData.get_row_for_level` (full list in the generated map). No `"create_" + name` style dynamic call exists for them.

Two scripts are referenced by nothing in the game:
- `scripts/core/sheet_anim_sprite.gd`: its docstring says it drives the waypoint totems, but no script or scene uses it.
- `scripts/ui/pile_icon.gd`: reached only by the dev capture `tests/_capture_pile_icon.gd`.

### 3.4 Duplicated logic
14 exact duplicate bodies (generated map), for example:
- `buff_icon_ui.gd` and `debuff_icon_ui.gd`: `_build_badge`, `_make_count_pill` and more (two copies of one icon widget)
- `status_icons.gd` and `ui_glyphs.gd`: `_disc`, `_tri` (two copies of the glyph primitives)
- `main.gd` and `town.gd`: `_pan_camera`
- `mythic_reveal.gd` and `main.gd`: `_sphere` / `_mesh_sphere`

Duplicates that are similar rather than identical:
- Player-side and enemy-side status systems (§2).
- The enemy reach numbers repeated between each chooser and `Enemy._ranged_reach` (6 for Bone Dragon, 4 for Ifrit, 3 for Titan, 4 for Treant…).

### 3.5 Hard-coded values that should be named or data
Bare-number counts per file are in the generated map. The worst are `main.gd`, `enemy.gd`, `dungeon_manager.gd` and `card.gd`. Typical cases:
- Reach and range literals inside enemy choosers (`distance <= 4`, `<= 6`) that duplicate an action's real reach.
- Card numbers inside `card.gd` executors that already have a resource field.
- Map layout numbers in `dungeon_manager.gd`, which are geometry and acceptable as-is.

### 3.6 Naming
Files are snake_case and `class_name`s PascalCase across `scripts/`. Exceptions: `main.gd` gained `class_name Main` late, and several `class_name`-less scripts are reached by path only. Fine as-is.

### 3.7 Known failing tests on the starting commit
`test_combo_planner`, `test_escort_quests`, `test_item_forge`, `test_sim_hand_check`, `test_sim_policies`, `test_spell_weapons_pass`, `test_sprite_imports`, `test_turtle_armor_anim`, `test_sim_determinism` (§3.1), and `test_sim_audit` (times out at 600 s under parallel load; it passes alone in about 9 minutes). Each fails the same way on `5c733a40`. The sim ones are probably downstream of §3.1, and Phase 1 re-checks them after the determinism fix.
