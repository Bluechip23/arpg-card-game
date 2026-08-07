# Codebase Audit Findings — 2026-08-07

Full two-pass audit of cards, combat mechanics, passives, keystones, stances,
and progression. Every finding survived a re-verification pass; items marked
**[hand-verified]** were additionally confirmed by direct code inspection.
One candidate finding (quiver cards skipping world effects) was **refuted**
during verification and does not appear below.

Status column tracks triage: first fix batch landed 2026-08-07 (A1, A2, A4,
A6, A7, B4, B7, B8, B10). A3/A5 answered, pending direction.

## A. Critical bugs (broken player-facing systems)

| # | Finding | Where | Status |
|---|---|---|---|
| A1 | **[hand-verified]** Sphere grid node ids 31–36 don't exist (Ring 3 = ids 19–30, Ring 4 starts at 37), but 5 constellations reference them — Windwalker, Storm Runner, Unyielding, Shadow Strike, Iron Bastion can never complete | `sphere_grid.gd:223,267,489-549` | fixed — ids 31–36 exist as placeholder NULL nodes |
| A2 | **[hand-verified]** 4 keystone flags omitted from save/restore — Sanguine Barrier, Living Bulwark, Arcane Blood, Willspring silently detach on every town↔dungeon transition | `player_stats.gd:442-456,524-538` | fixed — all 4 flags in save/restore |
| A3 | **[hand-verified]** Arcane Current permanently mutates the card: `bonus_damage += 5` per cast with no removal — compounds without bound | `progression_triggers.gd:2002` | open — answered: constellation bonus (see chat) |
| A4 | **[hand-verified]** Restored maintained cards never re-reserve mana — crossing a world boundary makes every active Power card free | `deck_manager.gd:113-116` | fixed — restore re-reserves maintain mana |
| A5 | **[hand-verified]** Growth Within Resilience never triggers in solo play (its hook lives in `_on_ally_damage_taken`, connected only in co-op/sandbox); also reads the active player's stats, not the victim's | `main.gd:9072-9078,569-572` | open — answered: Hydra-drop Power card (see chat) |
| A6 | War Rack exchange leaves `current_carry_load` stale (no `_recalculate_carry_load()` after `rack_items = outgoing`) — overburden/speed wrong until next equip | `inventory.gd:1534` | fixed — rack exchange recalcs load immediately |
| A7 | "On spell cast: 10% refund full mana cost" (node 111) parses to a no-op — the generic `mana` branch shadows the `refund` branch and value=0 | `progression_triggers.gd:276-277,300` | fixed — refund branch beats generic mana branch |

## B. Functional bugs (wrong numbers / wrong behavior)

| # | Finding | Where | Status |
|---|---|---|---|
| B1 | Consecutive Snap resolves one use ahead under deferred execution: first play deals 12 (3+9) and discounts the next use immediately | `deck_manager.gd:551`, `card.gd:2125` | open |
| B2 | Burden mechanic entirely unimplemented — helpers have no callers; Healthy Habit & Provider advertise it | `card.gd:1280-1295,4430,4972` | open |
| B3 | Blade Barrage advertises "Glut: 15 tempo" but never sets `glut_tempo` | `card.gd:3338-3353` | open |
| B4 | Collect Arrows requires clicking an enemy in melee range (default target/tempo not overridden) though it's a self utility; description omits its actual Glut 15 | `card.gd:3403-3412` | fixed — self-targeted; Glut noted in text |
| B5 | Surrounding Ice: chance is pre-rolled per enemy but the live path re-rolls a hard-coded 70%; `get_rng_outcome` has zero callers, the RNG preview indicator is an empty stub, so Loaded Die/House Money can't affect it | `card.gd:241-248`, `main.gd:7300`, `aoe_indicator.gd:117` | open |
| B6 | Loaded Die / House Money boost applies to every unrolled chance card at once, and multi-outcome rolls (Oops, What's the Worst) ignore the boost entirely | `main.gd:4971-4976`, `card.gd:228-238` | open |
| B7 | Shuriken / Vines / Worms Armageddon / Absorb Essence deal raw base damage while the card face shows the STR/INT-scaled number | `main.gd:7157,7058,7120,7427` | fixed — all 4 deal the face's scaled damage |
| B8 | Choke, Last Breath, Exacerbate Wounds inherit the class-default `base_damage = 10` → phantom ~10+STR hover preview on no-damage cards | `card.gd:2983,2888,2631` | fixed — Choke = half auto/round; others base 0 |
| B9 | `BLOCK_AMOUNT_OVERRIDES` lists cards that grant no armor (Turtle Up, Meditate, Mana Surge); Mana Surge's substitution can corrupt a color tag by matching the `8` inside a hex code | `main.gd:6146` | open |
| B10 | Mark lasts 125 tempo, not the stated 25 (value stored as cycles, ticked per 5 tempo) | `card.gd:1941`, `enemy.gd:2785,1369` | fixed — 5 cycles = the stated 25 tempo |

## C. Mismatches (code ≠ description; behavior defensible but undocumented)

| # | Finding | Where | Status |
|---|---|---|---|
| C1 | Flash Cut ignores the free-hand parry discount (hard-codes cost 3; Sidestep correctly pays 2) | `player_stats.gd:829-831`, `main.gd:4759` | open |
| C2 | A lone bow (no quiver) qualifies for the free-hand stance — README says a bow fills both hands | `inventory.gd:977-989` | open |
| C3 | Lead Arrow's "lower range" not implemented (standard 5-tile range) | `card.gd:2871-2886` | open |
| C4 | Misery Loves Company spreads on only 4 of ~12 AoE cards | `main.gd:6997-7038` vs `7294,7307,7403,...` | open |
| C5 | AoE shading radius ≠ real effect: Internal Combustion (1.5 shown / 3.0 real), Round 'Em Up (1.5/2.0), Worms (circle shown / all enemies real), Spirit Arrow (1.5 / full pierce), Absorb Essence draws a 100-tile circle, God of Thunder flagged AoE but single-target | `card.gd` + `main.gd` (per pairs) | open |
| C6 | Volatile Mixture's self-damage scales with your own INT; text says flat 8 | `main.gd:5481-5484` | open |
| C7 | Lethal Recall keys off the literal word "Instant" in descriptions — misses Spider Senses & Vengeful Shield (reactions), matches Healthy Bliss (utility) | `main.gd:6788` | open |
| C8 | Anticipation's Prepare token is placed in the discard pile where its own erase timer deletes it before it can be drawn | `card.gd:3849,4478`, `deck_manager.gd:698-719` | open |
| C9 | Skill-tree passives with no source: Sword Specialist, Phalanx, Corrupted Strength, Disarm Mastery handlers exist but no tree option produces those ids | `progression_triggers.gd:573,1269,1056,1306` | open |

## D. Display / cosmetic / dead code

| # | Finding | Where | Status |
|---|---|---|---|
| D1 | Halo's face replaces the "3" in "Maintain 3M" with the scaled heal (reads "Maintain 8M") | `card.gd:320-334,3248` | open |
| D2 | Fortify Alliance swaps its heal/armor numbers in the stat-aware display | `card.gd:308,3633` | open |
| D3 | Empower's text says "-3 block" but the effect is a 3-mana refund on defense cards | `card.gd:1397,1198` | open |
| D4 | Quick Shot shows a literal "X" instead of its damage | `card.gd:2758` | open |
| D5 | Two crit readouts in the character panel disagree under Tactician's Eye | `character_panel.gd:857,667` | open |
| D6 | Node 101 "bleed for 3 turns" applies 3 stacks of poison; node 76 "draw costs 0" discounts the next played card | `progression_triggers.gd:1897,1984` | open |
| D7 | Node 72 double-cast is near-inert (requires UTILITY + mana>0 + damage>0) | `main.gd:6707`, `progression_triggers.gd:2032` | open |
| D8 | Stale docs/comments: inventory.gd says capacity 80% (is 70%); README says dual-wield 1.35× in one spot (is 1.15×); sphere_grid comments claim 100 nodes / 3 conversion keystones (134 / 4); stale "shared node" comments | various | open |
| D9 | Dead code: Reaction `tempo_cost` unused; `SkillOption.passive_data` never read; `equipped_quivers` array permanently empty but still iterated; Healthy Bliss second implementation unreachable | `card.gd:3609`, `skill_tree_data.gd:34,54`, `inventory.gd:930,986`, `main.gd:5549` | open |

## Verified-correct coverage (no findings)

Maintain loop end-to-end (play path), jail tick/release/block, all reaction
triggers, all seven overflow types + manifest ids, chance cards using
pre-rolled outcomes (except B5/B6), STR/INT stat-aware numbers on the normal
attack path, AoE shading plumbing (selection → tile shading), enemy debuff
name integrity, special cost rules (Specific Strike, Exhausted Assault,
Heavy Swing, Fireball), the three stances (two-hand 0.7/0.5/+w per 10, dual
wield pair detection + 1.15× + −4 threshold, free-hand parry/echo incl. all
six echo sites), stat allocation flow (+3/level, 8-point creation, FREE_STAT
nodes, save round-trip), derived stat formulas per the rebalance, DET
neutral-15 table, all 15 other keystones live, quest/skill-tree row structure.
