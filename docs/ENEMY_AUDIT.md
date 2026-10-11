# Enemy Audit — stated vs. actual, spawn coverage, and debuff usage

*Section 0 is the **2026-10-11 sheet pass**: the designer's enemy sheet (`docs/ENEMY_SHEET.tsv`) checked against the
code, with everything that was changed to match it and every question it leaves open. Sections 1–5 are the
2026-10-08 read-only audit and are kept for reference; where they disagree with Section 0, Section 0 is current.*

---

## 0. Sheet pass — 2026-10-11

The sheet row is the source of truth. "Match" means the code already did what the row says; "Changed" means the
code was altered in this pass to match; "Built" means the enemy or action did not exist before this pass;
"Open" means the sheet leaves something an implementer had to decide (the decision is marked `# sheet:` or
`TODO(sheet)` in code and listed under *Assumptions* below). Tests for this pass: `tests/test_enemy_sheet_pass.gd`,
`test_sheet_mountains.gd`, `test_sheet_underworld.gd`, `test_sheet_act1a.gd`, `test_sheet_act1b.gd`.

### 0.1 Rules that apply to every row

- **Level column ≠ level band.** The sheet's *Level* (1–10) is a difficulty rating; the code's `INTENDED_LEVELS`
  band is the *player* level the enemy is tuned for (Sewer 1–5 … Forest 12–20, Mountains 20+). The band drives XP
  falloff **and** the HP/damage scaling (`passive_power_scale`). Setting bands to the sheet's levels would clamp
  nearly every enemy to ×0.9 and start XP falloff at player level ~5, so the bands were **left alone**. Cerberus
  and the Minotaur already use their sheet level as band; new enemies were banded by zone (Snow Wraith 20,
  Sabertooth 21, Roc / Weregoat 22, Granite Colossus 25, Magma Spider / Specter / Ash Harpy 26, Succubus / Mind
  Eater 27, Demon 28, Cherub 33). Every "fought" number below is the sheet's base × that band's multiplier.
- **Tier vocabulary (Changed).** The compendium now uses the sheet's words exactly — Trash / Mid-tier / Elite /
  Boss, plus Special for the Ring Wraith, the dummy and the structures — and the loot map (`get_loot_tier`) follows
  the same column: Trash→TRASH, Mid-tier→MID, Elite→ELITE, Boss→BOSS. Consequences: Bugbear, Infected Hunter,
  Earth Mage, Spirit Collector, The Consumed, Sewer Cobra and Fire Goblin Shaman drop *mid* loot instead of elite;
  Mini Bear and Fire Goblin Soldier drop trash; Hydra drops elite instead of boss; Rat King and **Bone Dragon**
  drop boss loot. The Bone Dragon used to be held at elite because the Necromancer can raise one after five of its
  summons die — a boss drop there is farmable in the deep graveyard rooms. Followed the sheet; flagging it.
- **Async on the sheet is real Async in code** (`docs/ENEMY_ACTION_KEYWORDS.md`): the action runs its own clock,
  and a Sync action may only *start* while no Async clock is mid-count. Consequences worth a designer look:
  - Cerberus: Bite (5) and Venom Tail (15) are now Async; Swipe / Roar / Move share the Sync clock and can only
    start right after a Bite fires. Venom Tail recurs every 15 tempo while in reach, so stun → aftermath → next
    tail can chain.
  - Sewer Cobra: Venom Spray (15, Async) means Bite (6) and Move (5) can each start only once per spray cycle.
  - Roc: Eye Scrape (3, Async) is always counting, so the 1-tempo retreat can only start every 3rd tempo — the
    Roc effectively moves one square per 3 tempo, not per tempo.
  - Sabertooth: Track (10) and Sunken Bite (15) are Async; Bite and Claw (5) waits for both gaps.
  - Demon: Mimic and Cuff (both 8, Async) line up, so Attack (5) starts every 8 tempo.
- **Distance is Manhattan** on the grid; "radius N" was read as Manhattan N everywhere new.
- **Blank resist cells** were read as 0.

### 0.2 Per enemy

| Enemy | Sheet row | Status | What changed / what is open |
|---|---|---|---|
| Cerberus | Boss 10 | Changed | Bite + Venom Tail flagged Async; Venom aftermath (2 Vulnerable, Cuffed 10) now lands the moment the Stun is gone (15 tempo stays the upper bound). Everything else matched (three heads, Swipe 8 Bleed, Roar +25/+25, Guardian of Death incl. re-trigger on heal-and-drop, Deathyard Dog +15). Note: Guardian also counts his allies' drops (incl. Hell's Door); the "life steal" head heals the pre-mitigation 25. |
| Corrupted Archangel / Pit Fiend / Hades | Boss, TBD | Mock-up | Stats TBD on the sheet; untouched. Hallucination cards not built. |
| Granite Colossus | Boss 8 | Built (stats) | 350 HP / 250 armor / 3 sp per 5 tempo / 65-50-50 set; actions are "TBD" on the sheet, so it stands. |
| Rat King | Boss 9 | Changed + Built | Tier Boss. **Infest** built: 5-tempo action, one Infest card per living Wererat / Archer Rat / himself within 10; the card is 50 mana / 0 tempo, erases on play, and if held 5 tempo hatches 2 Wererats beside the player; discarding it erases it (no hatch). Open: selection rule (used when not adjacent and no Infest is already in hand). Nest flight unchanged. |
| Bone Dragon | Boss 10 | Changed (tier) | Display + loot Boss (see farm note). Bite 12 / Breath Swarm match. Open: Breath is an 8-direction line (a target off-axis is missed). |
| Inflamed Minotaur | Boss 9 | Match | Leap on cumulative 20, −1 space per Slow, Bull Rush numbers, fire wake heals 10. Open: sheet says Bull Rush "1 cycle after landing"; code waits a random 5–15 tempo (STORY.md agrees with the code). |
| Hydra | Elite 8 | Changed | HP 80→190, resists 25/25/25 added, +2 strength now on **any** damage source (was player hits only). Heal still gated to ≤50% HP after the 4th hit. |
| Grave Titan | Elite 10 | Changed (tier) | Display/loot Elite. Open: "15 dmg in front" is single-target in code. Never spawns. |
| Armored Troll | Elite 7 | Match | Kick 6 / Smash 14 + Lightly Dazed / regen 3 per 6 / 60-40 split. |
| Djinn | Elite 7 | Match (mostly) | Chain Lightning 35, cast 5 / arc 4. Wishes: 3 per **hit** (a multi-hit card gives 3 per hit), each 1/3 of that hit, 60 mana / 0 tempo, sears on the global 5-tempo cycle. Open: "per attack" vs per hit; wishes always go to player 1. |
| Giant Beaver | Elite 7 | Match | Chomp 9 + Stun 3, Tail Whip 6 + Vulnerable (5 stacks, 15t) as a forced follow-up. |
| Ice Troll | Elite 7 | Match | Club 13, Cold + Brittle per hit, Clobber 50 auto on freeze. Open: the sheet's "10" tempo on Clobber (it is instant). |
| Ifrit | Elite 8 | Match (mostly) | Attack 45, Breath 20 + 5 Burn in a 5×5 lingering 3, Backflip over 40. Open: "the breath continues for 6 tempo" — code is one instant hit; left as is pending a ruling (a 6-tempo Channel? tiles that burn each tempo?). |
| Large Bear | Elite 7 | Match | Maul 12 + 4 Bleed, Roar Vulnerable within 4 (1 stack, 15t, 15-tempo cooldown), permanent 30% physical below half, rage ×1.5 / double bleed / heals from bleed, +1 Strengthen per hit with Mini Bears present. |
| Necromancer | Elite 8 | Match | Bolt 4 + 2 Hexes of 30 (also expire after 25 tempo), Summon 8 (skeleton/zombie coin flip, cap 3), Bone Dragon on the 5th summon death. Summon roster still owed by the designer. |
| Treant | Elite 8 | Match | Slam 14 earth, Root 8 (range 4), heal 5 per 5 tempo (+2 per 10% under 60%), thorn strip every 10. The stray "5" in the sheet's Tempo 3 cell is the Heal action. |
| Vampire | Elite 8 | Match | Bite 10 heals health damage only; Bat Form is an instant reaction below 50% (2 charges); Absorb 20 then 10 on the healthiest unit. Open: a second Bat Form during the first Absorb's wind-up loses the 20. |
| Werewolf | Elite 7 | Changed | First claw on a **new** target now costs the full 5 (streak resets when the target changes). +3 vs armor, rake on a debuffed target match. |
| White Manticore | Elite 8 | Changed | Stinger's Clumsy is now clock-timed for 3 cycles (15 tempo) as written, not 3 stacks. Bite 15, Stinger 25 + 8 Poison, 5-tempo cooldown match. |
| Wyvern | Elite 7 | Match | Bite 25, Talon Grab 25 + drag 8 squares, 10-tempo cooldown read as "2 cycles". |
| Spirit Collector | Mid-tier 5 | Changed | Tier Mid-tier. Release Soul now costs 15 mana / 2 tempo, gives every living Spirit Collector +5 Strengthen when played (their Strike / Collect Soul add it), and holds **Drain** (1 stack, re-applied each cycle) while it is in the hand. Held sap stays 5 per cycle (= 1 per tempo). Open: Strengthen amount (5). |
| Air / Earth / Fire / Ice / Spark Mage | Mid-tier | Match | Numbers match. Earth Mage and the others never appear in a spawn table. Earth Mage tier → Mid-tier. |
| Bugbear | Mid-tier 5 | Changed (tier) | Mid-tier (was Elite). First Strike +8 matches. |
| Crypt Crawler | Mid-tier 5 | Changed | Paralysis card is 10 mana / 5 tempo (was 0 / 1). Web after 3 bites matches. |
| Demon | Mid-tier 6 | Built | Mimic (Async 8): a 1-HP Demon copy with mirrored name / health / statuses that hits as hard; cap 2 per demon, no XP or loot, collapses when the original dies. Cuff (Async 8, Cuffed 15). Attack 8. |
| Fire Goblin Mage / Shaman / Soldier | Mid / Mid / Trash | Match | Shaman's Fire Wall keeps its Channel 4 / Disruptable 8 tags (not on the sheet). Soldier loot → trash. |
| Giant Hawk | Mid-tier 5 | Match | Swoop 9 (reach 2), 20% Blind 5t, flier. |
| Infected Hunter | Mid-tier 5 | Changed + Built | Cleave now hits the three squares in front (adjacent cell toward the target + the two beside it). **Net Throw** built: 2 tempo, 8-tempo cooldown, applies Weighted with one stack per card in the hand (+2 tempo per card until that many cards are played). Hook: starts charged, then recharges 8 tempo after each pull. Open: Net Throw range (3). |
| Roc | Mid-tier 6 | Built | Dive Bomb from ≤6 squares, lands beside the target, 5-tempo cooldown; Eye Scrape (Async 3) 2 Weakened after >3 tempo adjacent; always retreats otherwise. Open: the sheet gives Dive Bomb **no damage** — 8 used. |
| Sabertooth Tiger | Mid-tier 6 | Built | Track (Async 10) +15 Strengthen and a hunt lock on the nearest unit; Bite 6 then Claw 3 as two separate attacks; Sunken Bite (Async 15) 10 + 8 Bleed; 35% crit ×1.5 + 6 Bleed on every strike. |
| Sewer Cobra | Mid-tier 5 | Changed + Built | Tier Mid-tier. **Venom Spray** (Async 15): forward cone widths 1-3-3-3-5 out to 5; 8 Poison to every unit inside; 10 damage only to armored units. Passives built: 3 Poison back on any direct hit that reaches its health; a flat 5 thorns per direct hit while it has armor; on exposure Stun 3 and a full clock reset. Open: the cone's exact shape ("1 square in front to 4 at range 5" has no even-width answer on a grid). |
| Skeleton / Zombie / Swarm / Sludge / Pipe Crawler / Archer Rat / Coyote / Mini Bear / Wolf / Consumed / Wererabbit | Trash / Mid | Match | Numbers and kits match; only tier words changed. |
| Screecher | Trash 1 | Built | Invisible until it strikes (cannot be attacked directly; poison, burn and area damage still land), seen for 3 tempo after a Screech, Drift 4 sp / 2 tempo unseen and 2 sp / 5 tempo seen. |
| Snow Wraith | Trash 3 | Built | Snowball (8): Slowed 3 tempo + 2 Cold; Ice Blast: 5 ice +3 vs armor, Slowed 3 tempo. Open: Ice Blast has no tempo on the sheet (5 used) and no range (5 used). |
| Specter | Trash 1 | Built | Spirit Spit 2 at range 2; Invisible (Async 8) hides it 3 tempo. |
| Succubus | Trash 4 | Built | Mana Drain −10; Damaging Snap = missing mana / 20 + 4. Open: no range on the sheet (4 used). |
| Ash Harpy | Trash 1 | Built | Peck 3; Card Steal once per harpy: flies in from 4, takes a random card out of the hand (not a discard), returns it on death / despawn / save. |
| Cherub | Trash 4 | Built | Love's Arrow 2 and the Cherub cannot be attacked directly for 5 tempo; the first arrow flies the moment a unit enters range 4, then it is a 10-tempo clock. |
| Magma Spider | Trash 1 | Built | Fire Web: the 3×3 around the spider; inside it the player is Slowed and takes 1 fire damage every 3 tempo; lasts while the spider lives. Open: size, duration and the cast tempo (8) are all unstated on the sheet. |
| Mind Eater | Trash 3 | Built | Mind Slow (10): every card in the hand costs +20 mana until played (one Hex per card); Manipulate Mind Space (8): Cuffed 15. Open: range (6). |
| Wererat | Trash 1 | Open | Sheet: Scurry "dashes away (at range ≥6)"; code dashes 5 tiles **toward** you at range ≥6 (its compendium text says so too). Left as is — fleeing from a target already 6 away reads as a typo. |
| Ring Wraith | Special | Match | 15 damage / 2 tempo, ignores invisibility and shadow form, 0 XP; "resummons" = comes back fresh at the next shadow form, not during the same one. |

### 0.3 Assumptions made in this pass (all marked in code)

- Weregoat Charge: lanes are the 8 straight directions, up to 8 squares, stopping short of walls and other
  enemies; the lane with the most player-side units wins (ties: more units stunned at the landing, then the goat's
  own target); landing stun 3 tempo; 8 damage is flat (no band scaling), like the rest of the second-pass hits.
- Roc: Dive Bomb 8 damage, 5-tempo cooldown; a cornered Roc holds still rather than approach.
- Sabertooth: a player Taunt still overrides the Track lock.
- Snow Wraith: range 5; Ice Blast 5 tempo.
- Demon mimics copy statuses once at creation and then evolve on their own; only health/armor keep mirroring.
- Ash Harpy with an empty hand pecks and keeps its steal.
- Magma Spider web 3×3, one per spider, recast refreshes, dies with the spider; Silence blocks the cast.
- Mind Eater Mind Slow needs range 6 and not Silenced.
- Cherub: every arrow (not only the first) hides it for 5 tempo.
- Rat King Infest: used when the player is not adjacent and no Infest is in the hand; a discarded Infest is erased,
  never banked in the discard pile; the hatch is bound to the room's spawner, so a brood outlives a slain king.
- Sewer Cobra: all its new numbers (8 / 10 / 5 / 3 / 3) are flat; thorns are judged on armor *before* the hit, so
  the breaking blow still pays 5; the attacker is `main.player` (co-op P2 hits are answered on P1).
- Infected Hunter: Net Throw within 3 squares; "entire hand" = one Weighted stack per card at throw time; Cleave on a
  diagonal target uses the dominant axis as "front".
- Spirit Collector: Release Soul Strengthen +5; Drain held at 1 stack (10 mana per cycle) only for the player
  holding the card.
- Hydra: "every time she is hit" = any damage > 0, DoT ticks included.
- "Hidden" enemies (Specter, Cherub, Screecher): any radius / line / cone sweep counts as area and still lands;
  single-target cards built on a radius query (Flash Cut, Volatile Mixture) can therefore still strike one.

### 0.4 Questions for the designer

1. The **Level column vs the level band** (0.1): keep the bands as player-level pacing, or should the sheet's
   1–10 become the band and the scaling be re-tuned?
2. **Async consequences** (0.1): Cerberus's Swipe/Roar starving, the Cobra's once-per-15 Bite, the Roc crawling at
   1 square per 3 tempo, the Demon's 8-tempo Attack. Intended, or should some of these be Sync?
3. **Bone Dragon boss loot** via the Necromancer's raise (farmable).
4. Numbers the sheet leaves blank: Roc Dive Bomb damage; Snow Wraith Ice Blast tempo and range; Magma Spider web
   size / duration / cast tempo; Succubus and Mind Eater ranges; Net Throw range; Release Soul Strengthen amount;
   Weregoat landing-stun length; Rat King Infest selection rule.
5. Ifrit "breath continues for 6 tempo"; Minotaur Bull Rush "1 cycle after landing" vs the code's 5–15; Ice Troll
   Clobber "10"; Wererat Scurry "away"; Grave Titan Smash "in front"; Djinn wishes per attack vs per hit.
6. Necromancer summon roster (the sheet says it is still owed).
7. Spawn tables: no Mountains, Underworld or Heavens zone exists yet, so every new enemy (and the Elemental Mages,
   Grave Titan, Spirit Collector, The Consumed, Hydra) is reachable only through the Enemy Lab / sandbox and the
   World 2+ "deep lord" rooms (Ifrit, Minotaur, Djinn).

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
