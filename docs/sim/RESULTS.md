# Milestone 3 — validation-run findings

These numbers come from **reduced** sweeps run while the pipeline was built
(30 seeds for the strategy index, 100 for builds, 10 for the rest, a
15-card / 15-item slice, a 6-card combo pool). They show the questions can be
answered and give first readings; the committed sweeps under
`tests/sim/sweeps/` are the full-size versions (200 / 100 seeds, every card
and item). All of it is a level-5 Brad with the starter deck and a Short
Sword in the dojo, so every enemy above that level reads as "unbeatable
here"; the progression sweep is where higher levels enter.

## Q1 — do enemies warrant strategy? (`strategy_index.png`)

Of the 50 acting enemy types, against the baseline player:

- **15 reward play** (lookahead beats greedy): Bugbear, Infected Hunter,
  Sewer Croc and Earth Mage flip from 0 % to ≥ 87 % wins when the player
  blocks before the swing lands and side-steps melee hits; Consumed, Elite,
  Air Mage, Spirit Collector, Giant Hawk, Werewolf, Wolf, Boss, Crypt
  Crawler, Ring Wraith and Skeleton gain 7–67 points.
- **16 are meat bags** at this level (both policies win ≥ 95 %, usually in
  one bar): Wererat, Archer Rat, Coyote, Zombie, Swarm, Screecher, Sludge,
  Pipe Crawler, Minion, Mini Bear, Wererabbit, Grave Digger, Fire Goblin
  Soldier / Mage / Shaman (the Shaman is the one enemy where greedy slightly
  out-wins lookahead, 100 % vs 97 %).
- **19 are above this level** (both lose every time): the trolls, dragons,
  bosses, the mages, the bears, Vampire, Necromancer, Hydra, Djinn, Ifrit,
  Wyvern, Manticore, Minotaur, Cerberus, Grave Titan. The Armored Troll's
  48 armor is the sharpest case: nothing in the baseline kit scratches it.

Lookahead card entropy is highest where play matters (Boss 2.2, Earth Mage
2.0, Bugbear 1.9) and 0 where one card suffices.

## Q4 — do builds diverge? (`build_divergence_*.png`)

Over 7 allocations × 5 enemies, 100 seeds each: **win rate barely moves**
(only the Fire Goblin Mage column varies, 0.93–1.00) but **damage per
tempo does** — pure STR is 30–40 % above the even spread against every
enemy (3.92 vs 2.95 on the Wererat, 2.45 vs 1.75 on the Skeleton), DET-heavy
is second, and the four non-STR pure builds sit 5–10 % *below* even. With
the starter deck only STR has a lever; the other stats' payoffs (brain and
flash points, INT spell damage, DEX procs) need their cards and gear in the
deck to show, which the card and item sweeps can supply.

## Q5 — is progression felt? (`progression.png`)

Levels 1 / 5 / 10 / 15 / 18 with tier gear (first Common / Rare / Legendary
/ Mythic item per slot) against all 50 enemies, 10 seeds:

| level | win rate | bars to kill (22 enemies killed at every level) |
|---|---|---|
| 1 | 0.39 | 5.0 |
| 5 | 0.58 | 3.2 |
| 10 | 0.65 | 3.0 |
| 15 | 0.66 | 1.8 |
| 18 | 0.68 | 2.0 |

Win rate climbs steeply to level 10 and flattens after; bars-to-kill keeps
falling to level 15. The flattening is the roster: a third of it stays
unbeatable for the even-spread, first-item-of-tier character, which says
more about that generic build than about levels.

## Q2 / Q3 — combos and single cards / items

The pipeline runs end to end (`combos.png`, `card_power.png`,
`item_power.png`), with two things learned that shaped it:

- A one-card change to an 11-card deck is invisible in a two-bar fight, so
  the card under test now **starts in the opening hand** (`hand=`).
- The lookahead plays only what its evaluation can price. Against enemies it
  kills in a bar it attacks at once, so most utility cards score exactly
  the slot they displaced; the slice confirmed this (fourteen cards with an
  identical −0.31 DPT delta) and the README carries the caveat. Attack,
  block, heal and buff-the-next-attack cards do register (Biscuit +0.06).
- Items register cleanly: Assassin Belt +0.76 DPT, Belt of Wumbology +0.19,
  Blink Boots +0.13; the carry gate refuses Adimantium (350) and Bessy (450)
  at level 5, and the chart shows those as hollow "equip refused" markers
  instead of pretending they were worn.

Real answers to Q2 and Q3 need the full sweeps (3–9 h each serial, divide
by shards) and, for utility-heavy cards, either harder enemies in
`--enemies` or a lookahead term that prices the effect.

# Ryan build directory — first mix-and-match readings

Reduced runs (designed builds 30 seeds × 6 enemies; item × deck 10 seeds
and passives 10 seeds × 3 enemies; allocation × sphere 5 seeds × 3
enemies). Level 18, one mythic per set, lookahead policy. Charts:
`sim_out/charts/ryan_*.png`, numbers in the CSVs beside them.

## Designed builds vs the late-Act-1 roster

Win rate at level 18, 30 seeds, lookahead policy (`sim_out/ryan18`, after
the policy learned to price invisibility, poison stacks, discard engines
and flash / brain spends):

| build | Bugbear | Earth Mage | Large Bear | Wyvern | Treant | Ice Troll | mean DPT |
|---|---|---|---|---|---|---|---|
| bruiser | 1.00 | 1.00 | 1.00 | 0.90 | 0.67 | 1.00 | 8.4 |
| spellslinger | 1.00 | 1.00 | 1.00 | 0.50 | 0.17 | 0.90 | 2.9 |
| card_shark | 1.00 | 1.00 | 0.57 | 0.03 | 0.57 | 0.53 | 7.3 |
| apothecary | 1.00 | 1.00 | 1.00 | 0.53 | 0.00 | 0.13 | 1.6 |
| ranged_ambusher | 1.00 | 1.00 | 1.00 | 0.17 | 0.13 | 0.07 | 7.0 |
| shadow_blade | 1.00 | 0.63 | 0.17 | 0.00 | 0.00 | 0.03 | 2.2 |

(The ranged ambusher's row is from the re-run after the refused-play fix
below; its earlier 0.83–0.87 against the first three were harness stalls,
not losses.) The bruiser (Sword of Theseus, plate, 30 STR) is still the
only build that beats the whole roster. Pricing the discard engine lifted the card
shark from a 7 % to a 57 % Treant and from 0 to 53 % against the Ice
Troll (its Bugbear damage per tempo is now 16.9, the highest number in
the sweep), so the earlier card-shark reading was a policy floor, not the
kit. The shadow blade did not move: against the Large Bear it spends most
of its decisions walking (234 single-tile moves and 90 flash moves to 130
basic attacks over 30 fights), plays *Shadows* four times in 30 fights,
and its basic attack lands under 10 a hit. That is the Sabre Tooth's 10
base plus no STR, and the policy change does not alter it: the kit's
damage is the problem, not the play.

## The same builds at level 50

Level 50 means 147 stat points, 49 passive points and three equipped
mythics per set (the fallbacks drop out). The roster's intended levels
stop at 35, so these fights use `enemy_scale=hp:2.5,dmg:2` as a stand-in
for end-game tuning; the numbers say how the builds scale relative to each
other, not whether a specific boss is right. 30 seeds, `sim_out/ryan50`.

| build | Bugbear | Earth Mage | Large Bear | Wyvern | Treant | Ice Troll | mean DPT | median DPT |
|---|---|---|---|---|---|---|---|---|
| bruiser | 1.00 | 1.00 | 1.00 | 0.63 | 0.87 | 1.00 | 15.2 | 15.4 |
| ranged_ambusher | 1.00 | 1.00 | 1.00 | 0.57 | 1.00 | 0.40 | 25.4 | 14.5 |
| spellslinger | 1.00 | 1.00 | 1.00 | 0.40 | 0.37 | 1.00 | 5.3 | 4.7 |
| apothecary | 1.00 | 1.00 | 1.00 | 0.13 | 0.03 | 0.00 | 2.5 | 2.2 |
| card_shark | 1.00 | 0.97 | 0.53 | 0.07 | 0.30 | 0.23 | 8.6 | 6.5 |
| shadow_blade | 0.83 | 1.00 | 0.03 | 0.00 | 0.00 | 0.03 | 2.1 | 1.8 |

Read the median column for "how hard does it hit"; the mean is pulled up
by one-shot seeds (below).

- **The ranged ambusher is the build that scales, and it scales through
  crits.** From a 47 % mean win rate at level 18 to 83 %, median DPT 6 to
  14.5. The mean (25.4; 49.8 against the Bugbear) is a different story:
  in seeds 13, 17 and 27 the opening *Mixed Bag* — a 7-damage common arrow
  — crits for 239 and deletes the 2.5× Earth Mage or Bugbear in one tempo.
  The crit formula is 110 % + 3 % per point of DEX, so at the ~110 DEX a
  level-50 DEX build carries a crit is a 4.4× multiplier on top of the STR
  and sphere bonuses; a median Mixed Bag at 50 hits 69, a crit 240. Where
  level 18 tops out at 68. That multiplier, not the bow, is what to look
  at before Act 2 bosses are tuned.
- **Arcane Ward has no ceiling.** Sphere keystone 107 grants armor equal
  to half INT every time mana regenerates, against a decay of 2 a cycle.
  The level-50 apothecary (wis_int, Sage path through 107) sits at 811
  armor by mid-fight and cannot be killed by anything on the roster; it
  loses only by timeout (Treant heals, Wyvern) and never by damage. The
  spellslinger's Arcane path has the same node.
- **The bruiser scales linearly** (8.4 to 15.2 DPT) and keeps its win
  rate; it is the stable reference.
- **The shadow blade does not scale at all** (2.2 to 2.1 DPT, 31 % to 32 %
  wins). Three mythics of DEX and AGI do nothing for a dagger whose damage
  has no STR behind it. Whatever fix is chosen for it at level 18 has to
  hold at 50 too.
- The apothecary and spellslinger win by outlasting at both levels; the
  2× enemy damage pushes the apothecary off the Wyvern, Treant and Ice
  Troll entirely.

## One passive maxed: does any single passive carry a build?

Every one of Ryan's 12 tree passives taken to rank 15 on each designed
build, the remaining 34 points spread over the build's own set, level 50
against the scaled Large Bear, Earth Mage and Wyvern, 30 seeds
(`tests/sim/sweeps/ryan_passive_focus_L50.txt`, charts
`sim_out/charts/ryan_L50_passive_focus_*.png`). Damage per tempo, columns
are the maxed passive:

Median damage per tempo over the three enemies (the mean is distorted by
the ranged ambusher's one-shot seeds); columns are the maxed passive:

| build | surprise_opener | nimble_assault | ladder_work | let's_dance | now_you_see_me | quick_step | eye_scrape | others |
|---|---|---|---|---|---|---|---|---|
| bruiser | **16.1** | 15.0 | 15.4 | 14.5 | 14.9 | 14.9 | 15.0 | 14.6 – 15.8 |
| ranged_ambusher | 15.5 | **16.4** | 15.3 | 14.6 | 14.3 | 14.7 | 13.5 | 13.1 – 14.2 |
| card_shark | **7.6** | 6.7 | 6.6 | 6.6 | 6.8 | 6.6 | 6.4 | 6.6 – 7.2 |
| spellslinger | **4.3** | 3.8 | 3.9 | 3.9 | 3.9 | 3.9 | 3.9 | 3.8 – 4.0 |
| apothecary | **3.0** | 2.4 | 2.6 | 2.6 | 2.4 | 2.4 | 2.4 | 2.4 – 2.5 |
| shadow_blade | **2.3** | 2.1 | 2.1 | 2.3 | 2.1 | 2.1 | 2.1 | 2.1 – 2.2 |

What it says, as direction rather than verdicts (cards and enemies will
change under it):

- **No single passive rescues a kit.** Win rates move by at most a few
  points for any passive on any build; the shadow blade stays at 30–34 %
  with every one of its passives maxed in turn, including Let's Dance at
  divisor 1 (it fires 10–18 times a fight and still loses to the bear).
  The passive tree tunes a build, the gear and the damage stat define it.
- **Surprise Opener is the only passive that moves every build**: the
  best column on five of six, +0.5 median DPT on average. It is flat
  bonus damage on a first strike with no condition the kit has to set up,
  which is also why it is the one that works everywhere.
- **Quick Step never fires.** It keys off instants (REACTION cards) and
  not one of Ryan's six stored decks plays a single instant across the
  whole sweep; the 20 instants in the card pool are other characters'
  (Mage Shield, Hard Helmet, Spider Senses…). Its column is the
  redistribution of the other 34 points, nothing else. Either Ryan needs
  instants of his own or the passive wants a different trigger.
- **Maxing usually costs more than it gives.** Against the designed
  build's own proportional spread, nine of twelve maxed passives come out
  slightly lower on median DPT: the 15 ranks come out of passives that
  were doing more at rank 6–11. Rank scaling is steep on paper (cooldowns
  19 → 5, divisors 8 → 1) and still the last ten ranks of most passives
  buy less than the first five.

### Does the maxed passive fire at all?

Times the rank-15 passive fired per fight (`passive_triggers`, counted from
the game's own battle log), rows are the build it was maxed on:

| build | let's_dance | eye_scrape | surprise_opener | from_the_hip | nimble_assault | mad_scientist | stimulant | pop_rocks | keep_them_guessing | ladder_work | now_you_see_me | quick_step |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| apothecary | 22.5 | 3.6 | 0.9 | 0.4 | 0.4 | 1.9 | 1.5 | 1.0 | 0.0 | 0.2 | 0.0 | 0.0 |
| shadow_blade | 17.6 | 0.6 | 0.9 | 0.7 | 0.8 | 0.2 | 0.2 | 0.0 | 0.0 | 0.1 | 0.0 | 0.0 |
| spellslinger | 8.1 | 0.4 | 0.9 | 0.5 | 0.6 | 1.6 | 1.2 | 0.2 | 0.0 | 0.0 | 0.2 | 0.0 |
| card_shark | 6.6 | 0.4 | 1.0 | 1.7 | 0.5 | 0.1 | 0.1 | 0.0 | 0.9 | 0.8 | 0.0 | 0.0 |
| bruiser | 4.4 | 0.5 | 0.9 | 0.9 | 0.8 | 0.2 | 0.2 | 0.0 | 0.0 | 0.2 | 0.0 | 0.0 |
| ranged_ambusher | 1.3 | 0.8 | 1.0 | 0.9 | 0.9 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |

Cues from the trigger counts, which are a different kind of information
from the damage numbers:

- **Now You See Me fires 0.03 times a fight at rank 15**, zero on the
  shadow blade it belongs to. Its trigger is displacement (blink, swap,
  non-standard movement) and the shadow deck's one *Blink* is the only
  source on any build; at a 1-tempo cooldown it still has nothing to
  react to. The passive is fine, the kit has no ways to displace.
- **Quick Step fires 0.0 times on every build**: no instants in any Ryan
  deck (see above).
- **Keep Them Guessing fires only on the card shark** (0.9 a fight, needs
  4 discards at rank 15), **Pop Rocks only on the apothecary** (1.0, needs
  poison already on the target), **Ladder Work under once a fight
  anywhere** (its damage rider needs cards hitting the discard pile
  unplayed; its stat line is what the ranks actually buy). These are
  archetype-locked by design; the counts say the lock holds.
- **Eye Scrape fires about once a fight** (3.6 on the apothecary, whose
  fights are longest) — "every crit" at rank 15 is still gated by the
  10-tempo cooldown, so the ranks past the cooldown's length do nothing.
- **Let's Dance fires 4–22 times a fight and still carries nothing**:
  22.5 triggers on the apothecary against a 2.5× bear are 22 cycles of
  walking in a fight it cannot finish. Count is not value; the armor it
  grants is swamped by Arcane Ward and the damage by divisor 1 is spaces
  moved, which the lookahead keeps to 1–2 a cycle.
- **Surprise Opener fires 0.9–1.0 times a fight**, exactly once per
  enemy as written, and is the best passive on five of six builds. One
  reliable trigger with a flat payoff beats every conditional passive in
  the tree at these deck sizes.

## Every card, one at a time, on every build

The single-card sweep: each of the 202 base-deck-legal cards swapped for
the last card of each designed build's deck and spotlighted into the
opening hand, level 18 against the Large Bear, 10 seeds a card, paired by
seed against the designed run (`tests/sim/sweeps/ryan_card_swap.txt`, the
Large Bear pass of it; per-build table in
`sim_out/charts/ryan_card_swap.csv`). Cards are universal, so the pool is
the game's own flags, no character filter.

Median uplift in damage per tempo over the build's own deck, and the
build's win rate change (the apothecary, bruiser, ranged ambusher and
spellslinger already win 10 of 10 against the bear, so their win rate
cannot rise):

| card | mean DPT uplift | win rate | positive on | what it is |
|---|---|---|---|---|
| exhausted_assault | +7.0 (bruiser **+36**) | +10 pts | 6 of 6 | 4 damage × 3 hits, free at 0 mana |
| consecutive_snap | +5.7 | +13 pts | 6 of 6 | 3 damage, sticky, +9 per reuse |
| multishot | +5.1 | +8 pts | 6 of 6 | 7 damage × 3 hits, crit ramps |
| vines | +1.3 | +5 pts | 4 of 6 | root 3 turns, 4 a turn |
| mixed_bag, dagger_throw, thrown_stone, quick_arrow | +1.0 – +1.3 | +2 – +3 pts | 6 of 6 | cheap 1–2 tempo hits |
| if_pigs_could_fly | +1.1 | 0 | 6 of 6 | 15 AOE for 0 tempo |
| … 170 cards within ±0.5 … | | | | |
| shadows | −0.7 | −3 pts | 1 of 6 | invisible 10 tempo for 4 tempo |
| choke, armor_break | −0.9 / −1.0 | −3 / −5 pts | 0 of 6 | silence DoT / armor-only |
| lead_arrow, spirit_arrow, sky_fall | −0.9 – −1.0 | — | 1 of 6 | needs high ground / line / lands in 10 tempo |
| heavy_swing | −1.9 (bruiser −6.9) | — | 0 of 6 | 20 damage, all-offensive hand only |

- **Multi-hit cards are the strongest cards in the game for every build,
  and by a wide margin on the bruiser.** Exhausted Assault's three 4-damage
  hits each carry the bruiser's full per-hit STR and sphere bonus, so the
  "4 damage" card lands 133 in three tempo at 30 STR; Multishot and
  Consecutive Snap work the same way. Flat per-hit bonuses times hit count
  is the lever, not the cards' printed numbers. The same mechanism makes
  the bow build's crits one-shot bosses at level 50.
- **The card shark and shadow blade are the builds a card can rescue.**
  Consecutive Snap, Multishot or Exhausted Assault in the opening hand turn
  the card shark's 60 % against the bear into 100 %, and the shadow blade's
  10 % into 50 %. Nothing else moves a win rate by more than a few points:
  170 of 202 cards are within ±0.5 DPT of the card they replaced.
- **Shadows is a net loss on every build but one**, even with the policy
  pricing invisibility. Four tempo for ten invisible tempo against a bear
  that mauls every four is two and a half hits avoided for the price of an
  attack, and the shadow blade cannot use the window because its own
  attacks do under 10. Invisibility needs a payoff while invisible (Shadow
  Obi's +5 is the only one) to be worth its tempo.
- **Cards that never fire on a flat arena**: Lead Arrow (needs high
  ground) and Armor Break (nothing to break on most of the roster) are dead
  draws; Sky Fall lands ten tempo later than the policy can plan for.
- **Heavy Swing read as a 90-point loss before it read as a card**: its
  all-offensive-hand gate was not mirrored in the harness, the lookahead
  kept choosing it, and the fight idled out. The harness now mirrors the
  gate and drops any refused play from the legal actions for the rest of
  the tempo; the row above is the corrected one.

## Generated decks against the hand-written ones

Eight deck recipes (shape, school, reach, theme words) filled from the
whole pool by the generator, ranked by each card's measured uplift on
that build from the single-card sweep, played on every designed build
against the six-enemy roster at level 18, 30 seeds
(`tests/sim/sweeps/ryan_recipes.txt`, `sim_out/charts/ryan_recipes.csv`).
Win rate; the build's own hand-written deck is the first column:

| build | own deck | caster | top_twelve | ghost | instants | poisoner | dagger_rush | archer | discard_mill |
|---|---|---|---|---|---|---|---|---|---|
| spellslinger | 0.76 | **0.97** | 0.89 | 0.89 | 0.81 | 0.81 | 0.78 | 0.78 | 0.79 |
| card_shark | 0.62 | 0.77 | **0.81** | 0.77 | 0.77 | 0.69 | 0.61 | 0.77 | 0.59 |
| apothecary | 0.61 | **0.78** | 0.75 | 0.76 | 0.72 | 0.72 | 0.76 | 0.53 | 0.59 |
| bruiser | 0.93 | 0.96 | 0.94 | **0.97** | 0.95 | 0.89 | 0.92 | 0.91 | 0.91 |
| ranged_ambusher | 0.47 | **0.55** | 0.54 | 0.55 | 0.53 | 0.51 | 0.48 | 0.45 | 0.49 |
| shadow_blade | 0.31 | **0.34** | 0.32 | 0.23 | 0.33 | 0.24 | 0.28 | 0.28 | 0.24 |

- **Seven of eight generated decks beat the hand-written decks on
  average**, and the data-driven ones beat them most: `caster` +11 win
  points and +2.4 median DPT across the builds, `top_twelve` +9 and +2.2.
  The hand-written decks are not bad; the pool is just wider than any
  theme. The one that lost, `discard_mill`, is also the one whose theme
  words pull in the weakest cards.
- **The spellslinger wants spells.** The caster recipe (Vines, If Pigs
  Could Fly, Worms Armageddon, Mana Surge, Spark, Harness Lightning,
  Cryonics…) takes it from 76 % to 97 % and from 2.7 to 10.0 median DPT:
  its hand-written potion deck was playing the wrong school for a 27-INT
  build with the Belt of Scrolls. Same for the apothecary (61 % to 78 %
  on the caster deck).
- **The card shark's best deck is the universal top twelve** (Multishot,
  Consecutive Snap, Exhausted Assault, Vines, Thrown Stone…): 62 % to
  81 %, 4.4 to 9.3 median DPT. Its discard-engine deck is the one the
  recipe sweep ranks last for it.
- **No deck rescues the shadow blade** (23–34 % on all nine decks) or
  lifts the ranged ambusher past 55 %. For those two the gear and the
  damage stat are the ceiling, which is the same answer the passive sweep
  gave.
- **The instants recipe is the test of Quick Step**: four reaction cards
  in a 12-card deck is as many as the pool allows, and it ranks fifth of
  eight. The passive now has something to fire on; whether it is worth
  ranks is a separate run (`focus:quick_step` with `recipe:instants`).

Caveat: the recipes were ranked by the Large Bear pass of the single-card
sweep; the full three-enemy pass (`ryan_card_swap.txt`, about 36,000
fights) will re-rank them, and the generated deck changes with every card
or build change by design.

## Proposed rule: the invisibility draw

The designer's proposal: *whenever the player enters invisibility they
look at their top card and may choose to draw it; if they do, they must
discard a separate card.* Implemented in the game (the buff manager
reports the visible-to-invisible transition, main offers the choice and
the discard picker) and in the lookahead (draw when the hand is short or
holds a card worth less than a fresh one, discard the worst card). Then
the quick-feedback loop: the same runs with the rule reverted and with it
on, same seeds, same harness (`compare_runs.py`).

| build | reached | verdict |
|---|---|---|
| shadow_blade | 53 of 190 runs | no significant change: win rate −1 pt, DPT +1.6 %, damage taken ±0 |
| card_shark | 12 of 190 | no significant change (DPT +1.5 %) |
| ranged_ambusher | 12 of 190 | no significant change (Poof and Weave from the Shadow Obi, 3 uses in 30 fights) |
| apothecary | 9 of 190 | no significant change (damage taken −6 %, p = 0.35 on the Shadows swap) |
| bruiser, spellslinger | 6 and 5 of 190 | no significant change |
| shadow_blade at 50, Now You See Me / Eye Scrape maxed | 82 of 180 | no significant change (win rate +1 pt, DPT +1.8 %) |

**Verdict: safe, and not enough.** The rule reaches every build that
has an invisibility source, fires every time (the shadow blade's 11–12
invisibilities a fight against the bear each became a look and usually a
draw), and moves nothing by more than noise. The shadow blade's problem is
that its cards deal under 10; a free look at the next one is another
sub-10 card. Where the draw could matter — a deck whose cards are strong,
like the bow build's — the build goes invisible three times in thirty
fights. The rule is a fine quality-of-life rider and worth keeping for
feel, but if the aim is to make invisibility *worth its tempo*, the
payoff has to be damage or safety while invisible (the Shadow Obi's +5 is
the only such rider today), or Now You See Me needs displacement sources
to fire on. Both are things the single-card and passive sweeps can test
the moment they exist.

Two harness notes from this run, both fixed before the comparison above
was taken: the first before/after showed the ranged ambusher +11 win
points, which turned out to be the refused-play stall fix (the old
runner let the lookahead re-pick a refused card, idling fights into
timeouts; the ranged ambusher's deck has two such cards, Lead Arrow and
Spirit Arrow) and not the rule — the clean before-snapshot was re-run
with the rule reverted and only then compared. And the runner could
answer one picker twice in a frame; it now renames a picker once
answered.

## What each component is worth

- **Item set: the biggest lever.** Across every deck, swapping the gear
  moves damage per tempo by 8.2 (bruiser 9.5 mean, apothecary 1.3); the
  deck moves it by 2.9 (daggers 7.0 best, starter 5.0 worst). Decks are
  mostly interchangeable within a gear set.
- **Stat allocation: STR wins everywhere**, including the bow build with
  Deadeye Form lit (ranged ambusher: 11.0 DPT on `str_det` against 6.8 on
  its own `dex_agi`) and the card shark (8.2 vs 4.9). Nothing a DEX, AGI,
  INT or WIS spread does for damage competes with 30 STR's +15 per hit.
- **Sphere path: small.** Within an allocation the paths differ by ≤ 0.8
  DPT; the only visible pairings are `deadeye` for `dex_agi` (+0.8) and
  `bulwark` for `str_det` (+0.5).
- **Passive sets: smaller still.** Swapping all seven passives moves a
  build by at most 1.3 DPT (card shark: `none` 6.3, `relentless` 7.5).

Two caveats before reading these as balance verdicts. The component
readings above come from the sweep before the policy priced invisibility,
poison stacking, discard engines and flash / brain spends (the designed
table has been re-run; the component sweeps have not), and the sphere and
passive readings come from 5–10 seeds; the full sweeps in
`tests/sim/sweeps/ryan_*.txt` are the ones to trust.
