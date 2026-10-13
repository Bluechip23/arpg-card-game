# Headless combat simulation — Milestone 0 audit

Scope: can a bot-driven combat run through the real `main.tscn` pipeline under
`godot --headless`, deterministically, many times per process? Everything below
was read from the code or measured on this checkout (`9cbadf5`, Godot
4.6.stable). Line numbers refer to that commit. Nothing was changed.

Verdict first: **booting `main.tscn` headlessly is workable.** The rules are
synchronous and tempo-driven; only three wall-clock mechanisms sit between the
sim and the rules (the card tick pump, unit movement interpolation, and a 0.6 s
wave-clear delay), and each can be driven from a sim clock without touching
rules. One boot costs ~2.4 s; a 30-tempo exchange costs ~160 ms, so a combat is
well under a second and a process can run hundreds of combats after one boot.
Four things need a scripted answer or runner-side care, none of them a rules
change: Olorin's tutorial pause on the first enemy spawn, point-aimed cards
reading the live mouse at resolve time, the resolve-time pickers (Peshtigo,
Crack of Mintaka, Life Swap, …), and the deferred Cover tempo. One
one-line shim is proposed for sign-off (Defensive Sacrifice, §8). Details in
§5 and §8.

---

## 1. Minimum node set

There is no smaller set than `main.tscn` itself. The card pipeline is wired
inside `Main._ready()` (`scripts/core/main.gd:520-805`) and every stage below
lives on `Main` or a child the scene instantiates:

| Stage | Script | Lives at |
|---|---|---|
| Hand / piles / deferred play | `scripts/cards/deck_manager.gd` (`DeckManager`) | `$DeckManager` (`main.gd:5`) |
| Tempo clock + ticked queue | `scripts/battle/tempo_manager.gd` (`TempoManager`) | `$TempoManager` (`main.gd:28`) |
| Card draw cadence | `scripts/battle/draw_timer.gd` (`DrawTimer`) | `$DrawTimer` |
| Player body, movement, stats, buffs, debuffs, inventory | `scripts/character/player.gd` + `$PlayerStats`, `$Inventory`, `$DebuffManager`, `$BuffManager` (`player.gd:14-17`) | `$Player` (`main.gd:27`) |
| Grid / distance | `scripts/battle/grid_manager.gd` (`GridManager`) | `$GridManager` (`main.gd:8`) |
| Enemies | `scripts/battle/enemy_spawner.gd` + `scenes/battle/enemy.tscn` (`scripts/battle/enemy.gd`) | `$EnemySpawner` (`main.gd:12`); enemies are added as children of `Main` (`enemy_spawner.gd:54`) |
| Passives / keystones / sphere triggers | `scripts/progression/progression_triggers.gd` | created in `_ready` (`main.gd:526-528`) |
| Terrain, line of sight, elevation, interior layout | `scripts/core/dungeon_manager.gd` | created in `_setup_dungeon()` (`main.gd:13629`) |
| Card rules | `scripts/cards/card.gd` | resources, no node |
| Items | `scripts/progression/item_data.gd`, `inventory.gd` | on the player |

The resolution path, all synchronous (no `await`, no timers), is:

```
play_selected_card(target)            main.gd:8864   validates nothing about range; pays mana, queues
  deck_manager.play_card(i, t, p, true)  deck_manager.gd:469   legality + mana; removes from hand
  _pending_resolve_queue.append(...)     main.gd:8988
  tempo_manager.add_card_tempo(...)      main.gd:9032   (or _resolve_queued_card at once if 0 tempo / Steady)
TempoManager._process_one_tick()      tempo_manager.gd:120  (one per tick; emits card_resolved on resolve_tick)
  _on_card_tick_resolved(card)           main.gd:9062
  _resolve_queued_card(card)             main.gd:9205
    arm_pre_attack_passives / Stephen-Brad-Cory on_attack bonuses   main.gd:9298-9313
    deck_manager.execute_deferred_card(card, target, player)      deck_manager.gd:867 → Card.execute()
    sphere + skill-tree triggers, crit passives, ring riders       main.gd:9330-9371
    _apply_card_world_effects(card, target)                        main.gd:11961 (the 72 world-effect arms)
    Skilled Momentum echo, scope close                             main.gd:9375-9398
  tempo_advanced → _on_tempo_advanced     main.gd:6080  (buff/debuff timers, enemy_spawner.on_tempo_advanced, summons, draw timer, mana regen)
  tempo_threshold_reached → _on_tempo_threshold_reached  main.gd:7654  (per-cycle: DoTs, deck.process_turn, armor decay, hand RNG reroll)
```

Enemies respond inside `enemy_spawner.on_tempo_advanced(amount)`
(`enemy_spawner.gd:92-99`) → `Enemy.on_tempo_advanced(amount, target)`
(`enemy.gd:2166-2258`), which is called from `_on_tempo_advanced` at
`main.gd:6116`.

How the existing tests boot it (`tests/test_peshtigo_live.gd:21-26`):

```gdscript
var packed: PackedScene = load("res://scenes/core/main.tscn")
_main = packed.instantiate()
_main.set("starting_character", CharacterData.create_brad())
_main.set("current_interior_id", "dojo")
get_root().add_child(_main)
# wait ~12 frames, then drive it
```

24 of the 97 `tests/test_*.gd` files boot `main.tscn` this way. The sim will do
the same. `current_interior_id = "dojo"` is the right sandbox: a flat 1-room
building, no story spawns, no fog, no fountains (`dungeon_manager.gd:1353`);
`Main._setup_dojo()` (`main.gd:16313`) adds four `DUMMY` enemies and two ally
dummies, which the sim removes (`enemy_spawner.enemies.erase(d); d.queue_free()`)
before spawning the scenario's enemies with
`enemy_spawner.spawn_enemy(type, grid_manager.grid_to_world(cell))`
(`enemy_spawner.gd:52`). `sandbox_mode` is not suitable: `_setup_sandbox()`
(`main.gd:4531`) forces 999 mana and opens UI.

`starting_character` must be set before `add_child`, with
`seen_tutorial_ids` pre-seeded so Olorin never pauses the tree (§5);
`select_character()`
(`main.gd:4158`, called at 634) builds the deck via `deck_manager.initialize_deck`. Level,
stats, passives and gear are then set the way `tests/_build_sims.gd` does
(`stats._level_up()` ×N, `apply_stat_allocation`, `add_skill_tree_passive`,
`inventory.equip_item(ItemData.create_x())`), and extra deck cards with
`deck_manager.add_card_to_deck_from_id(id)` (`deck_manager.gd:1140`).

## 2. Entry points for "play card X at target Y" and movement

**Cards.** There is a direct function pair, no synthetic input needed:

- `select_card(index: int)` — `main.gd:8593`. Index into `deck_manager.hand`.
  Applies `world_block_reason()` and sets `selected_card_index`; also touches
  the AOE/range indicators (harmless headless).
- `play_selected_card(target)` — `main.gd:8864`. `target` is an `Enemy`,
  the `Player` (self / all_nearby / point cards), or `null`. Everything from
  Tighten String, High Ground, Harnessed Power, Arcane Overflow, the queue
  entry and `add_card_tempo` happens here (lines 8898-9053).
- Point-aimed cards read `_last_aim_world` (`main.gd:13456`) at play time
  and **the live mouse** at resolve time (`main.gd:11962`): the sim sets the
  former and parks the mouse for the latter (§5, verified).

**What the UI does that `play_selected_card` does not**, i.e. the legality
the sim must enforce itself (it lives in the left-click handler,
`main.gd:13419-13520`):

| Check | Where | Function to reuse |
|---|---|---|
| Target in range / line of sight | 13443, 13485 | `_is_target_in_card_range(card, target)` (`main.gd:11834`) — melee 1.5 tiles (+reach), ranged `_ranged_card_max_range` + 0.5, LOS via `dungeon_manager.has_line_of_sight` |
| Needs high ground | 13441 | `card.requires_high_ground`, `_has_high_ground(player.position, enemy)` (`main.gd:15186`) |
| Point card range cap | 13461-13467 | `card.get_effective_range()` vs `grid_manager.get_distance_in_cells` |
| Target-type routing | 13429-13520 | `card.target_types` (+ Poisoned Blood lets heals target enemies) |
| Glut / co-op confirm | 8871-8882 | inside `play_selected_card` already |
| Mana, stun, silence, disarm, jail, engrave, Heavy Swing | `deck_manager.play_card` 469-535 | returns `{"played": false}` — the sim treats that as illegal |

Picker cards (Release Tension, Sky Attack, Mirror Mirror, Collect Arrows,
Reposition, Friendship — `main.gd:13446-13525`) set `card.picked_card` /
`picked_cards` / `picked_ally` on the card before `play_selected_card`. The
sim's `Action` carries those picks; the UI pickers are never opened.

**Basic attack.** `_execute_basic_attack(target: Enemy, free := false)` —
`main.gd:2215`. Does its own reach check (`_basic_attack_reach`, 2491) and
queues through the same tick system with `is_basic_attack` data (2355-2383).

**Block / Wait.** `_on_block_pressed()` (`main.gd:2387`) and
`_on_wait_pressed()` (`main.gd:2427`, `tempo_manager.add_tempo(1)`).

**Movement.** `player.move_to_grid(world_pos, spaces) -> bool`
(`scripts/character/player.gd:315`). This is what the right-click handler and
the "Move N spaces?" dialog call (`main.gd:13590`, `_on_move_confirmed`
4439). It BFS-paths (`calculate_path_to`, 261), applies Haste, trims the
tail, sets `is_moving` and the first `target_position`, and returns false when
stunned/rooted/webbed/already moving. The route length the UI shows is
`_route_length(world)` (`main.gd:4436`). The sim must also honour
`_movement_locked()` (`main.gd:4409`: no move orders while the owner's ticks
run), which the input handler checks at 13566. The per-tile tempo is charged
by `_on_player_tile_reached` (`main.gd:4320`) when the body arrives — see §3.

**Gauntlet skills / quiver cards** have their own entry points
(`_fire_gauntlet_skill`, `play_quiver_card`, `main.gd:13380-13417`); M1
supports cards, basic attack, block, wait, move. Gauntlet skills are an M2
addition if a scenario equips such an item.

## 3. Wall-clock dependencies

Measured and read: the rules clock is integer tempo. Only these touch real
time.

| # | Where | What it gates | Sim treatment |
|---|---|---|---|
| 1 | `TempoManager._process(delta)` `tempo_manager.gd:67-74`; `tick_speed = 1.5 s` | The only link between "card played" and "card resolves": one `_process_one_tick()` per `tick_speed` | **Drive.** `tempo_manager.set_process(false)`; the runner calls `_process_one_tick()` (synchronous, 120-162) in a loop until `not is_ticking()`, or interleaves a decision between ticks. Verified: a Slash queued and ticked this way kills a Wererat with no frames pumped. |
| 2 | `Player._physics_process` `player.gd:180-259`; `move_speed = 5` | Tile arrival fires bleed, Approach, `tile_reached` (→ `_on_player_tile_reached` charges movement / pass-through / climb tempo, traps, fire walls, loot), `move_completed` | **Snap-step.** After `move_to_grid`, loop: `position.x/z = target_position.x/z; _physics_process(1/60)`. The real arrival body runs in order; the whole route resolves synchronously. Verified: a 2-tile order charged 2 tempo and ended on the right cell. |
| 3 | `Enemy._physics_process` `enemy.gd:4942-5019`; `move_speed = 2.5` | Per-tile bleed damage, Minotaur wake fire, `movement_completed` (→ traps, melee-entry reactions `main.gd:6339`), `turn_completed` | **Snap-step**, same loop, after every tempo unit. Verified: a Wererat at range 3 walks in over two 2-tempo moves and bites on the 8th tempo (`[Wererat] Bite for 3 damage!`). |
| 4 | `Enemy._idle_ambient(delta)` `enemy.gd:5023-5040` | Idle pacing when no target is within `aggro_range`; draws `randf_range` + `shuffle` from the **global RNG** on a seconds timer | **Suppress.** Never runs if the sim never pumps physics frames with an idle enemy (the snap loop calls `_physics_process` only while `is_moving`). Scenarios start within aggro anyway. Documented hazard, not a rule. |
| 5 | `enemy_spawner._on_enemy_died` `enemy_spawner.gd:173` `await create_timer(0.6)` | Delays `all_enemies_defeated` → `_on_all_enemies_defeated` (clears summons / zones) | **Bypass.** The runner decides "win" from `get_living_enemies()` itself; between combats it pumps a few frames so the pending coroutine fires on the old wave. |
| 6 | `_cover_mitigation` `main.gd:15343` `tempo_manager.call_deferred("add_tempo", …)` | Cover reaction's tempo lands at end of frame | **Flush.** Pump one frame (`await process_frame` in the runner) after each enemy action batch when a Cover card is in play. |
| 7 | `offer_defensive_sacrifice` `main.gd:5902-5944` `get_tree().paused = true` + UI picker | Enemy hit is held until the player answers | Only reachable through `get_tree().current_scene` (`enemy.gd:4760`), which is **null** under a `--script` boot, so it never fires in tests or the sim. See §5/§8. |
| 8 | `Main._process` `main.gd:805-849` | Hover, prompts, fog, minimap, AOE cursor; no rules | **Skip** (`_main.set_process(false)`). Idle frame time stayed 7 ms either way, so the cost is elsewhere (physics + figures); the sim just doesn't pump frames. |

Not wall-clock, confirmed:

- **Card draw**: `DrawTimer.process_tempo(amount)` (`draw_timer.gd:31`), a flat
  25 global tempo; WIS no longer scales it (`player_stats.gd:1546`). Extra
  draws come from brain points.
- **Hand RNG reroll**: `_reroll_card_rng()` (`main.gd:8341`) runs at cycle
  boundaries (7745) and rerolls a card once `global_tempo - rng_roll_tempo >= 15`
  (`card.gd:838`). Pure tempo.
- **Buff/debuff durations** advance on raw tempo (`main.gd:6089-6100`), per-cycle
  effects on the 5-tempo cycle. Enemy statuses tick on the enemy's own
  `_cycle_accumulator` (`enemy.gd:2253`).
- **Enemy wind-ups, channels, disrupts**: integer counters only
  (`enemy.gd:2482-2662`). No overflow carry: `_fire_ready_sync` resets the
  counter to 0 and re-chooses at once (2598-2613), so the next intent is
  visible immediately. `async`/`trigger` keywords are implemented
  (`_fire_ready_async` 2615, `fire_trigger` 2713) but no `actions_for_type`
  entry uses them yet; the harness supports them by construction since it
  only calls `on_tempo_advanced`.
- Tweens (damage numbers, flashes, death shrink, shuffle animation) are
  visual. The shuffle animation `_animate_shuffle` (`main.gd:11951`) and the
  damage-number jitter (`player.gd:534`, `enemy.gd:5613`) **do consume global
  RNG**, deterministically; they stay as they are.

## 4. Reading the state at a decision point

All cheap property reads; nothing is hidden behind UI.

| Thing | Read |
|---|---|
| Player HP / max | `stats.current_health`, `stats.max_health` (`player_stats.gd:107-108`) |
| Mana | `stats.current_mana`, `stats.get_available_max_mana()` (2342), `maintained_mana` |
| Armor | `stats.get_total_armor()` (177) = `current_armor + unerring_armor` |
| Temp HP | `stats.current_temp_health`, `temp_health_tempo_remaining` (208-209) |
| Flash / brain points | `current_flash_points`, `get_max_flash_points()`, `current_brain_points` |
| Player cell | `grid_manager.world_to_grid(player.position)`; `player.intended_cell()` while moving |
| Hand | `deck_manager.hand` (cards), `draw_pile.size()`, `discard_pile`, `maintained_cards`, `jail_pile`; hand cap `get_hand_cap()` |
| Card facts | `card_id`, `card_type`, `school`, `mana_cost`, `tempo_cost`, `resolve_tick`, `base_damage`, `block`, `heal_amount`, `is_ranged`, `get_effective_range()`, `target_types`, `is_aoe`, `keywords` (`card.gd:416-537`) |
| Card cost as charged | computed inline in `deck_manager.play_card` (539-640); the displayed cost is `card_ui.gd:97-100`. The sim exposes a `estimate_cost(card)` helper that mirrors the UI formula (mana − `temp_mana_discount`, tempo + `get_conditional_tempo_penalty()` − `temp_hand_tempo_reduction`, DEX proc halving) and treats `play_card` returning `played=false` as the authority |
| **Rolled outcomes** | `card.rng_selected_index` (−1 unrolled, −2 binary fail, ≥0 outcome), `card.rng_outcomes[enemy_instance_id]` for AOE, `card.rng_effective_chance` (`card.gd:446-458`). Rolled in `_on_hand_updated` (`main.gd:7270-7276`) on every hand change, exactly when the human sees them. The bot reads the same fields the card face shows. |
| Player buffs / debuffs | `player.get_buff_manager().buffs` (`Buff.buff_type/value/duration/stacks/charges`), `get_debuff_manager().debuffs`; helpers `can_play_cards()`, `can_move()`, `is_slowed()`, `get_tempo_increase()` |
| Enemy | `current_health`, `max_health`, `current_armor`, `is_exposed`, `enemy_type`, `enemy_name`, `attack_range`, `aggro_range`, `grid_manager.world_to_grid(e.position)`, `e.intended_cell()` |
| Enemy statuses | `enemy.get_active_effects()` (`enemy.gd:6110`) — the same list the status icons show |
| **Enemy intent** | `enemy.get_display_action()` (`enemy.gd:2731`) → `{name, label, counter, cost, kind}`: the overhead bar. `chosen_action` / `action_tempo_counter` are the raw fields |
| Tempo | `tempo_manager.current_tempo`, `global_tempo`, `tempo_threshold`, `is_ticking()`, `owner_is_busy()`, `get_active_card_progress()`; draw countdown `draw_timer.tempo_until_draw` |
| Pending resolves | `_main._pending_resolve_queue` (card, target, data) |

Hidden information the bot must **not** read: `deck_manager.draw_pile` order
(only its size, `peaked_card`, and `get_brain_peeked_cards()`), crit rolls
(`buff_manager.roll_crit()` is live at resolve), Blind/Clumsy misses, and the
enemy's `_choose_action` internals beyond `get_display_action()`.

Note for the CSV: `card_entropy` and `distinct_cards_played` key on `card_id`;
`rng_outcome_used` is `rng_selected_index` at play time.

## 5. Blocking and modal flows

Nothing on the play → resolve path awaits. What can stall or silently divert
a headless, bot-driven run, with the bypass for each:

**Pauses the tree** (`get_tree().paused = true`; stops `_process`/physics,
not direct calls):

| Flow | Where | Trigger | Plan |
|---|---|---|---|
| Olorin `combat_intro` | `main.gd:6244` → `olorin.gd:158`, pause at `olorin.gd:459` | **Any enemy spawn, including the dojo dummies in `_ready`**, when the character's `seen_tutorial_ids` lacks it. A fresh `CharacterData.create_brad()` boots paused | Before `add_child`: `c.seen_tutorial_ids.append_array(["combat_intro","field_tour","item_levels_intro","doughnut_keep","first_climbable_tree"])`. Verified: the probe boots with `paused=false`. Belt and braces, as 8 tests do: `while olorin.is_busy(): olorin._close()`. Setting `_main.olorin = null` after boot is also safe (every call site checks). |
| Olorin doughnut / item-level beats | `main.gd:6471`, `15528`, `15882` | first Wererat / Archer Rat kill on world 1 | same seed list |
| Olorin `trial_strike` | `main.gd:6465`, `6515` | `TrialSystem.on_kill` on non-sandbox kills with a `player_progression` | keep `player_progression` empty (the sim builds the character directly) |
| Defensive Sacrifice | `main.gd:5903-5944`, pause at 5919 | enemy hit while the card is in hand; reached only via `enemy.gd:4760 current_scene` | unreachable headless today (§6). If the shim in §8 is accepted, the runner answers the `"DefensiveSacrificePrompt"` Button under `$UI` by policy |
| Pause button | `main.gd:2047` | the bot would have to press it | never sent |

**Resolution-time prompts** (synchronous, but the effect only completes when
answered; the runner scans `$UI` after every resolve and answers by policy):

| Card / flow | Where | Answer |
|---|---|---|
| Peshtigo's Kiss maintain prompt | `_offer_to_maintain` `main.gd:10653`, called at 12292; flames exist only after the answer | `_maintain_prompt` Button "Maintain" / other → `pressed.emit()` (what `test_peshtigo_live` does) |
| Crack of Mintaka | `show_hand_multi_picker` 12123 (5647); all damage is in the "Done" callback | toggle candidate buttons in `"HandMultiPicker"`, press "Done" |
| Life Swap with 2+ adjacent enemies | `_pending_enemy_pick` 12484, answered by click 13398 | `_life_swap_strike(enemy, _pending_enemy_pick.damage); _pending_enemy_pick = {}` |
| Communal Donation | `_open_donation_panel` 13144/14770; `_donation_active` blocks input | `_on_donation_confirmed()` / `_on_donation_cancelled()` |
| Slot-discard pickers (coloured slots, shield on-self) | 10883-10915 → `show_hand_card_picker`; auto-resolve with 0-1 candidates (5731) | press a candidate in `"HandCardPicker"` |
| Point to Prove (Brad) | `progression_triggers.gd:1247`; non-blocking | `point_to_prove_dialog._on_yes_pressed()` / `_on_no_pressed()` |
| Click-path pickers (Sky Attack, Reposition, Mirror Mirror, Collect Arrows, Friendship, Release Tension) | `main.gd:13446-13525` | set `card.picked_card` / `picked_cards` / `picked_ally` before `play_selected_card`. Without it Sky Attack whiffs for 0 (`card.gd:3776`), Reposition/Mirror pick at random, Friendship fails solo |
| Overflow (Manifest / Quiver) | cards parked in `manifest_ui` / `quiver_ui` | `_on_manifest_card_clicked(idx)` 14107, `play_quiver_card` 14217 |

**Live mouse read at resolve time.** `_apply_card_world_effects` reads
`get_mouse_world_position()` at `main.gd:11962` for point-landing cards
(Its Alive, Ice Grenade, Poison Bomb, Smoke Bomb, Shift, Escape and Bewilder,
Terrain Formation, Wrath of the Sea, Heroic Leap, Snowball's Chance, Sky
Fall, Round 'Em Up, Blink; gauntlet Suck / Rise), and the `target.position if
target else mouse` family (Fireball, Peshtigo, Sprinkle Bomb, Spirit/Balistic
Arrow, Earth Rattle, Roll, Charge). Headless, the mouse sits at (0,0).
**Verified bypass:** before playing, build the aim's screen point with
`_main.world_to_screen(aim)` and park the mouse with
`Input.parse_input_event(InputEventMouseMotion)`; `get_viewport().get_mouse_position()`
then returns it and `get_mouse_world_position()` resolves to the aimed cell
(probe: aim cell (12,11) → world (12.5, 0, 11.5) → cell (12,11)). The runner
also sets `_main._last_aim_world`, which play time stores for Deadly / Seance.
Because the queue can hold several point cards, the runner re-parks the mouse
on each card's aim immediately before its resolve tick.

**Not modal but relevant to results:**

- **Solo death** (`_on_solo_player_died` `main.gd:4973`): no pause, shows a
  "FallenOverlay" with a Rise button; play continues at 0 HP. The runner ends
  the run as `loss` the moment `stats.current_health <= 0` and never calls
  `_respawn_at_level_start()`.
- **Victory**: `_on_all_enemies_defeated` is non-modal and 0.6 s late (§3);
  the runner declares `win` from `get_living_enemies()` (structures excluded).
- **Level-up** (`player_stats.gd:2643-2664`) banks points and **fully heals HP
  and mana**. Real enemies grant XP. For a balance sim that is a confound:
  the scenario gets a `grant_xp: false` default that disconnects
  `enemy.xp_reward` from `gain_xp` (by zeroing `xp_reward` on spawned
  enemies, no rules change); progression sweeps (3e) set levels directly.
- **Loot / interactions**: loot piles are picked up by walking (non-modal);
  chests, fountains, waypoints, exits are Shift-only (`main.gd:13221`) and a
  Shift on an exit frees `Main`. The bot never emits input events other than
  the parked mouse motion.
- **Co-op** is out of scope for M1 (every play would open Play Now / Lock In).
- **The dojo's dummies** refill instead of dying (`enemy.gd:5562`) and give 0
  XP, so the sim removes them and spawns real enemies; the dojo's Reset button
  and tutorial lock are inert headless.
- **Static state across sequential boots in one process**:
  `PlayerStats.incoming_mitigation_hook`, `CardUI.value_provider`,
  `Card.active_element_remap`, `Card.play_scope_open`,
  `PlayerStats.harnessed_mult`. The runner keeps one `Main`, so these are set
  once; the reset routine clears the `Card` statics between runs.

## 6. `enemy.gd` reaching `main`

All 19 indirect lookups resolve under the headless `main.tscn` boot because
enemies are children of `Main` (`enemy_spawner.gd:54`) and every one of them
goes through `get_parent()` guarded by `has_method` / `"x" in main`:

`_foes_in_play` 3099, `_thorns_strike_back` 3250, `_sibling_enemies` 3324,
`_try_fire_wall` 3719, `_player_units` 3918, `_try_vanish` 4020,
`_necro_spawn` 4224, `_try_breath_swarm` 4257, `_try_fire_breath` 4386,
`_try_bull_rush` 4427/4470, Minotaur wake 4981, `_ambient_target` 5051,
`_player_sphere_amp` 5285, `take_damage` 5513/5520/5539, `_spawn_damage_number`
5615 (unguarded `get_parent().add_child`, fine under Main),
`_consumed_explode` 6047. They want `main.player`, `main.enemy_spawner`
(`_living_players`, `spawn_enemy`, `despawn_enemy`), and
`main.register_fire_wall`. Injected callables (`ground_y_provider`,
`unit_cells_provider`, `nest_provider`, `gravestone_provider`, …) are set in
`_on_enemy_spawned_connect_debuffs` (`main.gd:6213`) for any spawn through the
spawner.

The one exception: `enemy.gd:4760` uses `get_tree().current_scene` to offer
Defensive Sacrifice. Under `--script` boots `current_scene` is null (nothing in
`main.gd` or the tests sets it), so the prompt is silently skipped — in every
existing test too. The sim inherits that behaviour; the card is simply not in
the baseline deck. Proposed, not applied: change that line to `get_parent()`
and give the prompt a scripted answer (§8).

Neither autoload (`UiTheme`, `Palette`) is referenced by enemy code.

## 7. Runtime

Measured headless on this container with throwaway profiler scripts (Brad, dojo, one Wererat); nothing was added to the repo for it:

| Step | Cost |
|---|---|
| Godot start + script load, no scene | 2.0 s |
| `load("main.tscn")` | 1.94 s (script compile of 100k lines) |
| `instantiate` + `add_child` + first frame (`_ready`, dungeon, UI) | ~0.5 s |
| Idle frame (not needed by the sim) | 7 ms |
| `tempo_manager.add_tempo(1)` with one Wererat | 3.5–6 ms |
| 30 tempo of a Wererat closing and biting, snap-stepped | 162 ms |
| `_on_tempo_threshold_reached(1)` (one 5-tempo cycle) | 8 ms |
| `_on_hand_updated()` (rebuilds CardUI; also rolls card RNG) | 3.8 ms per hand change |
| `_refresh_unit_tracker()` | 1 ms (called ~2× per tempo) |
| One card play + ticks to resolve | ~10-20 ms |

So a 60-tempo solo fight is roughly 0.3-0.5 s and the boot is paid once per
process. **The runner keeps one `Main` alive and resets between runs** (clear
enemies, respawn, reset HP/mana/armor/buffs/debuffs, `deck_manager.restore_deck_state`,
re-seed) rather than re-instantiating; 100 seeds of the baseline ≈ 1 minute.
If that reset proves leaky, the fallback is re-instantiating `main.tscn` per run
(+0.5 s each, the 1.9 s load is cached).

Stubs that would help but are not needed to get under a second: the two UI
rebuilds above (`_on_hand_updated`'s CardUI construction and
`_refresh_unit_tracker`) are ~60% of a tempo step. Both carry rules
(`_on_hand_updated` rolls RNG and assigns hexes), so they stay; a later,
rules-neutral speed-up would be to gate only the `CardUI.instantiate` part on
`hand_container.visible`. Rendering, meshes, `_set_mesh_color`, audio and
screenshots cost nothing measurable headless.

## 8. Decisions and proposed shims (none applied yet)

1. **Boot `main.tscn` in the dojo, once per process; run many seeds.** The
   dojo layout is deterministic (`dungeon_manager._rng` is seeded from
   `hash("layout_w%d_%s")`, independent of the global seed).
2. **Drive time from the runner**: `seed(n)` → `_process_one_tick()` loop
   for cards, snap-step loop for movement, no frame pumping except one
   `process_frame` per enemy batch to flush deferred Cover tempo.
3. **Determinism**: every combat roll uses the global RNG (~100 call sites,
   no private `RandomNumberGenerator` in combat code; `dungeon_manager` has
   its own, hash-seeded). `seed(n)` plus the two rules above makes a run
   reproducible. Known divergence from live play: live play decides ranges
   from mid-tile positions (`grid_manager.world_to_grid` floors the
   interpolated position); the sim always decides from whole tiles. That is
   the rule as written, and the M1 determinism test will catch anything
   else.
4. **Runner-side rules, no game change**: pre-seed `seen_tutorial_ids`;
   park the mouse on the aim before a point card resolves; answer
   resolve-time pickers by policy; end a run at HP ≤ 0 (no respawn); zero
   `xp_reward` on spawned enemies unless the scenario says otherwise (level-up
   full-heals would confound survival numbers).
5. **Shims I want sign-off on (each one line, rules-neutral):**
   - `enemy.gd:4760` `get_tree().current_scene` → `get_parent()`, so
     Defensive Sacrifice can be offered headless; the runner answers it via
     `_ds_resume`. Without it the card is dead in the sim (and in tests).
   - A `SIM_HEADLESS` flag on `Main` is **not** needed; nothing in the path
     requires one.
6. **Not supported in M1**: co-op (`is_multiplayer`), gauntlet skills, quiver
   cards, boss rooms with scripted structures. All reachable later through
   the same entry points.

## After sign-off (Milestone 1 decisions)

- XP and level-ups stay as in the game (a mid-fight level-up fully heals);
  nothing zeroes `xp_reward`.
- Card draw stays a flat 25 tempo (a WIS scaling was added, then reverted
  at the designer's request); the draw timer runs on tempo.
- The Defensive Sacrifice one-liner was applied (`enemy.gd` uses
  `get_parent()`).
- Runs re-instantiate `main.tscn` per seed (0.45 s a run) rather than
  resetting one instance: simpler, and provably seed-reproducible.

## Baseline test state on this checkout

86 of 97 `tests/test_*.gd` pass (221 s wall, serial); 11 fail before any of
this work, all on content that moved under them:

- card slotting into weapons / shields / coloured slots: `test_bladed_doughnut`,
  `test_ranged_pass`, `test_shields_pass`, `test_spell_weapons_pass`,
  `test_weapons_pass`, `test_item_forge`
- starter deck composition: `test_starting_loadout` (expects 11 cards)
- `test_passive_triggers` (Clean Exchange timing), `test_chaos_icons`
  (Inflamed Minotaur now uses the painting), `test_dungeon_gen` (level-4
  overworld connectivity / cave count), `test_escort_quests` (rescue NPC and
  depot timing)

None is harness-related. "Existing tests green" for the milestones means
these 86 stay green and the 11 are not made worse; the per-test logs are in
the run script's output directory. `tests/run_all.sh` (M1 housekeeping) will
make this count reproducible.
