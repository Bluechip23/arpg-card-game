# Milestone 3 — validation-run findings

> **Pre-audit.** This section was measured before the tester audit
> (`docs/sim/tool_audit.md`): damage per tempo here counts overkill, and
> runs predate the refused-play, reseeding and picker-card fixes. Win-rate
> shapes should hold; re-run with `tools/sim_analysis/run_sweep.sh` before
> quoting a number.

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

# Stephen — hands, engravings and the designed builds (merged main, 2026-10-17)

The same sweep as Ryan's below, on the branch after main was merged in
(items and cards as `data/*.tres`, the status-effects rework). 19,990
fights, level 18, lookahead player: four designed builds against six
enemies and a wolf pack (100 seeds), every grip, off-hand weapon and
engraving against the Large Bear, Earth Mage and Wyvern (10 seeds each,
paired with the designed build on the same seeds).
`build_matrix.py --character stephen --root sim_out/stephen_full`.

## Designed builds

| Build | Bugbear | Earth Mage | Ice Troll | Large Bear | Pack | Treant | Wyvern |
|---|---|---|---|---|---|---|---|
| crooked_duelist | 1.00 | 0.99 | **0.27** | 0.64 | **0.39** | **0.34** | **0.04** |
| heavy_swing | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 0.78 | 0.90 |
| longshot_ranger | 1.00 | 1.00 | 0.99 | 1.00 | 1.00 | 1.00 | 0.93 |
| sentinel_duelist | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 0.82 | 0.90 |

The longshot ranger is Stephen's card shark: 12-29 damage per tempo and
nothing below 0.93. The crooked duelist (Rusty Dagger, Crooked Dueling
Shield) is his shadow blade: a dagger's damage with a duelist's health.

## Two-handed grip

- A build's own weapon gripped changes little (+0.3 DPT on the swords).
- Among gripped weapons the gain is small everywhere (Umbral Eclipse
  +1.6, Phoenix Feather +1.1, Sabre Tooth +0.8); Stephen's +10% off hand
  makes the hand he gives up worth more than Ryan's.
- Bessy, Hammer of Ajax and Umbral Eclipse are over the crooked duelist's
  carry; Bessy over the sentinel's.

## Dual wielding: a second weapon in the off hand

- Nine Ruins of Sanguine is the item of the sweep: +8.2 DPT on the
  longshot ranger (main hand) and positive in the off hand on every
  build that can hold it.
- Wrist Rocket again: +1.3 DPT on average, positive on all four, +27
  points of wins for the crooked duelist.
- The sentinel duelist's best items are all off-hand weapons (Umbral
  Eclipse +1.8, Hammer of Ajax +1.6, Wrist Rocket +1.5): the Sword
  Breaker it carries is the weak slot.

## Engravings, one card at a time

> **Brad's War Rack (2026-10-17).** The rack is now a slot for one weapon,
> drawn free and held two-handed for 20 tempo before his usual gear returns
> on its own (60 tempo between draws). Brad's weapon-set results below were
> run under the old hands-for-back exchange (two items, a 25-tempo cooldown,
> no automatic return) and his `bow` set is now the bow alone; re-run Brad's
> stance and weapon-set sweeps before reading those rows.

> **Deck cap (2026-10-17).** The game now caps the deck at 25 cards
> counting the ones slotted into items (12 outside items as before;
> item-granted cards count toward neither). These sweeps were run before
> the cap and the tester still lets a build carry more (the audit reports
> it). At level 18 Ryan's card shark holds 37 (25 engraved), the bruiser
> 32 and the ranged ambusher 28; Stephen's builds hold 17–20. Any Ryan
> engraving result on those three builds is a slot the game would now
> refuse once the deck is full — the per-card ranking still says which
> engravings are worth their place.

| Card | Slots | Builds | DPT | Wins | Helps in |
|---|---|---|---|---|---|
| Mixed Bag | 2 | 1 | +17.9 | +3 pts | 2 of 2 |
| Consecutive Snap | 1 | 1 | +9.1 | 0 | 1 of 1 |
| Quick Shot | 5 | 3 | +3.7 | +1 pt | 5 of 5 |
| Dagger Throw | 4 | 4 | +3.2 | +7 pts | 4 of 4 |
| Premeditated | 1 | 1 | +2.0 | +17 pts | 1 of 1 |
| Oops | 1 | 1 | +1.6 | +20 pts | 1 of 1 |
| Savage Strike | 2 | 2 | +1.5 | 0 | 2 of 2 |

Worst: Shadows (−3.9, helps in 0 of 4), Armored Discipline (−3.2, 0 of
5), Mirror Mirror (−3.0, 0 of 3), Empower, Choke. Mixed Bag in the bow or
quiver is the biggest single engraving measured on any character.

**Over-engraving** is milder than Ryan's: the longshot ranger gains +7.0
DPT with Chewbacca's Bandolier stripped and +3.0 with the Stringless
Sender stripped; the swords lose 1.3-1.4 DPT when Fallen's Wrath is
stripped, so its Savage Strike / Reckless Strike engravings earn their
slots. The crooked duelist wins 10 points more with its Shadow Cowl
empty.

Same caveats as Ryan's: 10 seeds per cell; an engraving variant
spotlights its card into the opening hand. Thirty runs where a heavy
swapped-in weapon stopped the build switching back to its own set are
flagged and left out of the paired tables.

# Ryan — hands, engravings and the designed builds (fixed tester, 2026-10-15)

The full stance and engraving sweep on the tester with every mechanics fix
in (armor in card hits, the game's own tempo and mana, point-aimed cards
priced and aimed, summons stepped, prompts answered, the Manifest zone,
Power and Burden decisions, draws valued by the deck) and the two game
fixes (point cards no longer land on the caster; shield Overdraw riders
fire). 42,500 fights, level 18, lookahead player: the designed builds
against six enemies and a wolf pack (100 seeds), every grip, off-hand
weapon and engraving against the Large Bear, Earth Mage and Wyvern
(10 seeds each, paired with the designed build on the same seeds).
`tests/sim/sweeps/ryan_{designed,stances,engrave,item_swap}.txt`;
`build_matrix.py --character ryan --root sim_out/ryan_full`.

## Designed builds

| Build | Bugbear | Earth Mage | Ice Troll | Large Bear | Pack | Treant | Wyvern |
|---|---|---|---|---|---|---|---|
| apothecary | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | **0.29** | 0.76 |
| bruiser | 1.00 | 1.00 | 1.00 | 1.00 | 1.00 | 0.84 | 0.86 |
| card_shark | 1.00 | 1.00 | 0.91 | 0.99 | 1.00 | 1.00 | 0.95 |
| ranged_ambusher | 1.00 | 1.00 | 0.62 | 0.96 | 1.00 | 0.59 | 0.56 |
| shadow_blade | 1.00 | 0.78 | **0.08** | **0.31** | 0.78 | **0.17** | **0.02** |
| spellslinger | 1.00 | 0.99 | 1.00 | 1.00 | 1.00 | 0.70 | 0.95 |

Shadow blade is the outlier at level 18: 24 health against hits of 16-33.
Card shark and spellslinger hit hardest (up to 26 and 31 damage per tempo).

## Two-handed grip

- **A build's own weapon gripped** changes little: bruiser +0.6 DPT;
  apothecary and spellslinger take 13-24 more damage, because gripping
  empties the off hand (their second wand, the Reaction Rod).
- **Heavy weapons are what the grip is for**, exactly as weight ÷ 25 says:
  Bessy +3.2 DPT, Hammer of Ajax +1.8, Umbral Eclipse +1.8, Axe's Axe +0.6
  (and +11 points of wins) over the same weapon held one-handed. Wands,
  daggers and the Reaction Rod gain nothing or lose.
- **Only the STR builds can lift them.** Bessy, Hammer of Ajax, Umbral
  Eclipse and Axe's Axe are over carry capacity for apothecary, shadow
  blade and spellslinger (and most for card shark), gripped or not.

## Dual wielding: a second weapon in the off hand

- **Card shark wants a second blade**: Nine Ruins of Sanguine +6.4 DPT,
  Sabre Tooth +6.3, Bladed Doughnut +4.1, each +10 points of wins, in the
  off hand (Sabre Tooth in the main hand instead: −1.8).
- **Wrist Rocket is the best item in the pool**: +2.1 DPT on average,
  positive on 4 of 6 builds, +8.7 DPT and +13 points on the ranged
  ambusher. It is the one "Other" weapon with a slot, which takes any
  labelled card: the wildcard engraving slot is most of its value.

## Engravings, one card at a time

Best cards to engrave (mean change over every slot that takes them):

| Card | Slots | Builds | DPT | Wins | Helps in |
|---|---|---|---|---|---|
| Exhausted Assault | 1 | 1 | +9.7 | +7 pts | 1 of 1 |
| Consecutive Snap | 5 | 4 | +7.0 | +16 pts | 5 of 5 |
| Mana Surge | 3 | 3 | +3.6 | +1 pt | 3 of 3 |
| Vines | 3 | 3 | +2.5 | +6 pts | 3 of 3 |
| Multishot | 3 | 2 | +2.5 | +8 pts | 3 of 3 |
| Mixed Bag | 3 | 2 | +2.3 | +10 pts | 3 of 3 |
| Dagger Throw | 13 | 6 | +1.9 | +6 pts | 13 of 13 |
| Thrown Stone | 14 | 6 | +1.2 | +8 pts | 13 of 14 |

Worst: Armored Discipline (−0.9, helps in 0 of 8 slots), Heroic Leap,
Shadows (−0.8, helps in 3 of 19), Barbed Exterior (0 of 7), Sky Fall,
Choke, Empower, Shield of Growth (1 of 13).

**Over-engraving costs.** Stripping an item's engravings *raised* damage on
most builds, most of all the card shark, which carries 25 engraved cards
on a 12-card deck: Boot Holsters stripped +7.1 DPT, Wrist Rocket +7.1,
Shadow Cowl +5.3, The Headbandz +4.6, each with ~13 less damage taken.
The shadow blade wins more with any one of its items stripped (+17 to
+27 points: Shadow Cowl, Houdini's Slippers, Sabre Tooth, Momentum Mits,
Assassin Belt), at a small cost in damage. Engraved cards ride on top of the deck, so a weak one dilutes the
draws; the readings above are what the designer's armor-slot pools (mostly
utility) cost in practice.

Read with care: an engraving variant spotlights its card into the opening
hand (as the card swap does), so it is fair between candidates but flatters
every engraving a little against the designed build; 10 seeds per cell.

# Ryan — stored-build readings (audited harness)

Everything in this part was re-run on 2026-10-13 on the audited tester
(`docs/sim/tool_audit.md`): full sphere budget, overkill not counted as
damage, picker cards playable, refused plays dropped, stalemate breaker,
seeds pinned across processes. Level 18 unless marked; lookahead policy;
30 seeds for designed builds, 15 for tactics, recipes and the level-50
focus, 10 per card or item in the swaps. Every job folder carries its
`loadout.json` and code stamp. Read these as direction: cards and enemies
will change under them, and the point of the tool is to re-run them.

> **Superseded in part** by the section above (designed builds, hands,
> engravings, on the fixed tester). The tables below are older.
>
> **Since then (not yet re-run):** gauntlet active skills became policy
> actions (Ryan's Techno Wraps, Spidey Web Shooters, Sleeved Katar and
> every swapped-in gauntlet were measured on stats alone), the skill tree's
> stage gate is enforced on every spread (level-18 focus readings had
> impossible ranks), and the lookahead now walks in when a card in hand
> beats a bow's auto attack. Ryan's builds carry no second weapon set, so
> weapon swaps do not touch these tables. Shapes should hold; re-run
> before quoting a number.

**Retractions.** Four earlier readings were artifacts of the tester and
are withdrawn: "the shadow blade does not scale" (the sphere grid was not
spent; it wins 92 % at level 50), "Lead Arrow / Spirit Arrow hurt every
build" (refused-play stalls), the eight picker cards scoring as dead
(never played), and the ranged ambusher's 0.83 baseline (stalls).

## Designed builds

Win rate (Pack = Wolf, Wolf, Giant Hawk together):

| build | Bugbear | Earth Mage | Large Bear | Wyvern | Treant | Ice Troll | Pack | mean | median DPT |
|---|---|---|---|---|---|---|---|---|---|
| bruiser | 1.00 | 1.00 | 1.00 | 0.73 | 0.83 | 1.00 | 1.00 | 0.94 | 8.1 |
| spellslinger | 1.00 | 1.00 | 1.00 | 0.63 | 0.77 | 0.97 | 1.00 | 0.91 | 4.1 |
| apothecary | 1.00 | 1.00 | 1.00 | 0.80 | 0.07 | 1.00 | 1.00 | 0.84 | 2.8 |
| card_shark | 1.00 | 1.00 | 0.93 | 0.57 | 0.63 | 0.63 | 1.00 | 0.82 | 5.8 |
| ranged_ambusher | 1.00 | 1.00 | 0.97 | 0.57 | 0.47 | 0.60 | 0.97 | 0.80 | 8.6 |
| shadow_blade | 1.00 | 0.67 | 0.17 | 0.00 | 0.17 | 0.10 | 0.67 | 0.40 | 3.2 |

At level 50 (three mythics, 100 sphere nodes, enemies at 2.5× health and
2× damage as a stand-in for end-game tuning):

| build | Bugbear | Earth Mage | Large Bear | Wyvern | Treant | Ice Troll | mean | median DPT |
|---|---|---|---|---|---|---|---|---|
| ranged_ambusher | 1.00 | 1.00 | 1.00 | 0.93 | 1.00 | 1.00 | 0.99 | 28.1 |
| spellslinger | 1.00 | 1.00 | 1.00 | 0.87 | 1.00 | 1.00 | 0.98 | 7.5 |
| bruiser | 1.00 | 1.00 | 1.00 | 0.73 | 0.87 | 1.00 | 0.93 | 16.9 |
| shadow_blade | 1.00 | 1.00 | 1.00 | 0.53 | 1.00 | 1.00 | 0.92 | 7.0 |
| card_shark | 1.00 | 1.00 | 1.00 | 0.60 | 0.87 | 1.00 | 0.91 | 13.9 |
| apothecary | 1.00 | 1.00 | 1.00 | 0.53 | 0.47 | 1.00 | 0.83 | 5.3 |

- **The shadow blade is the one build that is weak at 18 and fine at 50.**
  Its gap is early: 40 % at level 18 against 82–94 % for the rest. The
  sphere grid's 64 extra nodes are what carry it at 50.
- **The Wyvern and the Treant are where every build loses, and for
  reasons the sweeps can name.** The remaining timeouts (22 % of Wyvern
  fights, 37 % of Treant fights at 18) are real fights, not idling: the
  Wyvern kites melee builds (45 moves to the bruiser's 50–98 damage in a
  timed-out fight), the Treant roots the apothecary out of reach 21–25
  times a fight, and it out-heals the bow (35 heals against 800 damage).
- **The ranged ambusher still scales hardest** (28 median DPT at 50, with
  crit one-shots in its mean), the bruiser is the stable reference.

## Tactics on every build

A tactic is an overlay any build can take (cards into the deck's tail, an
item into its slot, ranks into its passives). Win-rate change against
each build's own loadout:

| build | burst | poison | invisibility | discard | mobility |
|---|---|---|---|---|---|
| shadow_blade | +14 | **+27** | −2 | −2 | −9 |
| card_shark | **+8** | −5 | 0 | −1 | −3 |
| apothecary | **+7** | **+7** | +3 | +4 | +4 |
| spellslinger | +4 | +2 | **+7** | −2 | −6 |
| ranged_ambusher | **+5** | +2 | +3 | 0 | −5 |
| bruiser | +2 | 0 | +2 | −1 | 0 |

- **Burst** (Exhausted Assault, Multishot, Consecutive Snap, Surprise
  Opener) helps every build: per-hit bonuses times hit count.
- **Poison is the shadow blade's answer** (40 % → 67 %): a damage source
  that does not depend on its dagger.
- **Invisibility as a tactic is within a few points everywhere**; best on
  the spellslinger.
- **Mobility costs the shadow blade, bow and spellslinger** 5–9 points:
  the cards displace a build that wanted to stand and hit.

## The invisibility draw (proposed rule)

*Whenever the player enters invisibility they look at their top card and
may draw it; if they do, they must discard a separate card.* Measured on
every build with and without the invisibility tactic, rule reverted
against rule on, same seeds, final policy (which only draws when the
revealed card beats its weakest card, and values engine cards when it
discards):

| build | runs the rule changed | win rate | DPT |
|---|---|---|---|
| shadow_blade | 104 of 210 | −2 pts | −0.8 % |
| spellslinger | 73 of 210 | +2 pts | +2.2 % |
| apothecary | 50 of 210 | −2 pts | −0.5 % |
| card_shark | 48 of 210 | 0 | +0.1 % |
| bruiser | 38 of 210 | 0 | 0 |
| ranged_ambusher | 38 of 210 | +1 pt | +3.0 % |

**Verdict: neutral.** It fires on every build that goes invisible and
moves none significantly. The one recurring signal is the spellslinger
with the invisibility tactic against the Treant (67 % → 93 %, p = 0.06,
also seen in the first measurement): worth 100 seeds if that matchup
matters. As a feel rule it is safe; it does not make invisibility worth
its tempo, which still needs a payoff while invisible.

## Every card, one at a time

Each of the 202 base-deck-legal cards swapped in for the last card of
each designed deck and spotlighted into the opening hand, against the
Large Bear, paired by seed (`sim_out/charts/ryan_card_swap.csv`; also the
ranking deck recipes use). All 202 measurable on every build.

| card | mean median-DPT uplift | positive on |
|---|---|---|
| Exhausted Assault | +7.2 (bruiser +17) | 5 of 6 |
| Consecutive Snap | +5.4 | 6 of 6 |
| Multishot | +3.5 | 6 of 6 |
| Vines | +1.9 | 4 of 6 |
| Dagger Throw | +1.8 | 5 of 6 |
| If Pigs Could Fly | +1.3 (and +112 against the pack on INT builds) | 5 of 6 |
| … | | |
| Shadows | −0.9 | 0 of 6 |
| Choke | −0.9 | 0 of 6 |
| Adimantium Wall | −0.7 | 0 of 6 |

- **Multi-hit cards lead for every build**: each hit carries the full
  per-hit bonus (STR, sphere damage, item riders), so a three-hit card is
  worth three times every flat bonus the build has stacked.
- **If Pigs Could Fly is the outlier against packs**: a 0-tempo area burst
  that deals 95 to the Wolf/Wolf/Hawk pack (116 total health) for the
  27-INT spellslinger, +112 DPT for the apothecary and spellslinger. Chain Lightning is the
  runner-up (+10 on the spellslinger). On a single enemy both are modest.
- **Shadows is a net loss on every build** (four tempo for ten invisible
  tempo, nothing to cash it in on).
- **Wrath of the Sea** (Poseidon's Trident grants it, but it is not
  shop-excluded, so it is in the pool) lifts the shadow blade by 50 pts;
  see `bugs_found.md`.

## Every item, one at a time

Each of the 105 mythic and legendary items in its natural slot on each
build, exactly one item changed (`sim_out/charts/ryan_item_swap.csv`).

| item | mean median-DPT uplift | win rate | positive on |
|---|---|---|---|
| Girdle of Aphrodite | +2.7 | +2 pts | 3 of 6 (card shark +15) |
| The Precious | +2.2 | −2 pts | 3 of 6 (bow +7) |
| Megingjord | +2.1 | +10 pts | 5 of 6 |
| Jordan 1s | +1.9 | **+13 pts** | 5 of 6 (shadow blade +80 pts) |
| Monocle | +1.7 | +5 pts | 5 of 6 |
| … | | | |
| Bow of Budding Blasts | −1.1 | | 0 of 6 |
| Feral Evocation | −1.1 | | 2 of 6 |
| Sabre Tooth | −1.1 | | 1 of 6 |

- **Jordan 1s and Megingjord are the items that win fights**: on the same
  ten seeds the shadow blade goes from 20 % to 100 % against the Large
  Bear with Jordan 1s and to 80 % with Megingjord.
- **The card shark's belt slot is its lever**: Girdle of Aphrodite,
  Alchemist Belt and Megingjord each add 12–15 DPT.
- **Sabre Tooth, the shadow blade's own mythic, is among the weakest
  items on the other five builds** (positive on one of them).
- **Not wearable** (reported, not scored): Adimantium, Bessy, Briarhide
  Plate, Supernova Cuirass, Umbral Eclipse, Divine Resistance and Hammer
  of Ajax are over carry capacity for every Ryan build except the bruiser;
  no shield fits beside the bow.

## One passive maxed, level 50

Each of Ryan's 12 tree passives at rank 15, the other 34 points spread
over the build's set, against the scaled Large Bear, Earth Mage and
Wyvern. Mean median-DPT uplift over the designed spread, and how often
the maxed passive fired per fight:

| passive | DPT uplift | fired / fight | note |
|---|---|---|---|
| Surprise Opener | +0.2 | 1.0 | the best column on the card shark (18.3) and apothecary |
| From the Hip | +0.1 | 2.0 | card shark and shadow blade |
| Now You See Me | −0.4 | 0.6 | fires 2.0 a fight on the shadow blade now that Blink is played |
| Let's Dance | −0.7 | 4.1 | fires most, worth little |
| Quick Step | −0.5 | 0.01 | **never fires: no Ryan deck holds an instant** |
| Stimulant, Mad Scientist, Pop Rocks | −0.8 | 0.35–0.65 | fire on the apothecary and spellslinger only |

Maxing a passive costs more than it gives on nearly every build: the 15
ranks come out of passives that were doing more at rank 6–11.

## Generated decks against the hand-written ones

Eight recipes filled from the pool by the committed ranking, win rate
(the build's own deck: bruiser 0.94, spellslinger 0.91, apothecary 0.84,
card shark 0.82, ranged 0.80, shadow blade 0.40):

| build | caster | ghost | top_twelve | instants | poisoner | archer | dagger_rush | discard_mill |
|---|---|---|---|---|---|---|---|---|
| spellslinger | **1.00** | 0.97 | 0.98 | 0.96 | 0.98 | 0.86 | 0.90 | 0.91 |
| bruiser | 0.97 | **0.98** | 0.97 | 0.95 | 0.93 | 0.95 | 0.96 | 0.94 |
| card_shark | **0.96** | 0.95 | 0.93 | 0.89 | 0.88 | 0.88 | 0.84 | 0.86 |
| apothecary | **0.94** | 0.94 | 0.94 | 0.93 | 0.90 | 0.79 | 0.87 | 0.84 |
| ranged_ambusher | 0.70 | **0.86** | 0.78 | 0.79 | 0.70 | 0.78 | 0.74 | 0.72 |
| shadow_blade | 0.42 | 0.43 | 0.49 | **0.53** | 0.30 | 0.36 | 0.31 | 0.25 |

The ghost, top-twelve, instants and caster recipes beat the hand-written
decks on average (+5 to +7 points); the card shark gains 14 points from
the caster deck, the shadow blade 13 from the instants deck. Discard mill
is the one recipe that loses.

## Not re-run on the audited harness

The items × decks and allocation × sphere matrices from the first Ryan
pass (`ryan_items_x_decks.txt`, `ryan_alloc_x_sphere.txt`) predate the
sphere-grid fix, which changes allocation × sphere most of all. Their
earlier readings (item set the biggest lever, STR winning everywhere)
are withdrawn until re-run.
