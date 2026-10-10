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
| ranged_ambusher | 0.87 | 0.83 | 0.83 | 0.10 | 0.13 | 0.07 | 6.0 |
| shadow_blade | 1.00 | 0.63 | 0.17 | 0.00 | 0.00 | 0.03 | 2.2 |

The bruiser (Sword of Theseus, plate, 30 STR) is still the only build
that beats the whole roster. Pricing the discard engine lifted the card
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
- Which maxed passives fire at all (per-fight trigger counts, the
  `passive_triggers` column) is being re-run and will go here.

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
