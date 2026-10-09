# Enemy Audit — stated vs. actual, spawn coverage, and debuff usage

*Generated 2026-10-08 from `scripts/battle/enemy.gd`, `enemy_spawner.gd`, `dungeon_manager.gd`, `main.gd`,
`effects/debuff.gd`, `effects/debuff_manager.gd` and `docs/STORY.md`. Read-only: nothing was changed to produce it.*

"Stated" means any of: the in-game compendium text (`Enemy.get_all_enemy_data()` → `_specials`), the code
comments beside a stat, or the bestiary entry in STORY.md §5.4. "Actual" is what `initialize()`, the action
table, the chooser and the `_try_*` function do when the enemy acts.

---

## 1. Roster at a glance

Stats are **base → what the player fights** after the level-band scaling (`passive_power_scale(INTENDED_LEVELS[type])`:
HP and armor ×(1 + (band−8)·0.05) clamped 0.9–1.45, damage ×(1 + (band−8)·0.035) clamped 0.9–1.3). "Where it spawns"
is every real spawn site in the game (zone tables, boss rooms, summons). The sandbox / Enemy Lab can place anything,
so they are not counted.

| Enemy | Tier shown | Band | HP/Armor/Dmg (base → fought) | Move (spaces / tempo) | Resist P/F/L % | Habitat | Where it spawns | Status |
|---|---|---|---|---|---|---|---|---|
| Minion | Minion | 1 | 25/0/3 → 23/0/3 | 1 / 5 | - | generic | overworld fallback tiers (W1-3), Rat King's door guard is an ELITE | legacy generic |
| Elite | Elite | 5 | 80/0/6 → 72/0/5 | 0.8 / 6 | - | generic | overworld 'heavy' in World 4+, deep-room guard W3+, sewer door guard | legacy generic |
| Boss | Boss | 10 | 200/0/10 → 220/0/11 | 0.5 / 8 | - | generic | overworld arena rooms (boss_types) | legacy generic |
| Wererat | Minion | 2 | 8/0/3 → 7/0/3 | 1 / 2 (Scurry 5 / 4) | - | Sewer | sewer west rooster, overworld base melee W1-2, Rat King's Lair | built |
| Skeleton | Minion | 7 | 20/12/6 → 19/11/6 | 1 / 5 | - | Graveyard | overworld mid melee W1-2 / base W3+, graveyard shallow, Necromancer summon | built |
| Armored Troll | Elite | 12 | 60/40/7 → 72/48/8 | 2 / 4 | 30/15/15 | Cave | overworld heavy W1-3, cave deep guard | built |
| Archer Rat | Minion | 2 | 6/0/2 → 5/0/2 | 2 / 2 (Shoot 5) | - | Sewer | overworld ranged, sewer, Rat King's Lair (nest archers) | built |
| Hydra | Elite | 14 | 80/0/7 → 104/0/8 | 3 / 6 | - | Forest | ONLY the sandbox test arena (spawn_test_arena) | built, unplaced |
| Fire Goblin Soldier | Minion | 9 | 6/0/2 → 6/0/2 | 4 / 2 | - | Cave | caves (base/mid melee) | built |
| Fire Goblin Mage | Minion | 9 | 10/0/7 → 11/0/7 | 2 / 3 | - | Cave | caves (ranged) | built |
| Fire Goblin Shaman | Elite | 10 | 16/0/6 → 18/0/6 | 2 / 3 | - | Cave | one per cave | built |
| Giant Beaver | Elite | 16 | 60/0/9 → 84/0/12 | 3 / 6 | 25/0/0 | Forest | Greenwood elites | built |
| Mini Bear | Minion | 13 | 14/0/4 → 18/0/5 | 5 / 5 | - | Forest | Greenwood minions | built |
| Large Bear | Elite | 18 | 90/0/12 → 131/0/16 | 6 / 7 | - (30 phys below half) | Forest | Greenwood elites, deep clearing guard | built |
| Wolf | Minion | 14 | 30/0/7 → 39/0/8 | 4 / 3 | - | Forest | Greenwood minions | built |
| Coyote | Minion | 12 | 6/0/2 → 7/0/2 | 4 / 3 | - | Forest | Greenwood minions | built |
| Bugbear | Elite | 17 | 50/0/6 → 73/0/8 | 6 / 4 | - | Forest | Greenwood minion list (despite Elite tier) | built |
| Infected Hunter | Elite | 16 | 40/0/8 → 56/0/10 | 2 / 3 | - | Forest | Greenwood elites | built |
| Giant Hawk | Minion | 15 | 28/0/9 → 38/0/11 | 8 / 3 | - | Forest | Greenwood minions + hills | built |
| Treant | Elite | 19 | 110/0/14 → 160/0/18 | 9 / 10 | 25/-10/55 | Forest | Greenwood elites | built |
| Ice Mage | Minion | 15 | 40/0/6 → 54/0/7 | 3 / 5 | - | Forest | nowhere (no spawn table lists it) | built, unplaced |
| Fire Mage | Minion | 15 | 32/0/7 → 43/0/9 | 2 / 3 | - | Forest | nowhere | built, unplaced |
| Spark Mage | Minion | 13 | 16/0/3 → 20/0/4 | 2 / 3 | - | Forest | nowhere | built, unplaced |
| Air Mage | Minion | 14 | 30/0/5 → 39/0/6 | 6 / 3 | - | Forest | nowhere | built, unplaced |
| Earth Mage | Elite | 17 | 65/0/9 → 94/0/12 | 5 / 5 | - | Forest | nowhere | built, unplaced |
| Zombie | Minion | 7 | 12/0/5 → 11/0/5 | 3 / 8 | - | Graveyard | graveyard shallow + deep, Necromancer summon | built |
| Werewolf | Elite | 10 | 55/0/10 → 61/0/11 | 3 / 3 | 25/25/25 | Graveyard | graveyard deep | built |
| Wererabbit | Minion | 8 | 25/0/0 → 25/0/0 | 2 / 1 | - | Graveyard | graveyard shallow | built |
| Vampire | Elite | 10 | 95/0/10 → 105/0/11 | 5 / 5 | 10/10/10 | Graveyard | graveyard deep | built |
| Necromancer | Elite | 11 | 60/0/4 → 69/0/4 | 8 / 6 | 0/15/15 | Graveyard | graveyard deepest room | built |
| Bone Dragon | Elite | 12 | 150/0/12 → 180/0/14 | 5 / 5 | 45/45/0 | Graveyard | Necromancer's 6th raise; Boneyard boss room | built (boss-room boss shown as Elite) |
| Spirit Collector | Elite | 10 | 50/0/8 → 55/0/9 | 3 / 4 | - | Graveyard | nowhere | built, unplaced |
| Grave Titan | Boss | 12 | 130/30/15 → 156/36/17 | 4 / 8 | - | Graveyard | nowhere (boss loot tier, never spawns) | built, unplaced |
| Crypt Crawler | Minion | 8 | 28/0/6 → 28/0/6 | 3 / 4 | - | Graveyard | graveyard deep | built |
| Screecher | Minion | 8 | 14/0/5 → 14/0/5 | 4 / 2 | - | Graveyard | graveyard shallow | built |
| The Consumed | Elite | 9 | 35/0/8 → 37/0/8 | 5 / 3 | - | Graveyard | nowhere | built, unplaced |
| Sludge Being | Minion | 2 | 10/0/3 → 9/0/3 | 3 / 5 | - | Sewer | sewer west + east | built |
| Pipe Crawler | Minion | 3 | 20/0/5 → 18/0/5 | 2 / 2 | - | Sewer | sewer east | built |
| Sewer Cobra (enum SEWER_CROC) | Elite | 5 | 40/20/12 → 36/18/11 | 2 / 5 | - | Sewer | sewer east, deepest-room guard | built |
| Rat King | Elite | 5 | 90/10/6 → 81/9/5 | 2 / 2 | - | Sewer | Rat King's Lair (boss room 1) | built (mini-boss shown as Elite) |
| Swarm | Minion | 3 | 10/0/3 → 9/0/3 | 8 / 3 | - | Sewer | sewer east, Bone Dragon breath | built |
| Weregoat | Elite | — | — | - | - | Mountains | - | mock-up |
| Wyvern | Elite | 21 | 125/0/25 → 181/0/33 | 6 / 4 | 25/35/25 | Mountains | nowhere (no mountain zone exists) | built, unplaced |
| Roc | Boss | — | — | - | - | Mountains | - | mock-up |
| Ice Troll | Elite | 22 | 150/55/13 → 218/80/17 | 3 / 3 | 35/15/15 | Mountains | nowhere | built, unplaced |
| Snow Wraith | Minion | — | — | - | - | Mountains | - | mock-up |
| Granite Colossus | Boss | — | — | - | - | Mountains | - | mock-up (listed in boss loot tier) |
| White Manticore | Elite | 23 | 75/15/15 → 109/22/20 | 3 / 2 | 10/35/10 | Mountains | nowhere | built, unplaced |
| Sabertooth | Minion | — | — | - | - | Mountains | - | mock-up |
| Cerberus | Boss | 10 | 250/50/25 → 275/55/27 | 6 / 3 | 30/40/15 | Underworld | Hell's Gate (boss room 3) | built |
| Succubus | Elite | — | — | - | - | Underworld | - | mock-up |
| Demon | Elite | — | — | - | - | Underworld | - | mock-up |
| Ifrit | Elite | 28 | 225/0/45 → 326/0/59 | 5 / 4 | 20/15/15 | Underworld | World 2+ overworld deep rooms (deep lords, cycling) | built |
| Mind Eater | Elite | — | — | - | - | Underworld | - | mock-up |
| Specter | Minion | — | — | - | - | Underworld | - | mock-up |
| Magma Spider | Elite | — | — | - | - | Underworld | - | mock-up |
| Pit Fiend | Boss | — | — | - | - | Underworld | - | mock-up |
| Ash Harpy | Minion | — | — | - | - | Underworld | - | mock-up |
| Inflamed Minotaur | Boss | 9 | 350/100/35 → 368/105/36 | 6 / 5 | 15/50/25 | Underworld | the Labyrinth (boss room 4); ALSO World 2+ overworld deep rooms (deep lords) | built |
| Cherub | Minion | — | — | - | - | Heavens | - | mock-up |
| Djinn | Elite | 35 | 180/0/35 → 261/0/46 | 8 / 3 | 15/15/15 | Heavens | World 2+ overworld deep rooms (deep lords) | built |
| Corrupted Archangel | Boss | — | — | - | - | Heavens | - | mock-up |
| Ring Wraith | Elite | — | 100/0/15 → 100/0/15 | 5 / 4 | - | (The Precious) | ring shadow-world summon | built |
| Training Dummy | Minion | — | 500/0/0 → 500/0/0 | - | - | Dojo | dojo | structure-like |
| Rat Nest | Minion | — | 15/0/0 → 15/0/0 | - | - | Sewer | Rat King's Lair | structure |
| Gravestone | Minion | — | 10/0/0 → 10/0/0 | - | - | Graveyard | Boneyard | structure |
| Grave Digger | Minion | 8 | 20/0/0 → 20/0/0 | 2 / 2 | - | Graveyard | Boneyard (3, one at a time) | built |
| Hell's Door | Minion | — | 150/0/0 → 150/0/0 | - | - | Underworld | Hell's Gate | structure |

**Totals.** 68 enum values: 47 with a stat block and actions (the Ring Wraith and the Grave Digger among them),
14 design mock-ups with no arm (they spawn as an idle grey box with a warning), 3 structures, the dojo dummy, and
3 legacy generics (Minion / Elite / Boss boxes that still fill overworld tables and the sewer door guard). Of the
47, 45 are fighting enemies (the Digger never fights; the Ring Wraith is a generic attacker).

**Built but unreachable in normal play (13):** Hydra (test arena only), the five Elemental Mages, Spirit Collector,
Grave Titan, The Consumed, Wyvern, Ice Troll, White Manticore. There is no Mountains zone at all, and the graveyard
tables never pull Spirit Collector / Grave Titan / Consumed. Everything in this list has finished behaviour and a
hand-built figure; it just needs a spawn table.

**Tier labels that disagree with the role.** Rat King is a boss-room boss with boss loot but displays "Elite".
Bone Dragon is the Boneyard's boss and displays "Elite" (the sheet's call, noted in code). Grave Titan and
Granite Colossus display "Boss" and roll boss loot but neither ever spawns (Colossus is a mock-up). Bugbear
displays "Elite" but sits in the forest **minion** pool and STORY.md calls it a Minion. Hydra rolls boss loot
but displays "Elite". Cerberus is not in any loot tier list and falls to the default mid tier.

---

## 2. Stated vs. actual — per enemy

Only enemies with a gap, a soft spot, or something worth knowing are listed. Everything not listed here matched
its description and its STORY.md line on every point I could check (numbers, tempo costs, ranges, debuffs, passives).

### Sewer
- **Wererat / Archer Rat / Sludge / Pipe Crawler / Sewer Cobra / Swarm / Rat King** — match. Notes: the Sewer Cobra
  is still `EnemyType.SEWER_CROC` in code and its description calls it an "ambush predator" with no ambush
  mechanic (it walks and bites). Pipe Crawler's 25 % Disarm (5 tempo) is the only Disarm any enemy applies.
- **Rat King** — matches the lair design (nests at 50/30/30 %, feeds 20/30/50 %). His own kit is just Bite 6: no
  signature debuff.

### Cave
- **Armored Troll** — matches (Smash 14 + *Lightly Dazed* card, Kick 6, regen 3 per 6 tempo, 30/15/15).
- **Fire Goblin Soldier / Mage / Shaman** — match. Shaman's Fire Wall is the game's only **Channel** action and
  the only tagged action keyword in the whole roster (no enemy uses Async or Trigger yet, though the framework and
  `docs/ENEMY_ACTION_KEYWORDS.md` exist).

### Forest
- **Giant Beaver** — matches (Chomp 9 + Stun 3, then Tail Whip 6 + 5 Vulnerable 2 tempo later).
- **Mini Bear** — code and compendium: **+2** attack per packmate hurt (cumulative, never decays). STORY.md says +1.
- **Large Bear** — matches the long description. The "heals from bleed damage" only applies **below half** (the rage
  state), which the compendium implies but STORY.md states unconditionally.
- **Coyote** — code 6 HP / 2 dmg; STORY.md says 5 HP / 1 dmg.
- **Bugbear** — First Strike is **+8** in code and compendium; STORY.md says +5. Tier mismatch noted above.
- **Infected Hunter** — three gaps. (1) The stat comment says *"AOE swipe in front"* and STORY.md says *"AOE
  Cleave"*, but Cleave is a single-target `_try_elemental` hit. (2) STORY.md says Hook *"reels the player in over
  2 tempo"*; the reel is instant on resolve. (3) Hook is described as "starts charged" and `_hook_charged` is read
  by the chooser, but I found nothing that ever sets it back to false or recharges it: as written the hook is
  always available whenever the player is 2–7 tiles away (8-tempo action, no cooldown).
- **Giant Hawk** — code and compendium: 20 % Blind for 5 tempo; STORY.md says 15 %.
- **Treant** — matches (Root = Rooted 8 tempo, attack allowed / no movement; thorn strip every 10 tempo; heal
  5 +2 per 10 % under 60 %).
- **Elemental Mages** — Ice applies **1** Slow stack (one tile at 3 tempo), Fire 2 Burn, Spark 1 Shock, Air nothing,
  Earth +4 armor per hit. STORY.md says Earth gains **3** armor. None of the five is in any spawn table.
- **Hydra** — matches; only exists in the test arena.

### Graveyard
- **Zombie / Skeleton** — generic attack + move, no identity beyond stats.
- **Werewolf** — matches (+3 vs armor, rake on a debuffed target, 5/4/3 ramp on the same target).
- **Vampire** — matches (life steal on health damage only; Bat Form ×2 below half; Absorb 20 then 10 on the
  healthiest unit, player included).
- **Necromancer** — matches except one wording: Hex is described *"until played"*, but the Hex debuff is created with
  a **25-tempo duration**, so it also expires on its own. Summons are the first-pass skeleton/zombie coin flip.
- **Bone Dragon** — matches. The description promises "12 damage down a 6-tile line": the line is the 6 cells
  straight out along the dominant direction, no width.
- **Spirit Collector** — matches (Release Soul card). Never spawns.
- **Grave Titan** — description says *"15 damage in front"* for Smash; it is single target. Never spawns.
- **Crypt Crawler** — matches (web after 3 consecutive bites, reach 2, Paralysis card).
- **Screecher** — the stat comment says *"4 spaces / 2 tempo while invisible"* but there is no invisibility state;
  it is simply always a 2-tempo mover. The "seen only from its noise" idea lives in the figure (half-transparent
  sprite, flashes on attack), not in gameplay.
- **The Consumed** — matches (Death Burst 8 to everything within 1.9, enemies included). Never spawns.
- **Wererabbit** — matches (flees 15 tempo, vanishes, no loot on vanish).

### Mountains (no zone exists yet)
- **Wyvern** — matches. Talon Grab cooldown is set to 10 after the 8-tempo action; the text says "then 2-cycle
  cooldown", which reads as 10 after the action, so fine.
- **Ice Troll** — matches (Cold + Brittle per hit, Clobber 50 the moment a hit freezes). Note the player-side Cold it
  applies has a 15-tempo clock, so a slow fight thaws before 5 stacks; at Club's 4-tempo cadence it freezes on the
  fifth hit.
- **White Manticore** — matches (Stinger 25 + 3 Clumsy stacks + 8 Poison, 5-tempo cooldown).

### Underworld / Heavens
- **Cerberus** — matches the sheet and the test. Not in any loot tier (defaults to mid-tier drops for a boss).
- **Ifrit** — matches (Attack 45 at 3 tempo is as the sheet; Fire Breath 20 + 5 Burn in a 5×5, lingers 3 tempo;
  Backflip on a single blow over 40).
- **Inflamed Minotaur** — matches after this week's work (cumulative-20 leap, real maze routing, boss tier).
  He also spawns as a wild "deep lord" in World 2+ overworld deep rooms, where the Labyrinth's curse does not apply.
- **Djinn** — matches (Chain Lightning 35, cast 5 / arc 4; 3 Wishes per attack). Spawns only as a wild deep lord.

### Generic / structures
- **Minion / Elite / Boss** boxes still carry real duty: Elite is the Rat King's door guard and the World 4+
  overworld heavy; Boss sits in overworld arena rooms. They have no art and no abilities.
- **Hell's Door / Gravestone / Rat Nest / Grave Digger** — match their room designs.

---

## 3. Debuff audit — what the player can receive (`Debuff.DebuffType`)

30 enum values. Counts are **application sites in code** (places that create the debuff on a player-side unit),
not play-time frequency. "Mechanic" says whether the debuff actually does something once applied.

| Debuff | Applied by enemies (sites) | Applied by other sources (sites) | Mechanic implemented? |
|---|---|---|---|
| BURN | Fire Goblin Mage Ember (1), Fire Mage bolt (2), Minotaur attack (2), Ifrit breath (5), fire-wall traps: Shaman wall 3 / Ifrit lingering 5 / Minotaur wake 2 — **4 enemy sites + fire walls** | Phoenix item backlash on self (1), on-self item rider (1) | yes — doubles per cycle, also fires on attack |
| BLEED | Large Bear Maul 4 (8 enraged), Cerberus second head 5, Cerberus Swipe 8 — **3** | on-self item rider (1) | yes — 1 per tile moved |
| STUN | Giant Beaver Chomp 3t, Cerberus Venom Tail 15t, Minotaur Bull Rush 5t (chance) — **3** | Stone Encase self 5t, Cryonics self 15t | yes |
| VULNERABLE | Beaver Tail Whip 5, Large Bear Roar 1 (area), Cerberus venom aftermath 2, Minotaur rush 1 (+ trampled) — **4 (5 sites)** | a card on self (1) | yes — +30 % per hit, 1 stack per hit |
| SHOCKED | Spark Mage 1 — **1** | — | yes — arcs to allies within 2 tiles (co-op/summons only; in solo it does nothing) |
| SLOWED | Ice Mage 1 stack — **1** | Spiked Web trap 2, Approach (self, timed), a card rider | yes |
| POISON | White Manticore 8 — **1** | — | yes |
| CLUMSY | White Manticore 3 stacks — **1** | — | yes |
| COLD | Ice Troll 1 per hit — **1** | on-self item rider (1) | yes — Frozen at 5 |
| BRITTLE | Ice Troll 1 per hit — **1** | — | yes — +2 armor decay |
| BLIND | Giant Hawk 20 % / 5t — **1** | — | yes — 80 % miss on attacks |
| ROOTED | Treant Root 8t — **1** | — | yes |
| DISARM | Pipe Crawler 25 % / 5t — **1** | Succumb self, one card self | yes |
| HEXED | Necromancer Bolt ×2 — **1 (2 hexes)** | — | yes |
| CUFFED | Cerberus venom aftermath 10t — **1** | Succumb self | yes (tempo + brain draws only) |
| WEAKENED | Minotaur Bull Rush (on the stun roll) — **1** | — | yes |
| LOST | the Labyrinth room (every 25 tempo) — **1** | — | yes (new) |
| FROZEN | no direct applier; only via Cold reaching 5 (Ice Troll) | — | yes |
| DRAIN | **none** | Succumb self only | yes |
| STAGGERED | **none** | Tower Shield self (timed) only | yes |
| GENERIC | **none** | Marvolo's Misunderstanding item | n/a |
| SILENCE | **none** — no enemy silences the player | none | yes (blocks spell cards) |
| CURSED | **none** on the player | none | yes (−20 % dealt, 20 % self-damage) |
| WEIGHTED | **none** | none | yes (+2 tempo per card) — fully built, never applied |
| LOCKED | **none** | none | yes (card UI, deck assignment, highlight skipping all exist) — fully built, never applied |
| INEBRIATE / TETHERED / MAGNETIZED / LINKED | retired slots | — | no (enum placeholders) |

**Never used on the player by anything:** Silence, Cursed, Weighted, Locked (plus the four retired slots).
**Used only by the player on themself:** Drain, Staggered. **Carried by exactly one enemy:** Shocked, Slowed,
Poison, Clumsy, Cold, Brittle, Blind, Rooted, Disarm, Hexed, Cuffed, Weakened, Lost. **Spread across several
enemies:** Burn (5, counting the Shaman's fire wall), Vulnerable (4), Stun (3), Bleed (3).

**Card-injection "debuffs"** (not Debuff types, but the same design slot): *Lightly Dazed* (Troll Smash),
*Paralysis* (Crypt Crawler web), *Release Soul* (Spirit Collector), *Wishes* (Djinn). All four cards exist.

Only 16 of the 45 built fighting enemies apply any status to the player at all; of the other 29, four inject a
card instead (Troll, Crypt Crawler, Spirit Collector, Djinn) and 25 are damage and movement only. By habitat the
status-appliers are Sewer 1 of 7 (Pipe Crawler), Cave 2 of 4 (Goblin Mage, Shaman), Forest 7 of 15 (Beaver, Large
Bear, Hawk, Treant, Ice / Fire / Spark Mage), Graveyard 1 of 12 (Necromancer), Mountains 2 of 3 (Ice Troll,
Manticore), Underworld 3 of 3, Heavens 0 of 1 (the Djinn's Wishes are a card, not a status).

---

## 4. Debuff audit — what enemies can receive (`Enemy.apply_debuff` keys)

21 enemy-side keys. Counts are literal `apply_debuff("key", n)` sites in cards, items, passives and main
(29 in card.gd, 20 in main.gd, 5 in progression_triggers.gd, 3 in inventory.gd), plus 6 dynamic sites that pass
a variable key (Feral Evocation's element remap, sword slot pairs, Laced Arrow, Misery's spread, Cory's Wither,
and the player→enemy mirror table).

| Enemy-side key | Literal sites | Note |
|---|---|---|
| weaken | 12 | most-used enemy debuff |
| vulnerable | 7 | |
| poison | 5 | |
| bleed | 5 | ticks per tile the enemy moves |
| burn | 4 | doubling tick |
| shock | 3 | ticks stacks per cycle; Element Pollination adds the 5-stack stun |
| root | 3 | |
| disarm_attacks | 3 | per-attack disarm (Switch Kick) |
| cold | 3 | Frozen at 5 |
| stun | 2 (+2 via `apply_stun`) | |
| slow | 2 | each move +2 tempo and eats a stack |
| disarmed | 2 | timed disarm |
| trip | 1 | movement −4 |
| silenced | 1 | |
| polymorph | 1 | Circe's Wand |
| narashimha | 1 | heal cap |
| marked | 1 | +15 % taken |
| choke_dot | 1 | |
| cursed | 0 literal | only reachable through the player→enemy mirror map (Misery / Wither) |
| taunt / fear / wear down / phys-defense / cupid mark | 4 / 1 / 1 / 1 / 2 (own entry points) | |
| knockback | 7 (+1 `knock_dir`) | not a status, but the most common forced move |

Everything the enemy side can hold is reachable from at least one card except **cursed**, which no card applies
directly. Note the asymmetry with Section 3: the player can inflict Silence, Cursed, Mark, Trip, Choke, Polymorph
and Taunt on enemies, but no enemy inflicts Silence, Cursed, a mark, a trip or anything mana-related on the player.

---

## 5. Openings this leaves (for the next pass — no changes made)

These are the gaps the data points at, not decisions:

1. **Four player debuffs are built and never applied: Silence, Cursed, Weighted, Locked.** Locked in particular has
   card-UI greying, deck assignment and stack-representative logic all wired up with no caster. Any of the Graveyard
   casters (Necromancer's second spell, a Wight/Ghoul) or the Underworld mock-ups (Succubus, Mind Eater, Specter)
   are natural homes; Weighted and Locked read like Mind Eater / Specter effects, Cursed like a Succubus or
   Pit Fiend, Silence like a Cherub or Corrupted Archangel.
2. **Drain and Staggered only hurt the player when they do it to themselves.** No enemy touches mana at all.
3. **Thirteen finished enemies have no spawn table** (Section 1). The five Elemental Mages and the three Mountains
   elites are the biggest unused pool of status effects (Slow, Burn, Shock, Cold, Brittle, Poison, Clumsy, Frozen).
4. **Graveyard is debuff-poor relative to its size**: 12 built enemies and only the Necromancer's Hex is a status;
   Crypt Crawler and Spirit Collector inject cards; Zombie, Skeleton, Screecher, Vampire, Werewolf, Bone Dragon,
   Grave Titan, Consumed and Wererabbit are raw damage (or none).
5. **Sewer has one status in seven enemies** (Pipe Crawler's 25 % Disarm). The Rat King has no signature effect.
6. **Only one action keyword is in use** (the Shaman's Channel). Async and Trigger actions exist in the framework
   and the doc but no enemy has one.
7. **Text drift to settle** (either side could be the intended one): Mini Bear +1 vs +2, Bugbear +5 vs +8 and
   Minion vs Elite, Coyote 5/1 vs 6/2, Giant Hawk 15 % vs 20 %, Earth Mage +3 vs +4 armor, Infected Hunter's
   "AOE" cleave and "over 2 tempo" hook, Necromancer's "until played" Hex, Screecher's non-existent invisibility,
   Grave Titan's "in front" smash, Sewer Cobra's "ambush".
8. **Infected Hunter's hook has no recharge path** in code: it is always ready. If the design wants it to recharge,
   that is a bug; if it was meant to be always-on, the "starts charged" wording is misleading.
9. **Loot tiers**: Cerberus falls to the default tier; Rat King / Bone Dragon / Hydra tier labels and loot do not
   agree with each other or with their rooms.
