# Phase 1 — restructure and tech debt

Scope (designer, 2026-11-07): keep the existing layout (`scripts/battle`, `cards`, `core`, `ui`…) and add `scripts/shared/` for anything two or more scripts used to copy. Do only behaviour-neutral refactors. Converting enemy behaviour and card effects to data plus reusable effect scripts is **BLOCKED**, with a plan below.

**Verification for every step:**
- `godot --check-only` on each touched script. `tests/test_parse_all.gd` alone misses dependency compile errors (PLAN.md).
- The refactor gate, `tools/refactor_gate.sh` (quick tier): parse, determinism, `catalog.json`, the example sweep and the designed builds at seeds 1–10, byte-compared against a baseline taken at `c92860a0`.
- The tests that touch the changed code.

| Step | Commit | What | Verified |
|---|---|---|---|
| 1.0 | `c92860a0` | **The sim is deterministic again.** Swing hold (2026-11-03) landed blows on a wall-clock timer, and the headless sim never turned it off, so the same seed played out differently from run to run. The sim now boots with swing hold off (the game's own Settings switch) and restores it at teardown. The Treasure Bunny's vanish, the one gameplay effect on a cover timer, follows the same switch. | Three runs of seed 11 byte-identical. `test_sim_determinism`, `test_sim_hand_check`, `test_sim_policies` and `test_combo_planner` go from FAIL to PASS. |
| 1.1 | *(this commit)* | **`scripts/shared/`** created. Five helpers / base classes replace copied code: `status_badge_ui.gd` (base of `BuffIconUI` and `DebuffIconUI`, which were one widget written twice), `pixel_raster.gd` (the plot/rect/disc/line/tri primitives `StatusIcons` and `UIGlyphs` each carried), `lab_menu_base.gd` (the five list/panel helpers `AnimationLab` and `EnemyLab` each carried), `mesh_util.gd` (`sphere()`, in `main.gd` and `mythic_reveal.gd`), `camera_pan.gd` (the pan clamp shared by `main.gd` and `town.gd`). Consumers `preload` them, so nothing depends on the editor's class cache. | Gate MATCH. All 93 procedural icons and glyphs render byte-identical before and after (md5 of every image). The 36 tests touching the changed code pass, except `test_item_forge`, which fails identically on the starting commit. |
| 1.1 | | **Dead code removed:** 16 functions no code calls (10 `OverflowEffect.create_*` factories, `Buff.create_focused`, `EnemySpawner.spawn_fire_goblin_pack`, `DeckManager.get_total_deck_room`, `Inventory.can_rack_exchange`, `SkillTreeData.get_row_for_level`); two empty trigger stubs in `progression_triggers.gd` with their call sites and the `main.gd` handler that only called one of them; 5 unused constants (`TOUR_MARGIN`, `RACK_FREE_SWAP_COOLDOWN`, `OFF_HAND_RIDER_SCALE`, `NPC1`, `MINIMAP_SIZE`); `scripts/core/sheet_anim_sprite.gd` (its docstring claims the waypoint totems, but no script or scene uses it). | as above |
| 1.1 | | **Magic numbers → named constants:** the reach of every ranged enemy action (`HUNTER_HOOK_MIN/RANGE`, `HUNTER_NET_RANGE`, `TREANT_ROOT_RANGE`, `BONE_DRAGON_BREATH_RANGE`, `WYVERN_TALON_RANGE`, `IFRIT_BREATH_RANGE`, `TITAN_BOULDER_RANGE`, `DJINN_CHAIN_RANGE`). Each was a literal repeated in its chooser, its executor and `Enemy._ranged_reach`. Values unchanged. | as above |

## Kept on purpose

| What | Why |
|---|---|
| `Enemy.debuff_expired` signal | No listener after the handler went, but it is emitted from inside 16 expiry branches and costs nothing. It is the hook a future "when an enemy's debuff runs out" passive needs. |
| `ItemData.fire_resistance_percent`, `ItemData.movement_per_tempo_bonus`, `CharacterData.sprite_sheet_path` | Unused exported fields, but exported fields are serialised into saves (AUDIT §3.1). Removing them needs a save-compat check — FLAGGED for your call. |
| `character_select.gd` `title_separator` | An `@onready` node reference to a scene node; removing it means editing the scene. Harmless. |
| `scripts/ui/pile_icon.gd` | Only the dev capture `tests/_capture_pile_icon.gd` uses it. That is a dev tool, not dead. |
| `toggle_panel` in `skill_tree_ui.gd` / `sphere_grid_ui.gd`, `_refresh` in `jailed_icon_ui.gd` / `maintained_icon_ui.gd` | Two-to-four-line idioms over each script's own state. A shared base would add more lines than it removes. |

## BLOCKED (needs a decision or a dedicated project)

| Item | Why it is blocked | Plan when unblocked |
|---|---|---|
| **Enemy behaviour as data** (66 creatures, `enemy.gd` 8,200 lines) | Designer, 2026-11-07: safe parts only. Every enemy's chooser and executor is bespoke logic, so this is a rewrite of all combat AI, not a move. | (1) Introduce `EnemyActionDef` resources: name, wind-up, keywords, reach, damage, riders (debuff list), projectile kind. (2) Move the generic shapes first — melee strike, ranged strike, AOE line, cone, summon — and route `_run_action` through them for the enemies that are pure shapes (about 40% of the roster). (3) Keep bespoke executors as named effect scripts. Gate each enemy with the sim (`enemy_strategy.txt` sweep) and the per-enemy tests. |
| **Card effects as reusable effect scripts** (131 `_execute_*` in `card.gd`, plus 1,242 lines of per-card world effects in `main.gd`) | Same decision. One card's behaviour is split between `card.gd` and `main.gd`. | Effect primitives (`DealDamage`, `ApplyDebuff`, `GainArmor`, `Draw`, `SpawnZone`, `Summon`…) as `Resource` scripts listed on the card's `.tres`. Convert the data-only cards first (about a third are "damage + debuff"), gated by the full sim (`combos.txt` and `card_power.txt` sweeps). |
| **Splitting `main.gd`** (17.5k lines) | Behaviour-neutral but large. Each region needs its callers re-pointed and its state moved. PLAN.md E3 did three regions this way. | Lift the regions that have no outside callers into child node scripts, one gated commit each: LOOT DROP SYSTEM, BOSS ROOMS, WAYPOINT TRAVEL, SANDBOX MODE, FRANKENSTEINS MONSTER, WOLVES, SANGUINE THE PENGUIN. COMMUNAL DONATION UI goes with Phase 4 if it is city-only. |
| **One status system for player and enemies** | `DebuffManager` objects on the player vs string keys and hand-rolled clocks on `Enemy`. Unifying them changes timing edge cases (Wither, Mark), which is a design question (see the CLAUDE.md open note). | Decide what a "charge" means per debuff first; then give `Enemy` a `DebuffManager`. |
