# Milestone 3 — validation-run findings

> **Note (2026-10-22).** Every run on this page predates the rule changes of
> 2026-10-20 to 2026-10-22: the 8-card base deck cap (25 in all with slotted
> cards; it was 12, then 10), the five-card starter deck (Attack, Exposing
> Strike, Block, Braced Draw, Heal), Tome folded into Wand, and the shield
> Block at 4 tempo. "The starter deck" and deck sizes below mean the rules of
> the day; re-run before comparing against today's game.

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
enemies and a wolf pack (100 seeds), every two-handing, off-hand weapon and
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

## Two-handing

- A build's own weapon two-handed changes little (+0.3 DPT on the swords).
- Among two-handed weapons the gain is small everywhere (Umbral Eclipse
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
against six enemies and a wolf pack (100 seeds), every two-handing, off-hand
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

## Two-handing

- **A build's own weapon two-handed** changes little: bruiser +0.6 DPT;
  apothecary and spellslinger take 13-24 more damage, because two-handing
  empties the off hand (their second wand, the Reaction Rod).
- **Heavy weapons are what two-handing is for**, exactly as weight ÷ 25 says:
  Bessy +3.2 DPT, Hammer of Ajax +1.8, Umbral Eclipse +1.8, Axe's Axe +0.6
  (and +11 points of wins) over the same weapon held one-handed. Wands,
  daggers and the Reaction Rod gain nothing or lose.
- **Only the STR builds can lift them.** Bessy, Hammer of Ajax, Umbral
  Eclipse and Axe's Axe are over carry capacity for apothecary, shadow
  blade and spellslinger (and most for card shark), two-handed or not.

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

## Milestone 5 — the combo planner on 3a (2026-10-18)

`combo_planner` (lookahead with depth: every play sequence that fits the
rest of the bar, priced with lookahead's terms over a shadow state, plus
bar-end potential; see the sim README) re-ran the enemy strategy index
beside `greedy_dpt` and `lookahead`: the baseline level-5 Brad with the
starter deck and a Short Sword, 61 acting enemies, 30 seeds each
(`tests/sim/sweeps/enemy_strategy_m5.txt`, `strategy_index.py --strategic
combo_planner`, `sim_out/charts/strategy_index.csv`).

**Verification first.** `tests/sim/scenarios/setup_payoff.gd` — a boxed-in
Brad against a plated Skeleton whose second swing is lethal — is won only
by Stance Switch (strip the plate, 2 Vulnerable) then Slice into it.
Lookahead plays Slice first and loses every seed; the planner wins every
seed on the fifth tempo, with the registry empty and with the pair
registered. On the skeleton fight (no setups in the deck) the two match:
win 1.00 / 1.00, damage per tempo 2.05 / 2.04, taken 2.5 / 2.5.

**The strategy gap barely moved, and that is the honest reading of this
deck.** Mean win rate greedy 0.405, lookahead 0.568, planner 0.572; mean
damage taken 15.8 / 16.6 / 16.6. Per enemy the planner's win rate changed
on 8 of 61 enemies (better on 7, worse on 1) and was identical on 53:

| Enemy | greedy | lookahead | planner | planner − lookahead | taken (la) | taken (planner) |
|---|---|---|---|---|---|---|
| SCREECHER | 0.37 | 0.90 | 0.97 | +0.07 | 8.3 | 6.2 |
| ROC | 0.00 | 0.07 | 0.13 | +0.07 | 25.7 | 27.7 |
| CONSUMED | 0.37 | 0.93 | 0.97 | +0.03 | 11.7 | 11.5 |
| SPIRIT_COLLECTOR | 0.00 | 0.83 | 0.87 | +0.03 | 15.6 | 15.3 |
| GIANT_HAWK | 0.23 | 0.73 | 0.77 | +0.03 | 18.3 | 17.6 |
| NECROMANCER | 0.03 | 0.23 | 0.27 | +0.03 | 33.9 | 34.3 |
| ICE_MAGE | 0.00 | 0.20 | 0.23 | +0.03 | 36.4 | 36.9 |
| EARTH_MAGE | 0.00 | 0.13 | 0.03 | -0.10 | 32.0 | 32.4 |

Every difference is within 30-seed noise (one win is 0.033). The starter
deck holds no setup card — three Slashes, three Blocks, two Draws, Gain
Mana, Heal — so there is nothing for a bar-long plan to set up and the
planner's shadow state only ever changes an enemy's health; it reduces to
lookahead, as designed. The strategy gap on this deck is a measure of
one-step play against an auto-attacker, and the planner confirms rather
than raises it. Where planning will show is on decks that carry amp,
control and burst together (Stance Switch, M for Mini, Cupid's Golden
Arrow, the Marks, the big attacks): run 3a with the designed builds
(`gen_build_sweeps.py`) or a deck with those cards to measure it, and
run 3b with the planner unaided to find the pairs worth promoting.

The registry is empty on purpose: 3b has scored 15 pairs on the starter
baseline and every one came out negative, so nothing has earned a place.
It is a floor, not a ceiling — promote a pair only once 3b, run with the
unaided planner, has shown it.

## 3a on Ryan's designed builds with the combo planner (2026-10-18)

**What was tested.** Ryan at level 18 in each of his six designed builds
(`tests/sim/builds/ryan_builds.gd`: apothecary, bruiser, card shark,
ranged ambusher, shadow blade, spellslinger — each a gear set, a deck,
a stat allocation, a sphere-grid route and a passive set, composed by
`CharacterBuilds.compose` through `tests/sim/scenarios/build.gd`), one on
one against every acting enemy in the catalogue (61), with the three
bots that form the strategy index: `greedy_dpt` (best damage per tempo
now), `lookahead` (one action priced against the telegraphed intents)
and `combo_planner` (every play sequence that fits the rest of the bar,
priced on a shadow state plus bar-end potential; registry empty). 20
seeds per cell: 366 cells × 3 bots × 20 = 21,960 fights, 40-bar cap
(`tests/sim/sweeps/ryan_3a_m5_{1,2,3}.txt`, analysed by
`tools/sim_analysis/planner_gap.py --character ryan` →
`sim_out/charts/ryan_planner_gap.csv`, `ryan_planner_activity.csv`,
`ryan_planner_gap_win.png`, `ryan_planner_gap_dpt.png`,
`ryan_strategy_gap_builds.png`). The activity table is read from the
per-fight action rows, so "health lost" and "armor lost" there are real
(the summary's `total_damage_taken` is still the raw incoming amount; see
bugs_found.md).

**Headline.** Mean win rate greedy 0.861, lookahead 0.902, planner 0.911;
timeouts 3.1 % / 2.5 % / 2.3 %; median health lost per fight 3.8 / 3.6 /
2.5. Of 366 cells the planner beats lookahead on 14, loses on 2 and is
within 20-seed noise (≤ 0.10) on 350. 48 of the 61 enemies are won at
≥ 0.95 by every build with every bot: the sweep tells nothing about them
except that level 18 is past them. The reading is in the other 13.

| build | greedy | lookahead | planner | la DPT | planner DPT | plays / bar (la → planner) |
|---|---|---|---|---|---|---|
| apothecary | 0.908 | 0.915 | 0.920 | 2.6 | 2.6 | 0.89 → 1.04 |
| bruiser | 0.935 | 0.927 | 0.942 | 5.7 | 6.4 | 1.09 → 1.21 |
| card shark | 0.848 | 0.920 | 0.920 | 11.6 | 12.1 | 1.46 → 2.13 |
| ranged ambusher | 0.848 | 0.892 | 0.904 | 13.2 | 15.4 | 1.46 → 1.73 |
| shadow blade | 0.719 | 0.815 | 0.827 | 4.2 | 4.6 | 1.22 → 1.40 |
| spellslinger | 0.909 | 0.944 | 0.952 | 8.4 | 8.8 | 1.29 → 1.82 |

**Where the planner differs, and why.** It plays more cards per bar on
every build (the shadow state lets it chain a cheap card into the one it
enables within the bar) and that shows as damage per tempo (+17 % on the
ranged ambusher, +11 % on the bruiser) more than as wins. The win-rate
gains concentrate on one enemy: the Djinn (+0.12 averaged over builds;
apothecary 0.25 → 0.55, bruiser and spellslinger 0.20 → 0.40). That gain
is an accident worth knowing about: every hit on the Djinn hands the
player Wish cards that sear the holder each cycle until erased for 60
mana at 0 tempo; lookahead prices the erase as −60 mana for 0 gain and
never plays it, the planner erases 4–6 a fight because a 0-tempo step
costs nothing in its per-tempo plan rate. Neither bot values the sear
itself. The other gains (Treant +0.05, Cerberus +0.06, Wyvern +0.04,
Grave Titan +0.04) are 1–3 seeds each and in the direction of "more
damage sooner". The two losses: apothecary vs Treant (0.40 → 0.15, and
greedy wins 0.70) and spellslinger vs Inflamed Minotaur (0.55 → 0.45,
noise). The Treant cell is the one place the strategic bots are worse
than the greedy one, and it is a game finding, not a bot one (below).

**Fights that cannot end.** Six cells time out in at least half the
seeds for both strategic bots, and each has a mechanical cause in the
enemy, not the build's strength:

| cell | timeouts | cause |
|---|---|---|
| apothecary / Hydra, spellslinger / Hydra | 100 %, 90 % | heal-to-full after the 4th hit beats any 10–15 damage swing; the healer's gear keeps her alive |
| apothecary / Inflamed Minotaur, bruiser / Inflamed Minotaur | 100 %, 100 % | Labyrinth Leap lands him off the 20×12 grid; nobody can reach anybody |
| apothecary / Treant | 85 % | Root at 2–4 tiles, every 8 tempo, forever; the Treant never closes in |
| card shark / Cerberus | 75 % | Venom Tail's 15-tempo stun on a 15-tempo clock |

All four are in bugs_found.md with the code paths. The Minotaur and
Cerberus columns of the index are timeout counts, not difficulty
readings, until those are decided.

**The hard thirteen** (planner win averaged over builds): Inflamed
Minotaur 0.10, Hydra 0.19, Ifrit 0.21, Djinn 0.22, Cerberus 0.34, Wyvern
0.72, Bone Dragon 0.74, Treant 0.75, Ice Troll 0.78, White Manticore 0.88,
Grave Titan 0.89, Armored Troll 0.90, Large Bear 0.94. The shadow blade
is the build that loses to the most of them (Armored Troll 0.40, Bone
Dragon 0.20, Ice Troll 0.15, White Manticore 0.35, Wyvern 0.05 — the
only build under 0.5 on any of those), which is a build-strength reading
and not the point of this run; the Ifrit (45 damage every 3 tempo plus a
Backflip that resets melee) is the one enemy every build loses to for a
plain damage-race reason.

**What this run says about the tool.** The planner is a safe upgrade:
never worse than lookahead outside noise, more cards per bar, more damage
per tempo, and its one real win (the Djinn) exposes a scorer gap rather
than a planning strength. The sweep's findings are mostly loops in enemy
logic that any bot falls into, which is exactly the kind of thing a
bot-vs-catalogue sweep is good at and a human playtester is slow at. The
gaps it exposes in the sim itself are listed in the README's "Known
gaps" section (2026-10-18 additions).

## 3b on Ryan's designed decks: the deck-pair ablation (2026-10-19)

**What was tested.** Whether any two cards in a designed deck are worth
more together than apart, as the combo planner plays them. For each of the
six designed builds (level 18) the deck ran whole, with one copy of each
distinct card swapped for an inert blank, and with one copy of each pair
swapped, against Armored Troll, Wyvern and Bone Dragon (hard enough to last
several bars, winnable enough that damage per tempo means something), 30
seeds each, `combo_planner` with the registry empty:
`tests/sim/sweeps/ryan_deck_pairs.txt` (726 jobs, 21,780 fights, from
`gen_deck_pairs.py`), read by `deck_pairs.py` →
`sim_out/charts/ryan_deck_pairs.csv`, `ryan_deck_pairs_cards.csv`,
`ryan_deck_pairs.png`.

**How it was scored.** Per seed, synergy(a, b) = DPT(deck) − DPT(deck − a)
− DPT(deck − b) + DPT(deck − a − b); then the mean and its paired standard
error over seeds, averaged over the three enemies. A pair is *notable* at
15 % of the deck's own DPT and *resolved* when it also clears twice its
error. The blank matters: a first pass that *removed* the card changed the
deck's size, and with it the seed's shuffle, so every variant of one size
shared a single draw order per seed and the deck-size luck swamped the card
(card shark: 7.8 DPT at 12 cards, 15.3 at 11, 12.6 at 10, every pair
reading −9; per-seed correlation with the full deck 0.01). With the blank
the four fights of a seed share their draw order until the swapped card
turns up: correlation 0.96, paired error 0.26 against 3.2 unpaired. That
pass is kept in the README as the reason the design is what it is.

**Result: no pair clears the bar; the registry stays empty.** 186 pairs
scored; the largest synergy is +0.32 DPT (card shark: Meister of
Faustmesser with Slice, 4.8 % of the deck's DPT, inside its error) and the
most negative −0.42 (ranged ambusher: Draw with Spirit Arrow). Every pair is
within ±5 % of its deck's DPT. Promotion asked for 15 % and resolution
(`promote_combos.py --csv … --min-share 0.15 --resolved`) and got nothing,
which is the honest state of these decks: as the planner plays them, no two
cards set each other up.

| build | deck DPT | largest + pair | largest − pair | cards never played |
|---|---|---|---|---|
| apothecary | 2.6 | poison bomb + poisoned blood (noise) | slash + anything (−0.14 own worth) | — |
| bruiser | 7.0 | block + slice +0.26 | — | parry, heal |
| card shark | 6.6 | meister + slice +0.32 | meister + reposition −0.18 | exacerbate wounds |
| ranged ambusher | 9.3 | spirit arrow + trick shot +0.21 | draw + spirit arrow −0.42 | lead arrow |
| shadow blade | 2.6 | dagger throw + savage strike +0.09 | — | — |
| spellslinger | 7.2 | poison bomb + continuance +0.12 | — | — |

**What the single-card worths say instead** (`ryan_deck_pairs_cards.csv`,
DPT with the card minus DPT with a blank in its place): Multishot +0.92
and Quick Shot +0.37 carry the arrows deck; Spirit Arrow is −0.51 (eight
damage for 30 mana, its line-piercing worthless one on one); Volatile
Mixture −0.21 and Exacerbate Wounds −0.13 are the card shark's engine and
both cost the deck; Slice +0.39 is the card shark's best card. Nothing in
the potions deck moves more than ±0.14.

**Why the engines read as dead — three tool gaps, with the cards that show
them.** *Exacerbate Wounds* ("3 damage for each card discarded this turn")
was played 0 times in 90 fights: its damage is conditional, the state view
prices it at 0, so the discard engine's payoff never fires and no
discard → exacerbate synergy can exist in the data. *Lead Arrow* ("1.8×
damage, requires high ground") was played 0 times: the arena is flat. *Volatile
Mixture* ("on discard 8 damage; after 5 tempo in hand, 8 self-damage") is a
held-cost card the planner holds. Each is in the README's known gaps with
what a fix needs. Until the first is closed, a deck built around discards
cannot show a combo here whatever the cards do.

## Not re-run on the audited harness

The items × decks and allocation × sphere matrices from the first Ryan
pass (`ryan_items_x_decks.txt`, `ryan_alloc_x_sphere.txt`) predate the
sphere-grid fix, which changes allocation × sphere most of all. Their
earlier readings (item set the biggest lever, STR winning everywhere)
are withdrawn until re-run.
