# Combat simulation harness

Runs real combats through the real game (`main.tscn` booted headlessly, the
same `Card`, `DeckManager`, `TempoManager`, `Enemy`, `GridManager`,
`ProgressionTriggers` and item code the player uses) many times under a
seeded RNG, with a scriptable or automated player, and writes CSVs you can
chart. The design rationale and the audit it rests on are in
[`audit.md`](audit.md); bugs found while building it go in
[`bugs_found.md`](bugs_found.md).

```
godot --headless --path . --script tests/sim/run_sim.gd -- \
    --scenario=tests/sim/scenarios/baseline.gd --seed=1 --runs=100 \
    --policy=greedy_dpt --out=sim_out/
godot --headless --path . --script tests/sim/run_sim.gd -- --sweep=tests/sim/sweeps/example.txt
```

Flags: `--scenario=<path>` (a scenario file), `--seed=<n>` (first seed,
default 1), `--runs=<k>` (seeds `n .. n+k-1`), `--policy=<name>` (overrides
the scenario's policy), `--out=<dir>` (default `sim_out/`, git-ignored),
`--sweep=<file>` (many jobs, see `tests/sim/sweeps/example.txt`), `--verbose`
(one line per action). The game prints a lot; the harness reports on
**stderr**, so `godot --headless --quiet …` or `2>&1 >/dev/null` keeps only
the report. A baseline run costs ~0.45 s (100 seeds ≈ 45 s) after a ~2 s
engine start; the first run after adding a `class_name` script needs
`godot --headless --import --path .` once (the session hook does this).

## Files

| Path | What |
|---|---|
| `tests/sim/run_sim.gd` | CLI entry point: parses flags / sweep files, loops seeds, writes CSVs |
| `tests/sim/sim_runner.gd` | `SimRunner`: boots Main, builds the player, spawns enemies, drives time, records rows |
| `tests/sim/sim_state.gd` | `SimState`: the snapshot a policy sees, plus `legal_actions()` |
| `tests/sim/sim_scenario.gd` | `SimScenario`: loads, defaults and validates scenario files |
| `tests/sim/policies/*.gd` | player policies: `scripted`, `random`, `greedy_dpt`, `lookahead` |
| `tests/sim/scenarios/*.gd` | scenario files; `baseline.gd` is the control group |
| `tests/sim/sweeps/*.txt` | sweep files (`example.txt` by hand; the rest from `gen_sweeps.py`) |
| `tests/sim/dump_catalog.gd` | dumps the roster / card / item catalog the sweep generator reads |
| `tools/sim_analysis/*.py`, `run_sweep.sh` | sweep generator, sharded runner, the five analyses |
| `tests/test_sim_determinism.gd`, `tests/test_sim_hand_check.gd` | the harness's own tests |
| `tests/run_all.sh` | runs every `tests/test_*.gd` (`-j N` parallel, `-o dir` logs, `pattern` filter) |

## Writing a scenario

A scenario is a `.gd` file under `tests/sim/scenarios/` with one static
function returning a Dictionary. Copy `baseline.gd`:

```gdscript
extends RefCounted
static func build() -> Dictionary:
	return {
		"name": "baseline",             # output folder name
		"max_bars": 40,                 # hard cap in tempo cycles -> "timeout"
		"tempo_threshold": 5,           # tempo per cycle (TempoManager default)
		"player": {
			"character": "brad",        # CharacterData.create_<name>
			"level": 5,                 # applied with the real _level_up (full heal, banked points)
			"allocation": {"strength": 2, ...},   # spent with apply_stat_allocation; refused spends warn
			"passives": [],             # skill-tree passive ids (add_skill_tree_passive)
			"items": [["short_sword", 0]],        # ItemData.create_<id> [, slot]; equipped through Inventory.equip_item
			"deck": SimScenario.starter_deck(),   # card ids; cards owned by equipped items ride along
			"cell": [6, 7],             # grid cell; the dojo hall is cells 1..16 x 1..12
			"stat_overrides": {},       # PlayerStats fields set verbatim, e.g. {"base_crit_chance": 0}
		},
		"enemies": [
			{"type": "WERERAT", "cell": [9, 7], "overrides": {}},   # Enemy.EnemyType name; overrides set Enemy fields (max_health, attack_damage, ...)
		],
		"map": {"interior": "dojo", "obstacles": []},   # obstacles: cells added to every unit's blocked tiles
		"policy": "greedy_dpt",
		"script": [],                   # for the scripted policy, see below
	}
```

Everything is optional except `enemies`; `SimScenario.with_defaults` fills
the rest. Positions are real grid cells and distance, range, line of sight,
knockback and movement all run through `GridManager` / `DungeonManager`.
`GridManager` itself has no obstacle concept: walls live on the units'
`blocked_tiles` (pathing) and the dungeon's wall map (line of sight); the
`obstacles` list feeds the former only, so use it for pathing tests and a
different `interior` for line-of-sight ones.

**Level-ups and XP** are the game's: real enemies grant XP, a level-up
during a fight fully heals, exactly as in play (the designer's call).

### Scripted actions

```gdscript
"script": [
	{"type": "play", "card": "slash", "target": "enemy:0"},          # card by id (first playable copy) or hand index
	{"type": "play", "card": 2, "target": "self"},
	{"type": "play", "card": "fireball", "target": "point:9,7"},     # point-aimed: the cell
	{"type": "play", "card": "sky_attack", "target": "enemy:0", "picks": {"picked_card": 1}},
	{"type": "attack", "target": "enemy:0"},                         # the auto attack
	{"type": "block"},                                               # Basic Block (needs a shield)
	{"type": "wait"},                                                # +1 tempo
	{"type": "move", "cell": [8, 7]},                                # walks the whole BFS route
]
```

`enemy:<i>` indexes the living enemies in spawn order at decision time. An
illegal entry (out of range, no mana, stunned…) ends the run with outcome
`error` and the reason in the summary. When the list runs out the character
waits until the fight resolves.

## Output

`sim_out/<scenario>/<policy>/<seed>.csv`, one row per decision point: each
player action and each enemy action that fired, in order.

| Column | Meaning |
|---|---|
| `bar_index` | tempo cycle the action started in (`global_tempo / threshold`) |
| `tempo_before`, `tempo_after` | global tempo when the action started / when its ticks and settling finished |
| `actor` | `player` or `<EnemyName>#<spawn index>` |
| `action_id` | `play:<card_id>`, `attack`, `block`, `wait`, `move:<tiles>`, or the enemy's action name |
| `target` | `enemy:<i>`, `self`, `point:x,y`, `none`, or `player` |
| `player_hp` … `hand_size` | the player's state when the action started |
| `enemy_id`, `enemy_hp`, `enemy_pos` | the targeted enemy (or the acting one; or the first living one) — HP and cell **after** the action |
| `player_pos`, `distance` | player cell at the start; cell distance to that enemy after the action |
| `damage_dealt`, `damage_taken` | from the actor's point of view, summed over the action's window: health damage as the game reports it (`Enemy.damaged`, overkill included) plus any enemy armor stripped while the row was open — armor is effective HP, so a swing the troll's plate ate still counts |
| `buffs_applied`, `debuffs_applied` | names applied during the window, `|`-separated (`player:` / `Name#i:` prefixes on debuffs) |
| `rng_outcome_used` | the card's pre-rolled outcome index at play time (blank for cards without a chance effect) |

Attribution: damage during an enemy's action goes to that enemy's row;
everything else in a tempo step (DoTs at the cycle boundary, summons,
regen) goes to the player's row.

`summary.csv` gets one row per run: `seed, outcome (win/loss/timeout/error),
bars_elapsed, total_damage_dealt, total_damage_taken, damage_per_tempo,
cards_played, distinct_cards_played, card_entropy (bits, over card ids),
mana_wasted (regen lost to the mana cap), overflow_bars (cycle boundaries
crossed with carry-over tempo), end_hp_pct, enemy_actions_by_type
("bite:4|move:2"), global_tempo, decisions, error`.

`aggregate.csv` holds `n`, the four outcome rates and mean/std/min/max of
every numeric summary column over the seeds of that invocation.

## The policies

- **scripted** plays the scenario's action list verbatim.
- **random** picks uniformly among the legal actions: the floor.
- **greedy_dpt** is the auto-attacker: the highest damage-per-tempo attack
  (card or auto attack) against the nearest enemy, else a step toward it,
  else wait. It never blocks, heals, buffs or kites.
- **lookahead** is the strategic player. True state cloning was not
  feasible (the audit's §8: Main is the state, and replaying the seed to
  clone it costs seconds per candidate), so it is the audit's fallback: a
  one-step evaluation of every legal action,
  `(enemy HP removed + control value + mitigation value − HP lost while
  committed) / tempo`, with a kill bonus (the threat that enemy would still
  have dealt), a lethal-exposure penalty, and credit for stepping out of a
  melee hit about to land. It reads only what a human sees: the hover
  damage preview, the card text (for stun / root / disarm / vulnerable
  wording), the overhead intent bar, and the inspect panel's base hit and
  reach. With no threat it reduces to damage per tempo, so it never scores
  below greedy there. `tests/test_sim_policies.gd` checks the ordering on
  the skeleton scenario: random < greedy_dpt ≤ lookahead on damage per
  tempo, lookahead ≥ greedy on win rate and ≤ on damage taken. Measured
  over 50 seeds (see the Milestone 2 report): on the baseline and the
  two-rat pressure fight all three win every time and lookahead picks the
  same actions as greedy; against the Skeleton greedy wins 92%, random 98%
  (it blocks and heals by accident), lookahead 100% at higher DPT than
  greedy, blocking before the swing lands and side-stepping it once.

## Adding a policy

Drop `tests/sim/policies/<name>.gd` extending `SimPolicy`:

```gdscript
extends SimPolicy
func _init() -> void: name = "mine"
func choose_action(state: SimState) -> Variant:
	var legal := state.legal_actions()     # every action the runner will accept
	...
	return legal[0]                        # or null to abort the run as "error"
func answer_prompt(kind: String, options: Array) -> int:   # optional
	return 0
```

`SimState` is exactly what a human sees: HP / armor / temp HP / mana /
flash / brain, the hand with each card's cost, damage estimate
(`main.calculate_damage_preview`, the hover number), range, target types,
keywords and **pre-rolled outcome** (`rng_index`), buffs and debuffs, every
living enemy with HP, armor, cell, distance, status effects and telegraphed
intent (`get_display_action()`), the tempo clock, and the draw countdown.
It does not expose the draw-pile order, crit rolls, or the enemy's
untelegraphed choices. Cards that open a picker (Sky Attack, Reposition,
Mirror Mirror, Collect Arrows, Friendship, Release Tension, Crack of
Mintaka, Life Swap, Communal Donation) are listed as unplayable unless the
action carries `picks`; the generic policies skip them.

Prompts the game raises while a card resolves (Peshtigo's maintain
question, hand pickers, Defensive Sacrifice, Life Swap's enemy pick, Point
to Prove, the donation panel) are answered through `answer_prompt`; the
default keeps the power, takes the first option, declines donations.

## Sweeps and analysis (Milestone 3)

A sweep file lists jobs, one per line: `scenario=<path> [policy=<name>]
[seed=<n> runs=<k> | seeds=<a>-<b>] [overrides…]`, `#` comments. Overrides
sit on top of the scenario file: `enemy=TYPE[,TYPE]` (replaces the enemies;
melee types stand 3 tiles off, ranged at their own reach), `add_cards=a,b`,
`add_items=x[:slot]`, `items=x[:slot],y|none` (replaces the loadout),
`level=N`, `alloc=strength:10,dexterity:5`, `passives=a,b`,
`character=name`, `name=suffix` (the output folder becomes
`<scenario>_<suffix>`). `--shard=i/n` makes one process take every n-th
job, and `tools/sim_analysis/run_sweep.sh <sweep> [shards] [out]` runs a
sweep across that many processes (4 is right for this container).

```
godot --headless --path . --script tests/sim/dump_catalog.gd     # sim_out/catalog.json: roster, cards, items
python3 tools/sim_analysis/gen_sweeps.py                          # writes tests/sim/sweeps/*.txt
tools/sim_analysis/run_sweep.sh tests/sim/sweeps/build_divergence.txt 4
python3 tools/sim_analysis/build_divergence.py                    # sim_out/charts/*.png + *.csv
```

| Sweep (gen_sweeps.py) | Jobs | Analysis | Answers |
|---|---|---|---|
| `enemy_strategy.txt` — every acting enemy, solo, × greedy_dpt / lookahead, 200 seeds | 100 | `strategy_index.py` → `strategy_index.png/.csv`, `strategy_taken_gap.png` | Q1: `strategy_gap` = lookahead − greedy win rate (and damage taken), lookahead card entropy, bars to kill. Near-zero gap = meat bag |
| `combos.txt` — baseline deck + singles and pairs from a pruned pool, lookahead, 3 enemies, 100 seeds | ~230 at pool 12 | `combos.py` → `combos.png/.csv` | Q2: `synergy = DPT(A+B) − DPT(A) − DPT(B) + DPT(base)`; notable above 15 % of base DPT; top/bottom 20 |
| `card_power.txt`, `item_power.txt` — one card / one item at a time, 3 enemies, 100 seeds | ~700 / ~570 | `card_item_power.py` → `card_power.png`, `card_power_tempo.png`, `item_power.png`, `.csv` | Q3: delta win rate / DPT / damage taken vs control, by rarity; scatter vs mana, tempo, weight with the tier's mean ± 1 sd band |
| `build_divergence.txt` — 7 allocations × 5 enemies, 100 seeds | 35 | `build_divergence.py` → `build_divergence_win.png`, `_dpt.png`, `.csv` | Q4: heatmap build × enemy; identical rows mean stats don't matter |
| `progression.txt` — levels 1 / 5 / 10 / 15 / 18 with tier gear × the roster, 100 seeds | 250 | `progression.py` → `progression.png`, `progression_by_enemy.png`, `.csv` | Q5: win rate and bars to kill vs level; flat = progression isn't felt |

Costs at ~0.45 s a run: strategy 2.5 h, combos 2.9 h, cards 8.8 h, items
7.1 h, builds 0.4 h, progression 3.1 h serial — divide by the shard count.
`gen_sweeps.py --seeds N --pool-size K --limit M` scales them down.

The combo pool is every Basic/Common/Rare non-engraved, non-item card
costing ≤ 60 mana, first `--pool-size` by id (or exactly `--pool a,b,c`); the prune rule skips a pair
when both cards are attacks carrying no keyword beyond
attack/offensive/melee/ranged/enemy/conditional/self/spell (`--no-prune`
keeps them all; edit `PLAIN_ATTACK_KEYWORDS` / `card_pool` to change the
rule). Weapons in the item sweep replace the baseline Short Sword
(`items=`), everything else is added in slot 0; an equip the inventory
refuses lands in the summary's `warnings` column and shows as `clean = 0`
in `item_power.csv`. Progression gear is the first item by id of each slot
at the level's tier (Common at 5, Rare at 10, Legendary at 15, Mythic at
18), so it is "typical", not optimised; swap `tier_gear` for the
`_build_sims.gd` loadouts when you want the designed builds.

Charts are static PNGs (pandas + matplotlib, the repo's existing script
style) using the validated default palette; the CSV next to each chart has
every number.

Two things to keep in mind when reading summaries: `end_hp_pct` is 1.0 after
a fight whose last kill levelled the character (a level-up fully heals, as in
the game), so judge survival by `total_damage_taken`; and the `warnings`
column is non-empty when the build was not what the scenario asked for.

## How time is driven (why the numbers are trustworthy)

- The wall-clock tick pump (`TempoManager._process`) is off; the runner
  calls `_process_one_tick()` until the player's queue is empty. A win does
  not cut a card's committed ticks short; a loss does.
- Player and enemy movement is snap-stepped: each tile is entered through
  the unit's own `_physics_process` arrival code, so movement tempo, bleed,
  traps, fire walls and melee-entry reactions fire in order. Live play
  decides ranges from mid-tile positions; the sim always decides from whole
  tiles (the rule as written).
- Point-aimed cards read the live mouse when they resolve; the runner parks
  the mouse on the aim before each resolve.
- One frame is pumped per decision to flush `call_deferred` (Cover's tempo).
- `seed(n)` is set before boot and again before the first decision; every
  combat roll uses the global RNG and nothing in the loop reads the clock,
  so a run is reproducible byte for byte (`tests/test_sim_determinism.gd`).
