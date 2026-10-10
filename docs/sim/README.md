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
| `tests/sim/scenarios/*.gd` | scenario files; `baseline.gd` is the control group; `build.gd` runs any stored build; `ryan/` names Ryan's designed builds |
| `tests/sim/builds/*_builds.gd` | the stored builds: one component library per character, `character_builds.gd` composes them at any level |
| `tools/sim_analysis/compare_runs.py` | before/after verdicts on a balance change |
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
`level=N`, `alloc=strength:10,dexterity:5`, `passives=a,b`, `hand=a,b`
(those cards start in the opening hand),
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

In the combo and card sweeps the card under test **starts in the opening
hand** (`hand=`): a one-card change to an 11-card deck is otherwise invisible
in a two-bar fight, and every added card scored identically on the first
validation run. It measures the card's power when it is available, not how
often it shows up; `gen_sweeps.py --no-spotlight` turns it off.

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

A caveat on the card and combo sweeps: the lookahead plays a card only
when its evaluation can price it (damage, block, heal, control / amp /
armor-strip wording, a buff feeding an attack in hand, a draw when the hand
is thin). A card whose effect it cannot price is never played, so its delta
is the cost of the hand slot it displaced and nothing else; read a zero
delta as "unpriced by the policy", not "useless", and add a term to
`lookahead.gd` when a card family matters to you.

Two things to keep in mind when reading summaries: `end_hp_pct` is 1.0 after
a fight whose last kill levelled the character (a level-up fully heals, as in
the game), so judge survival by `total_damage_taken`; and the `warnings`
column is non-empty when the build was not what the scenario asked for.

## Stored builds (`tests/sim/builds/`)

One component library per character, `tests/sim/builds/<name>_builds.gd`:
named **item sets** (`[id, slot]`, or `[mythic id, slot, legendary
fallback]`), **decks**, **allocation weights**, **sphere paths** (node-id
targets), **passive rank weights**, per-set **slotted cards**, and the
**designed** builds that combine them. `CharacterBuilds.compose(character,
parts)` turns any mix into a scenario **at any level**: allocation and
passive weights are spread over the points that level banks (3 stat and 1
passive point a level, ranks capped at 15), and the mythic cap is the
game's (one equipped mythic per 15 levels: one at 18, two at 30, three at
45+), with the listed fallbacks worn when a mythic does not fit. Ryan's
library is authored in full; Brad, Jeremy, Stephen and Cory carry the
designer's `_build_sims.gd` loadouts with placeholder decks, so selection
works for every character today and each library can be filled in without
touching the harness.

Everything runs through one scenario, `tests/sim/scenarios/build.gd`:

```
scenario=tests/sim/scenarios/build.gd parts=character:ryan,build:bruiser,level:50 enemy=WYVERN seeds=1-100
scenario=tests/sim/scenarios/build.gd parts=character:brad,build:immovable_warden,deck:starter,alloc:even enemy=TREANT enemy_scale=hp:2,dmg:1.5 seeds=1-100
```

`parts` keys: `character`, `build`, `level`, `items`, `deck`, `alloc`,
`sphere`, `passives`, `slotted`, `focus`, `enemy`. `passives` names a
weight set, spread proportionally over the points the level banks (so
nothing is ever maxed); `focus:<passive_id>` takes that one tree passive to
rank 15 first and spreads the rest over the build's set, which is how a
player who commits to a passive builds. The tree passives come from the
character's skill tree itself (`CharacterBuilds.tree_passives`), so a new
passive is swept the moment it is added; passives that come with an item
have no rank and are not part of it. `enemy_scale=hp:x,dmg:y`
multiplies every enemy's health and base hit, for difficulty sweeps and for
end-game bosses that have not been scaled to the level yet (the roster's
intended levels stop at 35; a level-50 run against unscaled enemies says
nothing). `tests/test_sim_builds.gd` asserts every designed build of every
character assembles with zero refusals, and Ryan's at level 50 too.

```
godot --headless --path . --script tests/sim/dump_catalog.gd                 # catalog incl. every library's component names
python3 tools/sim_analysis/gen_build_sweeps.py --character ryan --level 50   # <char>_designed / _items_x_decks / _alloc_x_sphere / _passives / _passive_focus, "_L50" suffix (level 18 is untagged)
tools/sim_analysis/run_sweep.sh tests/sim/sweeps/ryan_designed_L50.txt 4
python3 tools/sim_analysis/build_matrix.py --character ryan --level 50       # sim_out/charts/<char>_L50_*.png / .csv
```

### Quick feedback on a balance change

Runs are deterministic per seed, so any difference between two snapshots is
the change itself. The loop:

```
tools/sim_analysis/run_sweep.sh tests/sim/sweeps/ryan_designed.txt 4 sim_out/before
# edit the item / card / passive / stat ...
tools/sim_analysis/run_sweep.sh tests/sim/sweeps/ryan_designed.txt 4 sim_out/after
python3 tools/sim_analysis/compare_runs.py sim_out/before sim_out/after --md sim_out/change_report.md
```

`compare_runs.py` pairs every scenario × policy × seed present in both
snapshots, prints the change in win rate, damage per tempo, damage taken
and bars with a significance flag, and ends with one verdict line per
build. A real example (Belt of Wumbology +5 → +15 STR, Ryan's designed
builds against the Bugbear, Large Bear and Treant, 30 seeds):

```
verdicts:
  ryan_apothecary              untouched (the change never reached this build: 90 of 90 seed-runs identical)
  ryan_bruiser                 touched but not significantly (90 of 90 seed-runs differed; DPT +8.6%, damage taken -1.5%, win rate +0 pts; more seeds to confirm)
  ryan_card_shark              touched but not significantly (74 of 90 seed-runs differed; DPT +9.3%, damage taken -8.5%, win rate +4 pts; more seeds to confirm)
  ryan_ranged_ambusher         untouched (the change never reached this build: 90 of 90 seed-runs identical)
  ryan_shadow_blade            untouched (the change never reached this build: 90 of 90 seed-runs identical)
  ryan_spellslinger            untouched (the change never reached this build: 90 of 90 seed-runs identical)
```

Three kinds of line: **untouched** (every seed byte-identical, so the
change cannot reach that build), **touched but not significantly** (the
runs moved, the effect is within noise at this seed count; the deltas say
which way), and a significant one such as "`ryan_shadow_blade` win rate
+30 pts; damage taken −22 % — on LARGE_BEAR, WYVERN". An "untouched" line
on a build that wears the item is itself a finding: that is how the
Shadow Cowl's dead on-self bonus was caught (`bugs_found.md`). Keep the
`before` snapshot of every stored sweep you care about and the question
"did that change to X fix build Y without moving build Q?" is one command.

### Did the passive fire at all?

`summary.csv` carries `passive_triggers`: for every passive the player has
ranks in, how many times it fired that run (`let's_dance:18|quick_step:0|…`),
counted from the game's own battle log through `Main.battle_logged` (every
tree passive logs itself as "Name: …"). A maxed passive at 0 across a
sweep is the cue the designer asked for: the kit never gives it a chance
(Quick Step with no instants in the deck, Now You See Me with no
displacement), which is a different problem from "it fires and is weak".

A single scenario takes the same overrides a sweep line does:

```
godot --headless --path . --script tests/sim/run_sim.gd -- --scenario=tests/sim/scenarios/build.gd \
  --parts=character:ryan,build:shadow_blade,level:50,focus:let\'s_dance --enemy=LARGE_BEAR --enemy_scale=hp:2.5,dmg:2 --seed=1 --runs=3
```

### What the policy prices for these builds

The strategic policy (`lookahead`) values, from what a human sees:
**invisibility** (every hit the enemies would have landed while they cannot
see you, from the card text's duration), **poison stacks** (the damage they
tick for over the next cycles plus Pop Rocks), **discard engines** (Volatile
Mixture's detonation when it is the card discarded, Exacerbate Wounds, Ladder
Work's banked damage, Keep Them Guessing), **flash points** (free tiles, so
stepping out of a hit about to land passes no tempo; the sidestep block;
proc ticks that bring the DEX proc forward) and **brain points** (Insight
draws when the hand runs thin), with an opportunity cost on every point
spent and a commitment cost on long actions equal to what the character
could otherwise have blocked, sidestepped or walked away from. `--verbose`
prints its top-scored actions and threat model at every decision.

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
