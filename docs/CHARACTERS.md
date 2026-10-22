# Character Playstyle Write-Ups

Every character starts from the exact same place: the same stat pool, the same 5-card basic
deck (Slash, Exposing Strike, Block, Braced Draw, Heal — `BASIC_DECK_IDS` in
`deck_manager.gd`), the same hand size, and **no equipment**. There are no per-character
starter decks and no card is locked to a character. What separates the five is their
**built-in passives**: the character passive and slot specialty from `character_data.gd`, and
the twelve skill-tree passives from `skill_tree_data.gd`, spread across four archetype lanes.

These write-ups describe only what those passives reward. They do not name cards, because any
card one character can obtain, any character can use. Numbers are given as rank 1 → rank 15.

---

## Ryan — a hand that never sits still

**Character passive:** belt cards cost 1 less mana. **Slot specialty:** 2 belt slots.

**Lanes:** Relentless Blade (constant pressure, a thousand cuts), Light Foot (always aware,
every move planned), Apothecary (potions and ailments nobody can predict), Shadow Blade
(weaving in and out, striking where the enemy is weakest).

Ryan's passives reward motion in three senses: cards moving, Ryan moving, and the fight
opening on his terms.

- **Cards moving.** Discarding is fuel, not waste: every 18→4 discards shave 3 tempo off a
  random card in hand (*Keep Them Guessing*), and every card that reaches the discard pile
  *without* being played last cycle adds +1→6 damage to his first attack this cycle
  (*Ladder Work*, which also grants +1→8 dexterity and +1→15 agility). Holding a hand with no
  Defense cards turns every offensive card into a draw on a 15→8 tempo cooldown
  (*Nimble Assault*), and the most recently drawn card, if it is an attack, is discounted
  -10→-75 mana until anything is played (*From the Hip*). Instants played from hand grant 2→16
  armor (*Quick Step*).
- **Ryan moving.** Every cycle he gains armor and deals damage to the nearest enemy equal to
  the spaces he moved, divided by 8→1 (*Let's Dance*). Any displacement — blinking, being
  swapped, any non-standard movement — makes him invisible for 5 tempo (*Now You See Me*,
  15→1 tempo cooldown), and every 15th→1st critical strike does the same (*Eye Scrape*).
- **Opening on his terms.** His first strike on an enemy deals +1→8, another +1→15 if they
  have no armor, and another +3→17 if he is the first thing to damage them (*Surprise
  Opener*) — up to +40 for a clean max-rank ambush out of invisibility.

The Apothecary lane turns his pocket into a toolkit: healing with a Pocket card draws the
healed character a card (*Stimulant*), re-poisoning an already poisoned enemy deals a third
of their poison stacks as burst (*Pop Rocks*), and the last card played changes what his
potions do — regen, Strengthen, extra poison stacks or a physical-defense cut depending on
whether a utility, attack or defense came before (*Mad Scientist*).

**Pick Ryan if you want:** to think one card ahead, to be rewarded for churning your hand and
for moving across the grid, and to win fights with ambushes rather than slugging matches.

---

## Jeremy — stronger the emptier he gets

**Character passive:** every 3rd cycle, the first ring trigger fires twice. **Slot
specialty:** 3 ring slots.

**Lanes:** Evocation (blasting with raw power), Abjurer (defense first, outlast and recover),
Shepherd (selfless, sometimes bleeding for friends), Poltergeist (death, hatred, agony).

Jeremy's passives pay out at the bottom of the tank. His damage, armor gain and healing all
gain 18%→32% effectiveness when he holds 2 or fewer cards (*Harnessed Power*), ending a spell
at 0 mana makes his next offensive card 1 tempo cheaper (*Arcane Overflow*, 20→6 cooldown),
spending 100 mana inside 5 tempo hands him a free 0-mana attack that refunds mana (*Mana
Surge*), and playing the card that empties his hand cleanses a debuff (*Fresh Start*). Where
other characters build up, Jeremy spends down.

His second axis is probability and cards that rewrite themselves. Every % chance on his cards
is raised by 5→12 (*Tricks of Death*), and whenever a card rerolls to a new outcome in his
hand he gets a free Magic Barrier instant worth 2→16 armor (*A Mage's Favor*). He does not
pray to the dice; he loads them.

The Abjurer and Poltergeist lanes make him awkward to attack. Armor he keeps for 30→16 tempo
shocks the nearest enemy for each defensive card in his deck (*Kinetic Armor*); an enemy that
attacks him while he holds 3+ defensive cards has its next action delayed 3 tempo (*Haunted
Rebuke*); and an offensive card aimed at an empty tile summons a Specter decoy with 5→33 HP
that deals its HP to whoever kills it (*Seance*).

The Shepherd lane is the game's most selfless kit. Allies within 3 squares are healed every
18→4 tempo (*I Heal You*). Healing an ally hands him a Shepherd's Mark that lets that ally
survive lethal damage at 1 HP with 5→19 armor, at the cost of 8 damage to Jeremy (*Whispers
of the Flock*). Taking damage stacks Sanguine, each stack adding +1→15 to all his healing; at
5 stacks his next heal is doubled, he takes 10 damage first, and the stacks reset (*Blood
Libation*).

**Pick Jeremy if you want:** to play with an empty hand and an empty mana bar and be scarier
for it, to manipulate percentages instead of accepting them, to bleed for your party, and to
build a three-ring trigger engine that doubles up every third cycle.

---

## Stephen — rhythm: chain fast, or swing slow, never in between

**Character passive:** +10% off-hand enchantment effectiveness (every other character takes
−10%). **Slot specialty:** weapon swaps cost 1 tempo, and the weapon portion of a build
switch is free.

**Lanes:** The Apex (the most efficient killer, master of offense), Sentinel (melee duelist,
armor nobody scratches), Ranger (distance, elements, stronger arrows), Avenger (huge, potent,
tires fast — timing is everything).

Almost every Stephen passive cares about cadence: what he played last, how many in a row,
and how heavy the swing was.

- **The chain.** 10→3 attacks in a row make the next resolve twice (*Skilled Momentum*).
  Hitting the same enemy three times banks +2→6 range and an auto-crit with +2%→30% crit
  damage for his next attack, spendable on *any* target (*Scouted*). Exposing an enemy deals
  his damage again and grants +1→15 Strengthen for 3 attacks (*Easy Target*). An attack-speed
  proc mints a free 0-tempo basic attack and +2→16 Strengthen (*Dominate*).
- **The alternation.** Drawing a Defense card right after an offensive play, or vice versa,
  discounts the drawn card 1 tempo and gives it +1→8 block on top of whatever it does, attacks
  included (*Clean Exchange*). With 3 or fewer cards in hand, playing a non-attack card
  triggers a free basic attack (*Lethal Resourcefulness*, 40→12 cooldown), so even his blocks
  keep pressure on.
- **The haymaker.** Any card costing more than 4 tempo deals 100%→380% of that cost as bonus
  damage (*Swing for the Fences*), and incoming Glut is turned into 10%→290% damage on the
  nearest enemy and halved (*Patience is a Virtue*).

Position is damage too: +2→16 damage and +2%→30% crit damage against a target with no allies
within 2 spaces (*Deadly*), ranged offensive cards add 100%→142% of their range as damage
(*Eagle Eye*), and burn, cold or shock has a 50%→100% chance to apply an extra charge (*Laced
Arrow*). Being hit in melee is not wasted either: crit chance on his next attack rises by
1%→4.5% per non-attack card he is holding (*Exposed Blind Spot*).

**Pick Stephen if you want:** a playstyle about sequencing and momentum — uninterrupted
attack chains, deliberate alternation, or deliberately slow oversized swings — plus range,
isolation kills, and the only full-strength off-hand in the game.

---

## Cory — arrange the fight, then let it feed you

**Character passive:** gain 1 mana whenever a gauntlet skill comes off cooldown. **Slot
specialty:** 2 gauntlet slots.

**Lanes:** Lurker (stronger as they weaken, trap and devour), Monk (calm, surrounded, helping
allies by hindering enemies), Druid (the world itself is a weapon), Atrophist (a touch that
withers the longer the fight runs).

Cory's passives make the enemies around him his sustain and their debuffs his damage.

- **Debuffs as damage.** Landing a new debuff on an enemy below half health deals 3→17
  (*Prey on the Weak*). Debuffs he applies carry +1 charge on a 15→1 tempo cooldown
  (*Wither*). An enemy entering or leaving melee range has a random debuff it already carries
  re-applied (*Territorial Death*). Dropping below 35%→63% health bounces one of his own
  debuffs onto an enemy, 2 charges on a 10-tempo refresh (*Expel Negativity*).
- **Enemies as sustain.** Every cycle he regenerates 1→5 HP per enemy within 2 squares, up to
  3→12 enemies (*Death as Lifeblood*). Kills with a card, gauntlet skill or auto attack heal
  1%→15% of max HP, and every direct hit deals +1% for each point the target sits below a
  11%→39% threshold (*Eat*). The first time an enemy drops below 11%→25% he turns invisible to
  it until he attacks, and that attack auto-crits (*Serial Killer*).
- **Throughput.** Playing an attack, a utility and a defense in any order heals 5→19 and grants
  the same temp HP (*Budding*). The third card inside one cycle discounts a random card in
  hand by 10→80 mana (*Self Reliance*). Emptying his hand draws 4 (*Regrowth*, 25→11
  cooldown). Shuffling his deck grants 10→24 armor and the same bonus damage for 3 offensive
  cards (*Circle of Life*). Every third mana gain that isn't regen — the gauntlet rebate
  included — puts a free Energy Barrier worth 3→17 armor in his hand (*Energy Barrier*).

Nothing in the kit wants him to sit on cards, stand alone, or let a debuff expire.

**Pick Cory if you want:** to win long fights through debuff attrition that heals you while it
kills them, to be rewarded for standing in the middle of a pack, and a machine-gun cadence
where hand, deck and gauntlets all cycle continuously.

---

## Brad — health is a dial, armor is ammunition

**Character passive:** chest items weigh 20% less. **Slot specialty:** the War Rack — swap to
a two-handed weapon for free, bringing its cards straight to hand; after 20 tempo the usual
gear returns on its own, with 60 tempo between swaps.

**Lanes:** Berserker (pain is strength, stronger near death), Warden (armor and tactics, no
weakness to find), The Ancient (thorns, armor and healing drawn from nature), The Fallen (a
cast-out child of god, earning a way back).

Brad's passives make low health valuable and armor a stockpile.

- **Health as a dial.** Below 50% HP he gains 1→15 strength (*Directed Strength*). Dropping
  below 10%→25% triggers a free reach AoE swing that refunds mana per kill, re-firing on a
  25→10 cooldown while he stays low (*Enraged Will*). Every attack life-steals 1%→8% (*Life
  Steal*), which is what lets him ride the line instead of dying on it. When stunned, silenced
  or disarmed he can pay 20%→6% of max HP to ignore it (*Point to Prove*).
- **Armor as ammunition.** Defense cards grant +1→5 armor, and three in a row add +3→14 more
  (*Pristine Armor*). Every 9th→2nd Defense card refunds 10 mana and 1 tempo (*The Way of the
  Plate*). He takes 1%→11.5% less fire, physical and lightning damage (*Stone Skin*).
- **Healing as offense.** Any direct heal grants 1→8 thorns and 0→7 regen for 5 tempo (*Vines
  Codependence*) and 1%→15% crit chance on his next offensive card or auto attack
  (*Redemption*). Every 5 cycles, a hand heavier in offense discounts a random offensive card
  by 50→190 mana, and a hand heavier in defense heals 3→17 (*Ancestral Aid*).
- **Being swarmed is a buff.** With 3+ enemies within 2 tiles he gains +5%→12% damage on every
  offensive card and auto attack and +1→8 armor per cycle, at the cost of all ally healing
  (*Solemn Independence*). Anyone stepping adjacent eats a free attack at 50%→120% damage, and
  anyone attacking from adjacent is knocked back — 2 shared charges, 10 tempo each (*In the
  Trenches*).

**Pick Brad if you want:** to deliberately fight at low health and be rewarded for the risk,
to bank armor as a second weapon rather than just a shield, to be the one standing in the
doorway, and to haul a two-hander off your back mid-fight.

---

## Quick reference

| Character | What the passives reward | Slot specialty | Character passive |
|---|---|---|---|
| **Ryan** | Discarding and cycling; moving across the grid; first-strike ambushes from invisibility | 2 belt slots | Belt cards cost 1 less mana |
| **Jeremy** | Being at 0 mana / ≤2 cards; rigged % chances; healing allies at his own expense | 3 ring slots | Every 3rd cycle, first ring trigger fires twice |
| **Stephen** | Unbroken attack chains, attack/defense alternation, or oversized slow swings; isolated targets and range | Weapon swaps cost 1 tempo | +10% off-hand enchantments (others −10%) |
| **Cory** | Debuffs on wounded enemies; standing inside a pack; playing one of every card type per cycle | 2 gauntlet slots | +1 mana when a gauntlet skill comes off cooldown |
| **Brad** | Spending health for strength; stockpiling armor; being swarmed; healing that turns into thorns and crits | War Rack (two-handed swap) | Chest items weigh 20% less |

All five share the identical 5-card basic deck and begin with no equipment. Every card in the
game is neutral — the kits above describe what each character's passives reward, not which
cards each character is allowed to use. For what the code actually does with every passive,
including where it disagrees with the design text, see
[`PASSIVE_REFERENCE.md`](PASSIVE_REFERENCE.md).
