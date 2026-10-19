# AUDIT.md — Phase 1 (read-only)

Audit of the Godot 4.6 project on branch `claude/great-keller-rprdi5` at commit `363e065`.
No project file was edited. Every claim below cites a `file:line`; line numbers are from that commit.

Legend for each finding: **Category** · **Risk** (low/med/high — risk of changing gameplay or breaking something while fixing it) · **Confidence** (certain / likely / guess — how sure I am the finding is real). Perf claims are marked **needs profiling** unless the waste is provable from the code alone; even then the *magnitude* is unmeasured.

---

## 0. Scope, method and the big picture

**What was read.** All 316 `.gd` files (101,857 lines under `scripts/`, 26,702 under `tests/`, 259 under `tools/`, 139 under `resources/`), all 29 `.tscn`, `project.godot`, all 5,149 `.import` files (aggregated), the docs that define conventions (`CLAUDE.md`, `docs/STYLE_GUIDE.md`, `docs/CARD_TAXONOMY.md`, `docs/sim/README.md`). The giant files (`main.gd` 17,249 lines, `card.gd` 9,106, `enemy.gd` 8,023, `dungeon_manager.gd` 6,743) were read by region and function profile plus targeted full reads of the hot paths (frame loop, tempo loop, damage paths, factories, executors); I did not read every one of their 17k+9k+8k lines word by word.

**How dead code was checked.** A whole-repo identifier scan (scripts, scenes, tests, tools, `project.godot`) counted every occurrence of every function / signal / export / const name, then I hand-checked the dynamic-reference channels you listed: `call(`/`call_deferred(`/`callv(` (82 + 18 + 0 sites), `Callable(obj, "name")` (46), string `connect(` (0), editor-connected signals in `.tscn` (0 — the project wires everything in code), `has_method(` (378 sites, 98 distinct names), AnimationPlayer method tracks (0 AnimationPlayers in the project), `get_node` paths (63 + 193 `$` paths) and reflection (`get_script_method_list`, 18 sites). Anything reachable through those is listed as **alive via dynamic reference**, not dead.

**Important framing you should know before reading the perf section.** This is **not a 2D game**. The battle and town are `Node3D` scenes (`scenes/core/main.tscn:1`, `scenes/menus/town.tscn:52`) rendered by a `Camera3D` with pixel art shown as `Sprite3D` billboards and `StandardMaterial3D` quads (`docs/STYLE_GUIDE.md` §0–§1). So "2D batching", "2D pixel snap" and "sprite atlases for the 2D renderer" mostly do not apply; what matters is 3D draw calls (one per unique material/mesh), `Label3D` count, and per-frame CPU work. The UI (`CanvasLayer` → `Control`) is the only 2D.

**Headline numbers**

| Metric | Value | Where |
|---|---|---|
| Scripts / lines under `scripts/` | 132 files / 101,857 lines | `find scripts -name '*.gd'` |
| Largest script | `scripts/core/main.gd` — 17,249 lines, 602 functions, 361 top-level vars, 82 `#region`s | `main.gd` |
| Custom `.tres` resources | **0** — every card (247), item (190), enemy (66) and character (5) is a GDScript factory or a `match` arm | `find . -name '*.tres'` |
| Per-frame `_process`/`_physics_process` | 33 definitions | §2.4 |
| `print(` calls in gameplay scripts | 1,149 (card.gd 257, enemy.gd 192, main.gd 184) | §2.6 |
| Untyped `var x = …` declarations | 4,773 (vs 6,942 typed/inferred) | §4.3 |
| Functions without `-> ReturnType` | 11 of 4,523 (good) | §4.3 |
| `has_method(` duck-typing sites | 378 | §4.5 |
| Certainly-dead functions | 37 functions, 462 lines | §3.1 |
| Textures | 5,149, all Lossless, no mipmaps, `detect_3d/compress_to=1` | §2.1 |

**Things you may have worried about that are fine**

- **Import settings are already correct for pixel art**: every one of the 5,149 texture imports is `compress/mode=0` (Lossless), `mipmaps/generate=false`, `process/fix_alpha_border=true`. Nothing is lossy or mipmapped. (One latent risk remains — §2.1.)
- **No shaders, no particles, no AnimationPlayers** exist in the project (`ShaderMaterial.new()` 0, `GPUParticles3D`/`CPUParticles3D` 0, `AnimationPlayer` 0). There is no mixed-material/shader batching problem to solve; the Tween/Timer question is small (§2.5).
- **No commented-out code blocks.** A heuristic scan for code-shaped comment lines found 12 hits, all of which are prose. Nothing to delete here.
- **No unreferenced scripts or scenes** at file level: every `.gd` under `scripts/` is reached by path, `class_name` or scene, and every `.tscn` is instanced or preloaded somewhere. Dead code in this project is *inside* files (§3), not whole files.
- **No unreferenced image assets** by a conservative test (full path, file stem, or parent-folder string appears in code). 3,795 of 5,137 images are reachable only through a folder string built at runtime (e.g. `SpriteEnemyFigure.KINDS` → `assets/sprites/craftpix/<pack>/<Variant>/…`), so I cannot prove any individual sheet dead without running every enemy/character; see §3.3.
- **The sim is deterministic today**: `tests/test_sim_determinism.gd` passes (byte-identical CSVs across passes), and `tests/test_parse_all.gd` parses all 132 scripts clean. That is the safety net Phase 3 relies on.
- **Naming is consistent.** No camelCase identifiers in GDScript; snake_case/PascalCase/ALL_CAPS conventions hold everywhere except the four `var BASE_ATTACK` mutables in `summoned_skeleton.gd:17-20` (§4.6) and a few misspelled ids that are save-compat and must not be renamed.

---

## 1. Duplication across characters, enemies, summons and cards

### D1. Eight summon scripts are one class written eight times
**Files:** `scripts/battle/summoned_wolf.gd` (152 lines), `summoned_skeleton.gd` (163), `summoned_specter.gd` (136), `summoned_worm.gd` (142), `summoned_clone.gd` (129), `frankensteins_monster.gd` (155), `sanguine_penguin.gd` (138), `spirit_bow_summon.gd` (164) — 1,179 lines total.
**Category:** duplication · **Risk:** low · **Confidence:** certain

**Evidence (side by side).** All eight contain the same members and functions, differing only in constants:

| Block | wolf | skeleton | specter | worm | clone | frankenstein | penguin | spirit bow |
|---|---|---|---|---|---|---|---|---|
| `signal died(x)` | :12 | :14 | :12 | :11 | :16 | :17 | :13 | :17 |
| `max_health/health/grid_manager/is_dead` | :20-23 | :24-27 | :16-21 | :16-18 | :23-26 | :20-25 | :20-23 | :27-31 |
| `move_accum/attack_accum` cadence | :24-25 | :28-29 | — | — | :27-28 | :28-29 | :24 | :32-33 |
| `setup(gm, spawn_pos, …)` snaps y=0, builds visuals | :39-44 | :35-56 | :32-39 | :26-31 | :33-40 | :39-48 | :28-33 | :36-49 |
| `_build_visuals()` + `_health_label` Label3D (`font_size 24`, `pixel_size 0.005`, `WorldText.crisp`) | :46-77 | :58-109 | :41-60 | :33-82 | :42-73 | :50-101 | :35-80 | :60-96 |
| `_process(delta)` glide `move_toward(… speed*delta)` then snap at `< 0.01` | :83-91 (4.0) | :115-123 (4.5) | — | :107-115 (3.0) | :78-86 (4.0) | :107-115 (3.0) | :85-93 (5.0) | :117-125 (4.0) |
| `get_cell()` | :93-96 | :125-128 | :63-66 | :117-120 | :88-91 | :117-120 | :95-98 | :127-130 |
| `move_to_cell(cell)` | :98-103 | :130-135 | — | :122-127 | :93-98 | :122-127 | :100-105 | :132-137 |
| `get_health_percent()` | :105-106 | :137-138 | :68-69 | — | :100-101 | :129-132 | :107-108 | :139-140 |
| `heal()` with Poisoned Blood check | :116-122 | :140-146 | :90-96 | — | :103-109 | :134-140 | :110-116 | :142-148 |
| `take_damage()` → `PlayerStats.apply_cover` → `die()` | :124-146 | :148-158 | :98-120 | :129-138 | :111-120 | :142-153 | :118-129 | :150-162 |
| `die()` sets `is_dead`, emits, `queue_free` | :148-152 | :160-163 | :122-127 | :140-142 | :122-129 | :155-159 | :131-138 | :164-168 |

**How they differ (the only real content):** wolf & specter carry Shepherd's Mark + armor (`summoned_wolf.gd:29-33, 108-114, 131-143`; `summoned_specter.gd:23-27, 75-80, 103-115`); worm is `burrowed`/untargetable until `surface()` (`summoned_worm.gd:18, 84-93, 129-131`); clone/skeleton take `hp` in `setup`; skeleton retunes per `kind` (`summoned_skeleton.gd:35-55`); frankenstein applies `resist_percent` (`frankensteins_monster.gd:148`); penguin emits `hurt` (`sanguine_penguin.gd:14, 126`); spirit bow has `is_bud`, instant death and `spend_attack()` (`spirit_bow_summon.gd:28, 105-111, 157`); specter has a `tick()` lifetime (`summoned_specter.gd:72-78`). Glide speeds differ (3.0 / 4.0 / 4.5 / 5.0) and must be preserved as per-subclass constants.

**Recommended pattern: a base class, not components or Resources.** `class_name Summon extends Node3D` holding the shared members, `setup()`, glide `_process`, `get_cell/move_to_cell/get_health_percent/heal/take_damage/die` and the label builder, with `_build_body()` and a few hooks (`_pre_damage(amount) -> int` for armor/resist/burrow, `_on_lethal()` for Shepherd's Mark / bud) overridden per subclass. Justification: these are *behaviourally* one thing (a grid unit with HP that main drives per tempo); the variation is a handful of overridable steps, which is exactly what inheritance expresses cheaply. Composition (`HealthComponent`) would also work but buys nothing here because none of these parts is reused outside summons. A Resource is wrong because the differences are code (burrow, bud death, Shepherd's Mark), not numbers. Main's `enemy_spawner.summons` list and `_update_*` drivers already treat them uniformly by duck typing (`main.gd:6186-6188`; `enemy_spawner.gd:144-152`), so a shared base also lets those call sites be typed.
**Estimated lines saved:** ~650 (eight files → one ~170-line base + eight 25–60-line subclasses). **Gameplay risk:** low if each subclass keeps its constants and overrides verbatim; `print` tags (`[WOLF]`, `[SPECTER]`) are UI-only noise but keep them to preserve logs.

### D2. Enemy definitions are spread over six parallel tables keyed by `EnemyType`
**Files:** `scripts/battle/enemy.gd:451-1215` (`initialize()` — a 764-line `match` with 66 arms setting name/HP/armor/damage/range/move/aggro/xp/resists/colour), `enemy.gd:1419-1806` (`actions_for_type()` — 387-line match, the action tables), `enemy.gd:1869-2215` (`get_all_enemy_data()` — `_type_display` tier table at :1878-1951 **and** a second `_stats` table at :1952-2020 that *re-states the same HP/armor/damage/xp as `initialize()`*), `enemy.gd:57-93` (`INTENDED_LEVELS`), `enemy.gd:1291-1370` (`_setup_sprite()` — a 70-line match mapping type → figure kind string), `scripts/battle/enemy_spawner.gd:316-348` (`get_loot_tier()` tier table — a third copy of the tier column), `scripts/cards/unit_tracker_ui.gd:543-545` and `scripts/menus/enemy_lab.gd:83-98` (more per-type tables), `scripts/battle/sprite_enemy_figure.gd:KINDS` (kind → art).
**Category:** duplication / data-as-code · **Risk:** med · **Confidence:** certain

**Evidence.** I cross-checked `initialize()` against `_stats` programmatically: 66 arms vs 68 entries (the two extra are the `PIT_FIEND`/`CORRUPTED_ARCHANGEL` mock-ups that have no `initialize` arm). All overlapping values currently agree — so the duplication has not yet produced a bug, but every new enemy needs edits in 5–6 places (`initialize`, `actions_for_type`, `_type_display`, `_stats`, `INTENDED_LEVELS`, `_setup_sprite`, `get_loot_tier`, `KINDS`). This is the clearest "a new enemy should be a Resource, not code" case in the project.

**Recommended pattern: data-driven `Resource` (`EnemyDef.tres`, one per type) + the existing `Enemy` node.** Fields: display name, tier, intended level, max HP/armor, damage, range, move, aggro, xp, resist triple, damage type, flags (`immune_to_high_ground`, `is_structure`, `is_training_dummy`, `ignores_invisibility`, `attack_burn/shock/blind`, `bleed_on_attack`, `armor_per_hit`), mesh colour, figure kind, loot tier, and the `actions` array of dictionaries. `initialize()` becomes "copy fields from the def, then run the existing post-processing at :1189-1215" and `get_all_enemy_data()`, `get_loot_tier()`, `INTENDED_LEVELS` and `_setup_sprite()` read the def. Justification: the arms are pure numbers; per-type *behaviour* (`_execute_action` at :4085, the elite passes) stays in code keyed by the same enum, so nothing behavioural moves. Why not a dictionary const instead of `.tres`? Either works and a `const ENEMY_DEFS := {…}` is a smaller first step with the same payoff for duplication; `.tres` adds inspector editing. I recommend the dictionary/Resource-class step first (one file, diffable) and `.tres` only if you want to edit enemies in the inspector.
**Lines saved:** ~800 of code replaced by ~66 short data blocks (net ≈ −500 in `enemy.gd`, −35 in `enemy_spawner.gd`). **Risk:** medium only because 66 × ~12 fields must be transcribed exactly; `dump_catalog.gd` (roster JSON) is a byte-exact check for all of them. **Note:** `EnemyType` enum order is save-compat sensitive (`enemy.gd:33-48`); the enum stays.

### D3. The card damage pipeline is copy-pasted into ~29 executors
**File:** `scripts/cards/card.gd` — 130 `_execute_*` functions; `_execute_slash` :2713-2756, `_execute_dagger_throw` :2757-2789, `_execute_poke` :3300-3315, `_execute_charge` :3322-3333, `_execute_trick_shot` :3394, `_execute_premeditated` :3696, etc.
**Category:** duplication · **Risk:** med · **Confidence:** certain

**Evidence.** The sequence *base + bonus → `get_effective_physical_damage` (or `_spell_`) → `empower_damage_bonus` → `consume_strengthen()` → `roll_crit()`/`crit_multiply()` → cursed `damage_reduction_pct` → `take_damage(total, true, damage_type)` → `self_damage_percent`* appears with small variations in 29 executors: `consume_strengthen()` 29×, `roll_crit()` 28×, `crit_multiply(` 31×, `get_effective_physical_damage(` 29×, `has_method("take_damage")` 33×. `_execute_slash` and `_execute_dagger_throw` differ only in the spell-school branch and the thorns call (`:2742-2749`); `_execute_poke` half-scales the modifiers (`:3306-3309`); `_execute_charge` computes but does not apply (`:3331`).

**Recommended pattern: one helper on `Card`,** e.g. `_resolve_hit(target, player_stats, buff_mgr, opts: Dictionary) -> int` with options for school, half-scaling, apply-or-return, thorns, self-damage, plus each executor keeping only its unique lines. Justification: this is the same object (`Card`) and the same algorithm; a method, not a class hierarchy. **Do not** do this as one sweeping edit: each executor has a documented quirk (Poke's half-scaling, Dagger Throw's missing thorns call, Charge's deferred application) and the order of `consume_strengthen` vs `roll_crit` matters for RNG consumption, which the sim will detect. Convert in batches of ~5, re-running the sim between batches.
**Lines saved:** ~400. **Risk:** medium (RNG order and rounding must be identical; the sim's byte-compare catches it).

### D4. Four "figure" scripts share one verb set behind duck typing
**Files:** `scripts/character/character_figure.gd` (5,116 lines), `scripts/battle/enemy_figure.gd` (3,527), `scripts/character/sprite_figure.gd` (847), `scripts/battle/sprite_enemy_figure.gd` (744).
**Category:** duplication / missing base type · **Risk:** low · **Confidence:** certain

**Evidence.** All four define `setup`, `play_action`, `play_hit`, `set_facing`, `set_facing_from_velocity`, `set_walking`, `_process`; the two sprite figures also share `flash`, `set_highlight`; the two procedural figures share `_build`, `_cancel_action`, `_spawn_heart`, `play_attack`. Owners hold them untyped: `player.gd:22 var _figure = null`, `enemy.gd:430 var _enemy_figure = null`, and call through `has_method` guards (`player.gd:128,140`; `enemy.gd:7` sites). The procedural pair also re-implements the idle bob / step cycle (`character_figure.gd:754-800` vs `enemy_figure.gd:2562-2600`).

**Recommended pattern: an abstract base `Figure extends Node3D`** declaring the verb set with empty bodies, and a shared `BillboardFigure` for the two sprite ones (frame clock, flash, highlight) — i.e. a base class, because the four are substitutable implementations of one role. **Also see §3.2:** `CharacterFigure` is reachable only for characters not in `SpriteFigure.ROSTER` (legacy saves) and `EnemyFigure` only for the `brute_*` tiers and the inspect portrait; if you confirm those are no longer wanted, the right fix is deletion (~8,600 lines), not consolidation.
**Lines saved:** ~150 from the base/typed API alone; up to ~8,600 if the procedural pair is retired (your call).

### D5. Cards and items are 437 hand-written factories (6,170 lines of pure data as code)
**Files:** `scripts/cards/card.gd:3022-9018` (247 zero-arg `static func create_*` — ~4,172 lines), `scripts/progression/item_data.gd:1046-3319` (190 — ~1,997 lines), `scripts/character/character_data.gd:131-291` (5 — 152 lines).
**Category:** data-as-code · **Risk:** high (if migrated to `.tres`) · **Confidence:** certain

**Evidence.** A typical factory is 15–25 lines of `card.field = value` (`card.gd:3022-3040`). Three separate systems rebuild the whole catalogue by reflection to discover them: `DeckManager._build_card_factory_map` (`deck_manager.gd:346-358`), `Card.create_by_id` (`card.gd:9090-9105` — a *second* identical map), `ItemData.get_all_items` (`item_data.gd:3337-3346`), plus `compendium_page.gd:88,98`, `town.gd:764,783`, `animation_lab.gd:282` and 10 test/tool sites. Rarity, slot labels and engraving are *already* separate tables (`CARD_RARITIES` :266, `CARD_SLOT_LABELS` :86, `CARD_ENGRAVED` :248), so a card's definition lives in 2–4 places today.

**Recommendation and why I rate it high risk.** The textbook answer is "cards become `.tres`", but `Card` mixes **definition** fields with **per-instance runtime state** in the same Resource (`consecutive_uses` :463, `rng_outcomes` :447, `jail_time_remaining` :442, `erase_tempo_remaining` :473, `slotted_in_item` :566, `temp_*` :581-598…) and almost none of the definition fields are `@export` (they are plain `var`, so `ResourceSaver` would not serialise them). A `.tres` migration therefore needs a `CardDef`/`Card` split first, touches every one of the 247 factories, and the hand/deck code that calls `Card.new()`. It is the single largest payoff in the codebase (−6k lines of GDScript) but it is not a zero-behaviour-change refactor you can verify step by step without a long migration. **I recommend deferring it past Phase 3**, and doing the cheap part now: collapse the two card factory maps into one (§4.7) and cache the item factory list (§2.7). If you want the full migration later, do items first (`ItemData` is simpler) and keep `card_id` as the key everywhere.

### D6. Per-character logic is dispatched by name strings in 11 files
**Files:** `scripts/progression/skill_tree_data.gd:193-198` (`match base_name: "Brad": …`), `scripts/character/character_figure.gd` (10 name hits), `scripts/character/sprite_figure.gd:24-33` (`ROSTER`), `scripts/ui/sandbox_ui.gd:30-37` (`CARD_GROUPS`), `inventory.gd` (5), `character_panel.gd` (5), `character_select.gd` (5), `main.gd` (5), `demo/character_viewer.gd` (5), `animation_lab.gd` (2), `character_data.gd` (11).
**Category:** data-as-code · **Risk:** low · **Confidence:** certain

**Evidence.** Adding a sixth character today means: a `create_<name>()` in `character_data.gd`, a `create_<name>_tree()` + match arm in `skill_tree_data.gd:193`, a `ROSTER` entry, a `CARD_GROUPS` entry, a figure spec in `character_figure.gd:364 _spec_for`, slot specialty branches in `inventory.gd`, and the sandbox/select lists. `CharacterData` is already a `Resource` with `@export`s (`character_data.gd:6-99`), so this is the one place where "new character = new `.tres`" is nearly free: move `sprite/outfit/hair` (from `ROSTER`), the skill-tree builder name and the card-group list onto `CharacterData` and make the 11 call sites read the resource. **Lines saved:** ~120. **Behaviour:** none, if the five existing `create_*` keep producing identical data (the catalog dump and `CharacterBuilds` tests pin it).

### D7. Smaller duplications worth folding (each certain, low risk)
- Floating damage numbers: `player.gd:523-543 spawn_damage_number` / `:545-565 spawn_heal_number` vs `enemy.gd:7117-7158 _spawn_damage_number` — same Label3D + parallel tween; ~45 lines → one `WorldText.float_number(parent, pos, text, color, size)`.
- Y-glide to terrain height: `player.gd:183-187` and `enemy.gd:6443-6447` are identical (`move_toward(position.y, ground_y, 3.5*delta)`; player's constant is `CLIMB_GLIDE_SPEED = 3.5` at :41, enemy hard-codes 3.5).
- Grid-walk completion (`distance < 0.1` snap, pop next waypoint, `_trim_path_tail`, emit) — `player.gd:189-231` vs `enemy.gd:6449-6503`; the enemy version has wake/bleed hooks in the middle, so a shared "step along path" helper on `GridManager` is the clean cut (~40 lines).
- Status-effect application is implemented twice: players use `DebuffManager.apply_debuff(Debuff)` (`debuff_manager.gd:24-126`) while enemies keep 30+ loose stack/timer vars and a 123-line string `match` (`enemy.gd:7340-7462`, state at :190-260). This is the largest *design* duplication in the project, but it is also where the designer's enemy-vs-player rules intentionally differ (see `CLAUDE.md` "Open Design Notes" on Wither). **Do not** unify it in a behaviour-preserving pass; note it for the buff/debuff rework the designer already plans.
- Interact-prompt updaters in `dungeon_manager.gd` (`update_chest_prompts` :6701, `update_waypoint_prompts` :6092, `update_site_prompts` :5409, `update_tree_prompts` :4556, `update_fountain_prompts` :6539, `update_shrine_prompt` :6346) are six copies of "visible = revealed and manhattan ≤ 2" (~70 lines → one helper over a list of `{grid_pos, node, label_node}`).

---

## 2. Graphics / rendering performance

**Profiling plan (do this before and after any perf step).** Run the game in the editor with the Profiler and Monitors open, in the same save at the same spot (the Dojo with 4 dummies, then an overworld zone with ~8 enemies in view), 30 s each, and record:
1. **Monitors → Time → FPS / Process Time / Physics Process Time** (ms), **Memory → Objects / Nodes / Orphan Nodes**, **Raster → Draw Calls, Primitives, Objects drawn, Total Objects**.
2. **Profiler (Script Functions, self time)** sorted by self time, with "Measure in ms" — expect `Main._process`, `WorldLabelOverlay._process`, `DungeonManager.update_*`, `Enemy._physics_process`, `AOEIndicator._process` near the top; those are the ones the findings below target.
3. **Visual Profiler → GPU** total frame time, for the MSAA question (P6).
4. Note the Godot version/renderer (Forward+ per `project.godot:21`) and window size, since draw-call counts depend on them.
Without those numbers, treat every "needs profiling" item below as a hypothesis.

### P1. Import settings: one latent landmine, otherwise correct
**Files:** all 5,149 `*.png.import` (e.g. `assets/sprites/MonsterKit/monster battler set.png.import:20-45`); `project.godot:43`.
**Category:** import settings · **Risk:** low · **Confidence:** certain (settings) / likely (that the editor would flip them)

- `compress/mode=0` (Lossless), `mipmaps/generate=false`, `fix_alpha_border=true` on **every** texture — correct; nothing to change.
- `detect_3d/compress_to=1` on **every** texture. This is Godot's default: the first time a texture is assigned to a 3D material/`Sprite3D` **in the editor**, the importer re-imports it as VRAM-compressed with mipmaps — exactly what the style guide bans (§7 "mipmapped or filtered pixel textures"). It has not fired yet because the game loads its sheets at runtime through `load()`/`CraftpixProps` paths, not through editor-assigned properties. The day you drag a sheet onto a `Sprite3D` in the inspector, that sheet silently turns blurry. **Fix:** set `detect_3d/compress_to=0` in all `.import` files (mechanical `sed`, one commit; Godot re-reads them on next import). Zero gameplay impact.
- **Filtering.** The project default canvas filter is deliberately Linear (`project.godot:40-43`, for MSDF fonts), and 69 nodes opt into `TEXTURE_FILTER_NEAREST` per node (`sprite_figure.gd` 2, `sprite_enemy_figure.gd` 1, `dungeon_manager.gd` 14, `town.gd` 9…). Two files create `Sprite3D`s with **no** filter set: `scripts/character/character_figure.gd` (2 sites) and `scripts/character/action_fx.gd` (1 site). `Sprite3D` defaults to linear-with-mipmaps; with mipmaps disabled at import that is plain bilinear — soft edges if those sprites hold pixel art. **Needs a visual check**, not profiling.
- **2D snap settings.** None set (`rendering/2d/snap/*` absent). Because the world is 3D at full resolution with an integer-scaled window (`project.godot:34-36`) and the camera derives a whole-pixel texel scale (`STYLE_GUIDE.md` §0), 2D snap would only affect `Control` UI. Fine as is.
- **Atlases.** Not applicable to the 3D billboards (each `Sprite3D` is its own draw call regardless of atlas). The UI already uses a handful of sheets. No action.

### P2. `main.gd:_process` does ~20 subsystems' work every frame; most of it is a pure function of the player's grid cell
**File:** `scripts/core/main.gd:809-854` (`_process`), calling `dungeon_manager.update_chest_prompts` (`dungeon_manager.gd:6701-6718`), `update_waypoint_prompts` (:6092), `update_site_prompts` (:5409), `update_tree_prompts` (:4556), `update_fountain_prompts` (:6539), `update_shrine_prompt` (:6346), `update_feather_visibility` (:6202), `update_enemy_fog_visibility` (:4772), `_update_trap_prompt` (`main.gd:5332`), `_update_rescue_npc_prompts` (:5255), `_check_hidden_site_discovery` (:5239).
**Category:** per-frame work that should be event-driven · **Risk:** low-med · **Confidence:** certain that it is redundant; magnitude **needs profiling**

**Evidence.** Each of those loops over *every* chest/site/tree/fountain/waypoint/enemy in the level every frame, calls `is_revealed()` per object, toggles `visible`, and `update_chest_prompts` does `get_node_or_null("InteractLabel")` per chest per frame (`dungeon_manager.gd:6711`). Their inputs are the player's grid cell `pg` and the fog map — which change only when `tile_reached` fires or fog is revealed — plus chest `opened/looted` flags that change on interaction. The minimap already got this treatment (`main.gd:835-839` throttles redraws to 0.2 s with a comment that per-frame was "visibly laggy on large worlds"). **Fix:** cache `_last_prompt_cell`; run the block only when `pg != _last_prompt_cell` or a `_prompts_dirty` flag is set (set it in `reveal_*`, chest open/loot, trap disarm, site discovery). Keep the AOE-indicator and hover blocks (`:842-854`) per frame since they follow the mouse. **Behaviour:** identical as long as every state change that the updaters read also sets the dirty flag — list them while implementing. **Perf:** removes O(objects) work per frame; large overworlds have hundreds of decorations/sites (`_build_decorations` :3137), so this is the most likely CPU win, but **measure it**.

### P3. `WorldLabelOverlay._process` rewrites four theme overrides on every mirrored label every frame
**File:** `scripts/core/world_label_overlay.gd:77-118` (`add_theme_font_size_override` :95, `add_theme_color_override` :96, `add_theme_constant_override` :98, `add_theme_color_override` :101), fed by 41 `WorldText.crisp` registration sites and every `Label3D` under Main (`:40-52`).
**Category:** per-frame churn · **Risk:** low · **Confidence:** certain (redundant) / magnitude **needs profiling**

**Evidence.** Each `add_theme_*_override` on a `Control` sends `NOTIFICATION_THEME_CHANGED` and invalidates the minimum size, so every enemy name/health/action label, every prompt and every damage number triggers layout work 60×/s even when nothing changed. **Fix:** compare against the last written value (store `px`, color, outline in a small per-entry dict) and only write on change; `ui.text = l.text` likewise. The position update (`:113-116`) must stay per frame. Zero behaviour risk (display only).

### P4. `AOEIndicator._process` allocates and rebuilds an `ImmediateMesh` every frame while visible
**File:** `scripts/battle/aoe_indicator.gd:114-117` → `_rebuild_mesh` :29-39 → `ImmediateMesh.new()` at :42, :66, :80 every call; `_refresh_rng_tiles` :134-152 also runs per frame.
**Category:** per-frame allocation · **Risk:** low · **Confidence:** certain (provably wasteful: a new mesh resource per frame, freed by refcount) / magnitude **needs profiling**

**Fix:** rebuild only when `(shape, aoe_range, snapped mouse direction/cell, global_position)` changed since the last build; reuse one `ImmediateMesh` with `clear_surfaces()`. The shape drawn is unchanged.

### P5. Each enemy runs `CharacterBody3D.move_and_slide()` every physics frame while idle, with nothing to collide with
**Files:** `scripts/battle/enemy.gd:6437-6514` (`_physics_process`, `move_and_slide()` at :6514 on every frame, `_idle_ambient` at :6512), `scripts/character/player.gd:180-259`; `scenes/battle/enemy.tscn:22-23` and `scenes/character/player.tscn:25-26` set `collision_mask = 0`.
**Category:** physics overhead · **Risk:** **med** · **Confidence:** certain that no collision can occur; perf magnitude **needs profiling**

**Evidence.** With `collision_mask = 0` the bodies collide with nothing, so `move_and_slide()` reduces to `position += velocity * delta`, yet the physics server still processes every body each tick. The player's "stuck detection" (`player.gd:214-230`, `STUCK_THRESHOLD`) can never trigger. **Why medium risk despite being provable:** movement timing drives `tile_reached` → tempo, and the sim's row order depends on when moves complete. Replacing `move_and_slide` with manual integration in `_physics_process` should be bit-identical in theory, but this is exactly the kind of change the sim must veto. Do it late, alone, and only if the profiler shows Physics Process Time matters (with ≤10 enemies it probably does not).

### P6. Project-wide MSAA 4× on a pixel-art scene
**File:** `project.godot:44` (`anti_aliasing/quality/msaa_3d=2`).
**Category:** GPU cost · **Risk:** low (but it *is* a visible change) · **Confidence:** likely wasteful; **needs profiling** (GPU frame time)

MSAA smooths polygon edges only — the ground plane, wall quads, the grid lines — not the alpha-scissored sprite texels. The style guide bans soft edges (§7). Turning it off saves GPU memory bandwidth (4× depth/color samples) and may *sharpen* wall edges, but it changes the look of mesh edges, so treat it as a design decision to confirm visually, not a free win.

### P7. Scene/script lighting mismatch (not perf, but a correctness nit)
**Files:** `scenes/core/main.tscn:63` and `scenes/menus/town.tscn:65` set `shadow_enabled = true`; `main.gd:476-480 _unify_lighting` and `town.gd:2306` turn it off at runtime, with four more `shadow_enabled = false` in `dungeon_manager.gd:3521,4681`, `main.gd:14334`.
**Category:** redundant override · **Risk:** low · **Confidence:** certain
Set `shadow_enabled = false` and the §3 light rotation in the `.tscn` so the editor viewport matches the game; keep the runtime guard or drop it. Zero gameplay change either way.

### P8. Unique materials and Label3Ds per unit — draw-call pressure (**needs profiling**)
**Files:** 100 `StandardMaterial3D.new()` sites (every summon `_build_visuals`, `enemy.gd` bars, `grid_manager.gd:36`, `aoe_indicator.gd:19,160`), 52 `Label3D.new()` sites, 130 `MeshInstance3D.new()`.
**Category:** draw calls · **Risk:** low · **Confidence:** likely, **needs profiling**
Each unique `StandardMaterial3D` is its own draw call; three wolves build three identical "fur" materials (`summoned_wolf.gd:47-49`). Each enemy carries 2 tscn Label3Ds + up to 4 built ones + 4 bar meshes (`enemy.gd:398-430`), and every `Label3D` is additionally mirrored by a UI `Label` (P3). **Fix if the Draw Calls monitor says so:** hoist per-class materials into `static var` or `preload`ed `.tres` materials (identical appearance), and consider one `MultiMeshInstance3D` for the tempo/health bars. Not a correctness issue.

### P9. Runtime `load()` vs `preload()` and instancing churn
**Files:** 91 runtime `load(` vs 41 `preload(` in `scripts/`.
**Category:** load/preload · **Risk:** low · **Confidence:** certain where cited; impact small
- Hot-path `load()`s that run per instance: `scripts/battle/blob_shadow.gd:24` (`load(TEXTURE)` per shadow), `scripts/effects/fire_tile_sprite.gd:31-32` (`load(SELF_PATH).new()` and `load(SHEET)` per fire tile), `scripts/core/leaf_fall.gd:25` (per leaf), `scripts/core/cloud_shadows.gd:24`, `scripts/battle/sprite_enemy_figure.gd:211-237,329,369` (per enemy spawn), `scripts/character/sprite_figure.gd:189`. `ResourceLoader` caches by path, so repeat `load()`s are hash lookups, not disk reads — **not a measurable perf problem**, but `preload` (or a `static var` cache) is the idiom and removes the string paths from hot code.
- Scene transitions (`title_menu.gd:205-224`, `town.gd:3291,3755`, `main.gd:14197,14225,16568,16592`, `character_select.gd:535-584`) use `load()` deliberately to avoid circular preload chains between `main.tscn`/`town.tscn`; leave them.
- Per-hit instancing: damage numbers allocate a `Label3D` + `Tween` per hit (`enemy.gd:7117`, `player.gd:523`); hand re-render frees and re-instances every `CardUI` on `hand_updated` (`main.gd:7312 _on_hand_updated`, 176 lines). Both are pooling candidates **only if** the Objects/Orphan Nodes monitor or profiler flags them; at this game's event rate I expect them to be negligible.

### P10. `print()` in hot loops
**Files:** 1,149 `print(` sites; per tempo tick: `tempo_manager.gd:118,138` (every tick), `enemy.gd` (192 sites, many per action/tick), `card.gd` (257, per executor).
**Category:** I/O in hot path · **Risk:** low · **Confidence:** likely, **needs profiling**
Godot's `print` is a synchronous stdout write (and an Output-panel append in the editor), so each tick/hit costs several. **Fix without touching behaviour:** route through a tiny `Log.d(...)` that early-outs on a debug flag (keeps the sim's `--verbose` useful), or leave gameplay prints and only gate the per-tick ones in `tempo_manager.gd`. The sim harness already relies on `--quiet` to silence them, which is itself a hint they are noticeable.

### P11. Hidden nodes that still process — none found
All 33 `_process` bodies early-out on a flag or are on nodes that are freed when not needed (`status_hover_popup.gd:100-108` checks `visible`, `aoe_indicator.gd:115` checks `visible`, summons free on death). `set_process(false)` is used 3×. The remaining always-on `_process`es are the four figure idle bobs (`character_figure.gd:754`, `enemy_figure.gd:2562`, `sprite_figure.gd:785`, `sprite_enemy_figure.gd:697`) and ambience (`cloud_shadows.gd:52`, `leaf_fall.gd:51`, `torch_flicker.gd:16`, `sewer_critter.gd:83`) — cheap, visual, and off-screen culling is the renderer's job. **No action**, just measure.

### P12. Tween / Timer leaks — none found
296 `create_tween()` sites; 27 tween member vars and 13 `.kill()`s; 137 member reassignments of the form `_tween = create_tween()`, only 3 preceded by a kill. Node-bound tweens are freed automatically when they finish or when their node frees, so reassigning without `kill()` leaks nothing — it just lets an old tween run to completion in parallel (a *visual* overlap, not a leak). The one `Timer.new()` (`enemy_inspect_ui.gd:70`) is a child node; the three `create_timer` one-shots free themselves. **No action.**

---

## 3. Dead code

### 3.1 Certainly dead (name appears nowhere else in the repo, including tests, tools, scenes, `has_method` strings, `Callable` strings and reflection prefixes)
37 functions, **462 lines**. Removal risk: low; confidence: certain for every entry (each was checked against the dynamic-reference channels listed in §0).

| File:line | Function | Lines |
|---|---|---|
| `resources/palette/palette.gd:73` | `all_colors` | 67 |
| `scripts/core/main.gd:7712` | `_on_apply_buff` (old test UI) | 38 |
| `scripts/core/main.gd:15551` | `_on_apply_overflow` (old test UI) | 32 |
| `scripts/core/main.gd:14421` | `_on_give_card` | 21 |
| `scripts/core/main.gd:14374` | `_on_spawn_elite` | 17 |
| `scripts/core/main.gd:15102` | `_ally_stats_by_name` | 15 |
| `scripts/core/main.gd:15074` | `_get_ally_names` | 10 |
| `scripts/core/main.gd:15983` / `:15978` | `_mesh_cyl` / `_mesh_box` | 9 / 4 |
| `scripts/core/main.gd:14365` | `_on_spawn_fire_goblins` | 8 |
| `scripts/progression/item_data.gd:924` | `get_card_slot_summary` | 34 |
| `scripts/progression/inventory.gd:2543` | `_destroy_equipped_item` | 27 |
| `scripts/progression/sphere_grid.gd:467` / `:491` | `_shelved_passive_procs` / `_shelved_ring3_nodes` | 24 / 21 |
| `scripts/menus/town.gd:2437` / `:2577` | `_npc_sphere` / `_build_barrel` | 19 / 13 |
| `scripts/core/dungeon_manager.gd:2481` / `:917` | `_min_adjacent_floor_elevation` / `get_rat_nest_cells` | 15 / 5 |
| `scripts/progression/skill_tree_data.gd:148,152,155,169` | `is_retrospective_level`, `is_retro_level_used`, `can_retrospective_pick`, `is_retrospective_picked` | 23 |
| `scripts/effects/debuff_manager.gd:500` | `remove_locks_on_card` | 9 |
| `scripts/cards/card.gd:614` | `apply_flat_block_mod` | 6 |
| `scripts/battle/enemy.gd:2878,1400,7553,6596,6764` | `delay_next_action`, `_on_enemy_animation_finished`, `reduce_armor`, `set_target`, `attack_player` | 16 |
| `scripts/effects/overflow_manager.gd:71` | `has_effect_type` | 5 |
| `scripts/core/quest_manager.gd:512` | `get_turnable_quest_for` | 5 |
| `scripts/ui/split_border_style_box.gd:34` | `set_colors` | 5 |
| `scripts/ui/skill_icon_art.gd:236` | `card_by_id` | 4 |
| `scripts/battle/rescue_npc.gd:71`, `scripts/cards/gauntlet_skill_ui.gd:108`, `scripts/cards/deck_manager.gd:1155`, `scripts/battle/enemy_spawner.gd:449` | `set_prompt_text`, `_pressed`, `get_peaked_card`, `get_enemy_count` | 10 |

> Correction (2026-10-19): `GauntletSkillUI._pressed` is BaseButton's engine virtual, called on every click without any reference in the repo. Its removal left every active gauntlet skill unclickable; it is restored, with `tests/test_gauntlet_skill_button.gd` guarding it. A name beginning with `_` that matches a Godot virtual (`_pressed`, `_toggled`, `_gui_input`, `_draw`, `_process`…) is referenced by the engine, not the repo.

Also certainly dead:
- **Signals declared and emitted but never connected (11):** `tempo_manager.gd:22 turn_triggered`, `draw_timer.gd:7 turn_started`, `:9 player_turn_started`, `player.gd:7 move_started`, `character_animator.gd:7-8 animation_finished/animation_started`, `character_questionnaire.gd:7-8 character_recommended/back_pressed`, `character_select.gd:6 character_selected`, `character_panel.gd:7-8 card_slotted/card_unslotted`, `demo/sprite_character.gd:15 attack_finished`. (`buff_manager.gd:11 invisibility_entered` looked unemitted but is emitted via `emit_signal.call_deferred("invisibility_entered")` at `:88` — **alive**, a good example of why the dynamic check matters.)
- **`@export`s never read:** `item_data.gd:452 fire_resistance_percent`, `:456 movement_per_tempo_bonus`, `character_data.gd:99 sprite_sheet_path`. Caution: `@export`s on `CharacterData` are serialised into saves; removing `sprite_sheet_path` is safe for loading (unknown properties are ignored) but do it knowingly.
- **Members/consts never read:** `card_ui.gd:32 _select_tween`, `player_stats.gd:605 st_seance_specters`, `enemy.gd:351 TRIGGER_EVENTS`, `sprite_enemy_figure.gd:28-29 NPC2, GEN`, `main.gd:8411 SNOWBALL_COUNT`.
- **Orphan import files (3):** `assets/sprites/generated/monsters/fire_goblin_{soldier,mage,shaman}.png.import` — their PNGs no longer exist (the kinds now use `goblins/Goblin*`, `sprite_enemy_figure.gd:KINDS`). Delete the three `.import` files.
- **Stray generated files:** `tests/sim/builds/rankings/ryan_card_swap.csv` is being imported by Godot as a *translation* (`ryan_card_swap.csv.import`, importer `csv_translation`), producing three untracked `.translation` files in your working tree. The file is read with `FileAccess` by `tests/sim/builds/deck_builder.gd:69`, which does not need the importer. Fix: a `.gdignore` in `tests/sim/builds/rankings/` (FileAccess still reads it), and delete the generated `.translation`/`.import` files.

### 3.2 Possibly dead — reachable, but only through paths you may consider retired (needs your decision)
- **`scripts/character/character_figure.gd` (5,116 lines) — the procedural 3D player model.** Reached only when `SpriteFigure.supports(name)` is false (`player.gd:98-103`, `character_panel.gd:531-534`, `character_card.gd:273-276`), and `ROSTER` (`sprite_figure.gd:24-33`) contains all five playable characters plus the Dog dummy. So it runs only for a save whose `get_base_character()` is not one of those names — i.e. pre-`base_character` saves of a renamed character (`character_data.gd:12-16`) — and for `tests/_capture_anim.gd`. `card.gd:1002-1150 get_animation_action` (145 lines) maps cards to its `play_*` verbs, and `action_fx.gd` says it ported CharacterFigure's effect kit. **If** you accept that legacy saves fall back to the character's sprite (a one-line change: resolve unknown names to `character_name`'s preset or a default), the whole file is deletable. Confidence that it is unreachable in normal play: likely. Lines: 5,116 (+ ~145 in card.gd).
- **`scripts/battle/enemy_figure.gd` (3,527 lines) — the procedural enemy models.** In battle it is instanced only for kinds absent from `SpriteEnemyFigure.KINDS`; I diffed the two tables programmatically: exactly three kinds fall through — `brute_minion`, `brute_elite`, `brute_boss` (the legacy `MINION/ELITE/BOSS` placeholder tiers, `enemy.gd:1351-1356`). `ELITE` still spawns in the overworld at world level > 3 (`dungeon_manager.gd:5670`), so it is **alive** today. It is also used by `enemy_inspect_ui.gd:179` (portrait fallback) and the `Enemy Lab` dev tool (`enemy_lab.gd:450`). Retiring it requires giving the three brute tiers sprite art (CLAUDE.md "Art: Packs First" already calls procedural meshes wrong). Lines: 3,527 (+ most of `enemy_lab.gd`'s 682).
- **`scripts/demo/character_viewer.gd` + `sprite_character.gd` + `scenes/demo/character_viewer.tscn` (352 lines):** referenced only by `tests/_capture_sprites.gd:30` and `tools/capture_screens.gd:30`. Dev-only; harmless, but it is a second implementation of the paper-doll logic in `sprite_figure.gd` (`sprite_character.gd:1-30`).
- **Debug regions in `main.gd`:** `#region TEST UI HANDLERS` (`:14352-14557`, 206 lines) and `#region DEBUG: OVERFLOW & REACTION HANDLERS` (`:15550-15866`, 316 lines). The certainly-dead entries above come from these; the rest are still wired to `SandboxUI` signals (`main.gd:4646`) — alive while the sandbox exists.
- **Reflection-reached factories (NOT dead, listed so you don't delete them):** 135 `Card.create_*` and 100 `ItemData.create_*` have no direct caller (the scan flagged them), because `DeckManager._build_card_factory_map`, `Card.create_by_id`, `ItemData.get_all_items` and the shop/compendium discover them with `get_script_method_list()`. Another 57 card and 90 item factories are referenced *only* from tests. All are alive through reflection.
- **Enemy types that exist as enum + data but have no `initialize` arm:** `PIT_FIEND`, `CORRUPTED_ARCHANGEL` (`enemy.gd:1206-1214` default arm warns "design mock-up"). Not dead — design placeholders; leave.

### 3.3 Assets
No image is provably unreferenced (§0). 56.5 MB of the 92 MB `assets/` tree is reachable only through runtime-built folder paths (Craftpix packs 2,823 files, Mana Seed base 357, NPC packs 197, icons 141). Proving individual sheets dead needs a runtime trace (log every `load()` path during a full playthrough + the catalog dump) — out of scope for a static audit, and the packs are the art direction anyway. The `.godot/imported` cache is 70 MB and is correctly git-ignored.

---

## 4. Poor / bloated code

### B1. `main.gd` is a 17,249-line god object (certain, med risk to split)
`scripts/core/main.gd`: 602 functions, 361 top-level vars, 82 `#region`s. Largest functions: `_apply_card_world_effects` **1,204 lines** (`:12295-13498`, one `match card_id` with per-card world logic), `_input` **431** (`:13533`), `_resolve_queued_card` 327 (`:9443`), `_setup_action_buttons` 230 (`:1112`), `_on_hand_card_hovered` 224 (`:3613`), `_ready` 219 (`:522`). 214 lines sit at ≥ 6 indent levels and 29 at ≥ 8 (the most in the project). The regions themselves are the extraction map: `RANGED PASS: SKELETONS, SPIRIT BOWS, MARK ZONES` (804 lines), `BOSS ROOMS` (556), `LOOT DROP SYSTEM` (553), `OVERLAY PICKERS` (512), `OVERDRAW & CYCLE PASSIVES` (468), `DELAYED EFFECT SCHEDULER` (439), `COMMUNAL DONATION UI` (270), `MANAGE DECK` (325), `PILE CONTENTS POPUP` (267)… Each is a self-contained child node waiting to happen (`progression_triggers.gd` was already extracted this way — its header says so at `:3`). The 36 `card_id == "…"` checks in `main.gd` and the 20 `_update_<summon>` / `_helm_*` / `_ranged_*` item-specific functions are the "logic that belongs in a different node" you asked about — summon drivers belong on the summon base class (D1), item riders on the item.
**Fix pattern:** move one region at a time into a `Node` child (`LootSystem`, `BossRooms`, `SummonDirector`, `Pickers`) that receives `main` in `setup()`; keep function bodies verbatim; change call sites to `loot.collect(...)`. **Lines saved:** ~0 directly (it is relocation), but it is what makes everything else reviewable; do the regions whose functions are called only from inside the region first (`LOOT DROP SYSTEM`, `COMMUNAL DONATION UI`, `BOSS ROOMS`).

### B2. Long `match`/if chains that should be lookup tables (certain, low risk)
- `card.gd:15-33 keyword_name()` — 16-arm enum→string match → one `const` dictionary (−15 lines, and `slot_label_names` :515 can index it).
- `card.gd:1006-1150 get_animation_action()` — 145 lines of `card_id` → verb → a dictionary.
- `enemy.gd:1291-1370 _setup_sprite()` — 70-arm type→kind match → part of the enemy def (D2).
- `enemy_spawner.gd:316-348 get_loot_tier()` and `enemy.gd:1878-1951 _type_display` — the same tier column twice → one table (D2).
- `enemy_spawner.gd:239-288` four drop-chance functions each with a hand-tuned `match` then a tier `match` → one `{type: {item, card, stone}}` table (−30 lines).
- `dungeon_manager.gd` has 67 `elif`s, `main.gd` 64, `enemy.gd` 51 — mostly `elif kind == "…"` ladders in decoration builders (`_build_decorations` :3137, 157 lines).

### B3. Magic numbers (certain, low risk)
The 5-tempo cycle is written as a literal `5` in ~35 places (`enemy.gd:2552-2555 while _cycle_accumulator >= 5`, `:2500,2520,2535 regen every 5`, `apply_debuff` `frozen_tempo = max(frozen_tempo, 5)` :7398, `polymorph` `ceili(value / 5.0)` :7453, `main.gd`, `effects/*.gd`) even though `TempoManager.tempo_threshold` (`tempo_manager.gd:31`) and `Enemy.STACK_TEMPO` (`enemy.gd:183`) exist. Replace the literals with a `const CYCLE_TEMPO := 5` (do **not** bind them to the `@export tempo_threshold`, which would change behaviour if someone edits it). Likewise the hover-stack offsets, `0.1` snap distance (`player.gd:194`, `enemy.gd:6453`), `1.2` hover radius (`main.gd:1054,1092`), glide speed `3.5` (`enemy.gd:6446`).

### B4. Static typing gaps (certain, med risk to fix blindly)
4,773 untyped `var x = …` (main.gd 1,224, dungeon_manager 539, card.gd 408, town 268, item_data 209, progression_triggers 204, enemy 204) and 322 untyped parameters; return types are nearly universal (4,512 of 4,523). Typed locals are faster in GDScript 2 and catch mistakes, **but** adding `: int` to a value that is sometimes a float (or vice-versa) silently changes rounding, and `Array` → `Array[X]` changes assignment semantics. Do this only in the hot files (`card.gd` executors, `enemy.gd` damage/tick paths, `player_stats.gd`), function by function, with the sim run after each file. Several deliberately untyped members exist to avoid class-cache cycles (`deck_manager.gd:27-30`, `main.gd:42`) — leave those.

### B5. Repeated node lookups → `@onready` (certain, low risk)
`card_ui.gd:215,268,372,436` `get_node_or_null("Panel")` ×4; `player2_ui.gd:79,162,192,244` and `chest_loot_ui.gd:44,391,454` `main.get_node("UI")` ×7; `main.gd` `$UI` ×30 and `$UI/HandArea` ×4; `town.gd` `$UI` ×16, `$Vendors` ×7; `dungeon_manager.gd:6711` `get_node_or_null("InteractLabel")` per chest per frame (P2). Each `$`/`get_node` is a path parse + tree walk; cache once.

### B6. Duck typing where the type is known (certain, low-med risk)
378 `has_method(` sites (main 98, card 86, enemy 72), 24 `get_parent()` casts from `enemy.gd` into Main (`:6483,6529…`), `player.gd:206-208` likewise. Where the receiver is always an `Enemy`/`Player`/`Main`, the guard is a string hash per call and hides the dependency. Replace with typed references or an injected `main` reference in the files you are already touching; leave the genuinely polymorphic ones (summons vs players in `take_damage` callers) until D1 gives them a shared type.

### B7. Two reflection sweeps build the card catalogue; item catalogue rebuilt on every call (certain, low risk)
`deck_manager.gd:344-365` and `card.gd:9089-9105` are the same factory map built twice (every sweep instantiates all 247 cards). `item_data.gd:3337-3346 get_all_items()` instantiates all 190 items on **every** call and is called from 16 sites including per-kill loot (`enemy_spawner.gd:353-360`, `drop_rates.gd`). Fix: `DeckManager._create_card_from_id` delegates to `Card.create_by_id`; `ItemData` caches the factory *method names* once and still returns fresh instances. Identical output, less startup/kill-time work (**needs profiling** for magnitude; provably redundant).

### B8. Naming / hygiene nits (certain, low risk)
- `summoned_skeleton.gd:17-20` `var BASE_ATTACK / MOVE_INTERVAL / MOVE_STEPS / ATTACK_INTERVAL` are mutable but ALL_CAPS (they are retuned in `setup`); rename to snake_case in D1.
- Misspelled ids that are **save-compat and must not be renamed**: `create_theif_hat`, `create_assasian_belt`, `create_alchemeist_belt` (`item_data.gd:1244,1794,1879`), `SEWER_CROC` named "Sewer Cobra" (`enemy.gd:1016`). Leave; comment.
- `scenes/core/main.tscn:66-71` keeps a dark `GroundPlane` and a 45° camera that `main.gd` replaces at runtime (`CameraView`); harmless but misleading in the editor.
- `enemy.tscn`/`player.tscn` ship a BoxMesh/Capsule + `Outline` that the figure code hides (`enemy.gd:1379-1383`, `player.gd:107-115`); `Outline` is still used for hover (`enemy.gd:7564`). Keep.

---

## 5. Observations that are *not* refactor items (possible bugs — reporting, not fixing, per your rules)
1. **`Card._exec_depth` leaks on a blinded miss.** `card.gd:1362 _exec_depth += 1`, but the Blind early `return` at `:1409` skips the `_exec_depth -= 1` at `:2640`. After one blinded miss in a session, every later card resolve takes the `_exec_depth > 0` branch (`:2641-2647`) and restores the snapshot instead of resetting `PlayerStats.adaptive_damage_type`/`hit_multiplier` (`:2648-2653`). Whether that is observable depends on riders; it is at least a latent state leak. Fixing it changes behaviour → out of scope for Phase 3; flagging for you.
2. `enemy.gd:6464-6470` the Inflamed Minotaur wake-fire hook calls `get_parent().register_fire_wall(...)` from `_physics_process`, i.e. frame-timed, not tempo-timed. Probably intended (it is per tile), noting only because it is the one gameplay effect driven from the physics loop, which matters for P5.
3. `player.gd:204-230` stuck detection cannot trigger (P5), so the `print("[PLAYER] Movement blocked…")` path is dead in practice.

---

## 6. Summary

| Category | Findings | Est. lines removable now (behaviour-neutral) | Est. additional if you approve the "possibly dead" deletions |
|---|---|---|---|
| 1. Duplication | D1–D7 (7 clusters) | ~1,350 (D1 650, D3 400, D6 120, D7 ~180) + ~800 moved from code to data in D2 | — (D5's −6,000 is a later migration, not Phase 3) |
| 2. Graphics / perf | P1–P12 (12; 3 are "fine, no action") | ~0 (perf steps are rewrites, not deletions) | — |
| 3. Dead code | 37 functions, 11 signals, 3 exports, 5 members/consts, 3 orphan imports, 1 stray import | ~500 | ~5,300 (`character_figure.gd` + its `get_animation_action` map) and ~4,200 (`enemy_figure.gd` + `enemy_lab.gd`) |
| 4. Bloat | B1–B8 | ~150 (tables, lookups) + relocation of ~6,000 lines out of `main.gd` | — |
| **Total** | **~60 findings** | **≈ 2,000 lines deleted, ≈ 7,000 relocated/converted to data** | **≈ 9,500 more** |

**Top 5 highest-impact, lowest-risk items**
1. **Dead code removal (§3.1)** — 462 lines of functions + 11 signals + exports/consts + 3 orphan `.import`s + the CSV translation import. Certain, zero gameplay impact, verifiable by parse test + sim.
2. **Import hygiene (P1, P7)** — `detect_3d/compress_to=0` on all 5,149 textures; `shadow_enabled=false` + light rotation in the two `.tscn`s to match the scripts. Certain, zero gameplay impact; prevents a future art regression.
3. **Summon base class (D1)** — ~650 lines gone, eight files become one family, and main's summon drivers get a type. Low risk; every summon is exercised by the sim builds (wolves, skeletons, spirit bows, penguin, clones, frankenstein, worms, specters all appear in `tests/sim/builds`).
4. **Gate the per-frame prompt/fog updaters on cell change (P2) + stop rewriting theme overrides every frame (P3) + rebuild the AOE mesh only on change (P4)** — provably redundant work in the three busiest `_process` bodies; display-only; measure with Process Time and Draw Calls before/after.
5. **Enemy definitions into one data table (D2)** — removes the six-way duplication and makes a new enemy a data entry. Medium transcription risk, but `dump_catalog.gd` gives a byte-exact check of every number for all 66 types, and the sim covers the roster.

Deliberately **not** in the top 5 despite size: the card/item `.tres` migration (D5) and splitting `main.gd` (B1) — both are large, both are the right long-term direction, and both need a longer runway than one-commit-one-step; they are sequenced at the end of `PLAN.md` as optional follow-ons.
