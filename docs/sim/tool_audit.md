# Stored-build tester — audit (2026-10-12)

The tester's job: take any character, build them any way the game allows
(items, cards, stats, sphere grid, passives) at any level 1–50, fight
them through the real game, and say what a change to a card, item,
passive or enemy did to every stored build. This audit checks each thing
the designer asked for against the code and against runs, and lists what
was wrong. Everything marked *fixed* is on the branch, covered by a test.

## Verdict

The tester now does what was agreed, with the limits listed at the end.
The audit found **twenty-one defects** (16 and 18–21 from the follow-up on mechanisms not yet modelled); five of them changed numbers already
reported in `RESULTS.md`, and those tables were re-run (see there).

| # | Defect | Effect on readings | Status |
|---|---|---|---|
| 1 | Sphere grid lit only the path to three keystones, free: 11–17 nodes whether level 18 (36 spheres earned) or 50 (100 earned) | every level-50 build was missing most of its grid; level 18 about half | fixed: nodes bought with the game's own spheres, full budget spent (build-weighted), Free Stat points allocated |
| 2 | Eight picker cards (Sky Attack, Mirror Mirror, Collect Arrows, Friendship, Release Tension, Crack of Mintaka, Life Swap, Communal Donation) were never playable by the policy | the single-card sweep scored them as dead cards | fixed: playable; lookahead values and picks for them |
| 3 | A refused play could be picked again until the fight idled out (Heavy Swing, Lead Arrow) | timeouts read as losses: Heavy Swing −90 pts, ranged ambusher 0.83 → 1.00 | fixed earlier; every table taken before it re-run |
| 4 | The same seed drifted between processes under CPU load | paired comparisons were not strictly paired | fixed earlier: per-decision reseed, byte-identical across processes |
| 5 | `--skip-done` reused results regardless of code; re-running into a folder appended rows | an "after" re-run into the same folder could silently show no change | fixed: every job stamped with a code fingerprint, starts clean, skipped only on the same stamp; `compare_runs` warns when before and after ran the same code |
| 6 | No way to test one item on a stored build | "existing items / new items" untestable | fixed: `item:<id>` and the item sweep |
| 7 | Swapping an item in could change other items (a freed mythic slot let a second set mythic in; a forced mythic left a hand empty) | an item reading would have measured two or three items | fixed: other mythics pinned to the baseline, every set mythic has a fallback, tests |
| 8 | Tactics and recipes existed for Ryan only | four characters could not be tested by play style or generated deck | fixed: defaults for every character, passives resolved from each tree |
| 9 | Recipe decks ranked cards from an untracked, ever-changing file | the same recipe produced different decks on different machines or between a before and after | fixed: ranking committed under `tests/sim/builds/rankings/`, refreshed only on `--update-ranking` |
| 10 | Passive trigger counts read 0 for passives the game never logs (Directed Strength, Life Steal, Harnessed Power, Blood Libation, Wither) and for Way of the Plate (logs under another name) | "never fired" was wrong for six passives | fixed: name mapped; silent passives read `-` |
| 11 | Invisibility draw: cancelling the discard picker kept the drawn card for free | a real player could skip the cost | fixed in the game; scene-level test |
| 16 | Passive spreads ignored the skill tree's stage gate (a stage opens once 5 points sit in the stage before it) | 180 of 240 level-18 focus variants and 3 of Stephen's 4 designed builds at 18 could not exist in the game (level-50 readings were legal) | fixed: the composer legalizes every spread; audit test checks every composition |
| 17 | Jeremy's library spelled `a_mages_favor`; the game's id is `a_mage's_favor` | the shepherd passive set put ranks into a passive that does not exist | fixed; audit test rejects any library passive id the tree does not have |
| 14 | Stalemates: with nothing scoring above waiting (a Wyvern hovering out of reach, a hand of utility cards) both sides waited out the 40-bar clock | timeouts read as failures against the Wyvern; the apothecary's invisibility tactic lost 8 of 15 to it | fixed: after 6 idle waits with no health change the lookahead commits to its best non-wait action or closes distance |
| 15 | The invisibility draw's discard threw away engine cards (Poisoned Blood scored 0 by damage + block + heal) and drew without looking at the revealed top card | the rule's first final reading (−47 pts for the apothecary vs the Wyvern) measured the policy, not the rule | fixed: cards valued for poison, potions, draw, invisibility and discard engines; draw only when the revealed card beats the weakest in hand |
| 13 | The swap table averaged each card over whatever enemies it ran against, so cards with an extra pack run were ranked on different fights | If Pigs Could Fly briefly topped the ranking at +20 (its pack wipe averaged in) | fixed: packs reported in their own table, the ranking uses one shared enemy set |
| 18 | Gauntlet active skills (16 of them: Zeet, Coming In!, House Rule, Imbue Tree, Fan Save…) were never offered to the policy | every gauntlet was measured on its stats and passives only; an item whose value is its skill read as weak | fixed: skills are legal actions fired through the game's skill path and priced per effect; `skills_used` column; `test_sim_builds` checks one fires |
| 19 | Weapon swapping was impossible for the policy: no second weapon set in any stored build, no build-switch or War Rack action | Stephen's man-of-arms discount and Brad's War Rack, both character identities, were never exercised; the Wyvern read worse for melee builds than a player with a bow on the back would find it | fixed: `alt:<set>` / per-build second weapon sets, set up as build II or on the rack, swapped through the game's buttons and priced by reach and cards; `weapon_swaps` column; tests for both. Found on the way: Stephen's free switch never moved his weapons (a game bug, fixed; `test_stephen_build_switch` checks weapons, stats, cards, reach, shield, cost and saved builds over three round trips) |
| 20 | Decks lived in each character's library, so a deck written for one character could not be loaded on another, and shared decks were copied five times | cross-character deck tests needed copy-paste; copies could drift apart | fixed: one shared library, `tests/sim/builds/decks.gd`; the audit boots every deck on every character |
| 21 | Which card sits in which item slot was never swept | no way to see whether an item's slots, or a card's slot labels, are worth anything | fixed: `engrave:<item>~<card>` and the engraving sweep (every card the game lets into every slotted item of every designed build, plus each item stripped) |
| 12 | Overkill counted as damage dealt (the game's damage signal reports the full hit after clamping health) | damage per tempo inflated, most for burst and area cards (168 vs a 116-health pack) | fixed: the killing hit counts the health it removed; excess in an `overkill` column |

Also added: multi-enemy packs in the designed, tactic and recipe sweeps
(single-enemy fights cannot show what an area card is worth), a
`loadout.json` per job recording exactly what fought, and a permanent
self-audit test.

## Requirement by requirement

| Asked for | How it is met | Verified by |
|---|---|---|
| Real game, deterministic, scriptable player | boots `main.tscn`, drives the tick pump, real card/movement/prompt paths; reseeded per decision | `test_sim_hand_check` (byte-exact row), `test_sim_determinism`, three concurrent processes byte-identical |
| Any of the five characters | one library per character; `CharacterBuilds.compose` | `test_sim_audit`: every designed build of all five, levels 1–50 |
| Stored builds, quick before/after verdict | libraries + `compare_runs.py` (paired seeds, untouched / touched / significant per build), stamps | stamp probe (code change forces re-run, same-code warning) |
| Levels up to 50 | stat points 3/level, passive points 1/level (rank cap 15), mythic cap level/15, spheres 2/level, all spent | `test_sim_audit` asserts nothing unspent and caps hold at 1, 15, 18, 30, 50 |
| End-game enemies | the roster's intended levels stop at 35; `enemy_scale=hp:x,dmg:y` stands in | manual (a design input, not a measurement) |
| Mix and match items, decks, stats, sphere, passives | component libraries; items × decks and allocation × sphere sweeps | `test_sim_builds` |
| Policy uses invisibility, poison, discards, flash and brain points | lookahead prices each, plus displacement under Now You See Me and the picker cards | trigger counts and action logs in the sweeps |
| Let's Dance | id fixed | fires 10–22 times a fight when maxed |
| Every passive maxed, rest spread | `focus:<id>`, tree passives read from the skill tree (item passives excluded) | `test_sim_audit`: every tree passive of every character reaches 15 with all 49 points spent at 50 |
| Did a passive fire | `passive_triggers` per run, `-` when not observable | `test_sim_audit`: every tree passive countable or on the known-silent list |
| Cards universal; test new and existing cards | card pool by the game's flags (new card factories enter automatically), `swap:<id>`, recipes | `test_sim_audit`: every pool card deals and none is held out of play |
| Test new and existing items | item pool by factory (new items enter automatically), `item:<id>` | `test_sim_audit`: every pool item is worn when swapped into every build of every character |
| A play style on any build | `tactic:<name>` for every character | `test_sim_audit`: every tactic builds on every character |
| Invisibility draw rule | in the game; policy answers it | `test_invisibility_draw` |

## Limits that remain (by design or not yet built)

- **The player is a heuristic.** The lookahead plays a one-step-deep,
  priced game; a kit that needs multi-turn setup is played below what a
  person would manage. Read its numbers as floors for intricate kits.
- **Engravings are swept one at a time.** The engraving sweep tries every
  eligible card in every slotted item, one change from the designed build;
  it does not search for the best full set of engravings (combinations
  grow too fast). Swapped-in items inherit the replaced piece's engravings
  when they fit. Options are listed at level 18.
- **Four of the five libraries are first drafts.** Brad, Jeremy, Stephen
  and Cory's item sets, decks and passive weights come from the old build
  sims; they compose cleanly but have not had Ryan's design pass.
- **Carry capacity is a hard gate.** An item or tactic a build cannot
  carry is reported, not scored ("Adimantium is over capacity for every
  non-STR Ryan build"); that is a game fact, but it means heavy items are
  only measured on builds that can lift them.
- **Five passives cannot be counted** until the game logs them
  (`bugs_found.md`).
- **One arena, no terrain.** High ground, line of sight and obstacles are
  not part of the stored fights, so Lead Arrow and kin read as dead.

## Running it

```
godot --headless --path . --script tests/test_sim_audit.gd    # ~4 min, before trusting a sweep
tests/run_all.sh -j 4 sim                                     # every sim test
```
