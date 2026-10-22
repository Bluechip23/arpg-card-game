# Card design notes

Comments carried over from the card factories when the cards moved to
`data/cards/*.tres` (E6). The data lives in the `.tres` files; this is the
designer intent `.tres` cannot hold, in the factories' order.

### `slash`
The basic Attack card. Its id stays "slash" so saved decks, the basic
deck list and purchase records keep resolving; only the name changed.
Conditional: it takes the reach of the weapon in hand (melee with a
melee weapon, Ranged 5 with a bow or a magic weapon).
- `card.tempo_cost = 3` — Standard attack

### `block`
- `card.tempo_cost = 2` — Standard defense

### `fleet_etching`
First-pass Engrave card for boot slots (Swift keyword).

### `regal_etching`
First-pass Engrave card for helm slots (Crown keyword).

### `empower`
- `card.tempo_cost = 2` — Setup action

### `heal`
- `card.tempo_cost = 2` — Takes effort to heal

### `taunt`
- `card.aoe_range = 3.0` — 6 square diameter

### `roar`
- `card.aoe_range = 3.5` — within 3 squares

### `armor_break`
- `card.card_type = CardType.ATTACK` — the sheet's type; a self-cast whose NEXT attack carries it

### `charge`
- `card.target_types = ["point"]` — a direction, never a required enemy
- `card.aoe_range = 5.0` — the charge distance, so the preview shows the path
- `card.resolve_tick = 3` — Wind up then charge forward

### `heroic_leap`
- `card.resolve_tick = 4` — Big windup before landing

### `surrounding_ice`
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack
Per-enemy 70% hit rolls only — a card-level binary roll used to sit here
too, but nothing consumed it at resolution: it just miscolored the "30%"
in the description as if it predicted the outcome.
- `card.aoe_range = 2.5` — two squares around you

### `try_this`
- `card.chance_is_downside = true` — the 10% is the backfire

### `snowballs_chance`
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack
Chance lives in the card-level binary roll (does the cone spread?). The
fire line always hits, so per-enemy rolls (chance_effect_percent) would
only paint false red "miss" tiles on enemies the line is guaranteed to hit.
- `card.aoe_range = 3.0` — 3 grid spaces

### `exacerbate_wounds`
- `card.base_damage = 0` — damage comes from discards, not a base hit
- `card.conditional_range = true` — Melee with a blade, ranged (+1 tempo) with a bow

### `shuriken`
Hits a RANDOM enemy (no aiming) — plays immediately, resolved in main.gd.

### `down_town`
- `card.damage = PlayerStats.BASIC_ATTACK_BASE_DAMAGE` — normal auto weapon damage

### `sky_attack`
- `card.damage = 0` — the discarded card sets the damage

### `lead_arrow`
- `card.range_modifier = -2` — "lower range": 5 -> 3 tiles

### `last_breath`
- `card.base_damage = 0` — damage comes from mana consumed, not a base hit

### `round_em_up`
- `card.aoe_range = 2.5` — pull diameter 5

### `choke`
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack

### `paralysis`
Crypt Crawler web: while this sits in your hand you cannot move (other
actions are fine). Playing it tears the webbing free and erases it.
sheet: "Paralysis is 10m/5 Tempo".
- `card.linger = true` — forced into hand; may exceed the hand cap

### `release_soul`
Spirit Collector (sheet): "Release Soul: 15 mana, 2 tempo: give all
soul collectors strengthen". While it is in hand the holder is Drained
(held at 1 stack by Main._sync_held_drain, lifted when the card
leaves) and it "deals 1 dmg per tempo until played" — there is no
per-tempo in-hand tick, so the 5 tempo of a cycle are charged together
through held_damage_per_cycle (DeckManager.process_turn). Erased on play.
- `card.held_damage_per_cycle = 5` — 1 per tempo, charged per 5-tempo cycle
- `card.in_hand_debuff = "drain_1"` — Drain, held at 1 stack while in hand (Main._sync_held_drain)

### `infest`
Rat King's Infest (sheet): one lands in your hand per rat within 10
squares of the king. Held for 5 tempo it hatches into 2 Wererats
beside you; play it (50 mana, 0 tempo) to crush the brood, or discard
it — either way nothing hatches. The fuse only runs while it is in
the hand: the sheet says otherwise than the negative-card rule (a
curse's countdown runs in every pile), since a discarded brood is
erased and never reaches another pile to tick in. The hatch itself is whatever hatch_handler the king bound
(a card rebuilt by id from a save has none and simply crumbles).
- `card.linger = true` — forced into hand; may exceed the hand cap

### `halo`
- `card.mana_cost = 30` — Initial cast cost
- `card.maintain_cost = 30` — 30 mana reserved from max while active

### `armored_discipline`
- `card.maintain_cost = 50` — Maintain 5M: holds more than the 3-mana play cost

### `collect_arrows`
- `card.target_types = ["self"]` — a self utility — no enemy click required

### `absorb_essence`
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack

### `energy_ball`
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack
- `card.erase_on_play = true` — "Erased after use" — never recycles from discard

### `vines`
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack

### `internal_combustion`
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack
- `card.aoe_range = 3.0` — matches the real 3-tile blast

### `heavy_swing`
- `card.resolve_tick = 2` — Short windup for heavy hit

### `shield_slam`
- `card.resolve_tick = 7` — Heavy windup with shield

### `fireball`
- `card.element = "red"` — Feral Evocation slot color
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack
- `card.aoe_range = 2.0` — 4 squares diameter = 2 radius
- `card.resolve_tick = 6` — Channel the fireball

### `peshtigos_kiss`
The firestorm. The floor around the chosen point erupts: 10 damage to
every enemy in the flames, +5 for each enemy standing in them. The
area's diameter is INT / 8 (rounded down; never smaller than the tile
itself). The flames go out at once unless the card is maintained —
main asks after the play — and while it burns, enemies in the flames
take half that damage every 5 tempo.
- `card.maintain_cost = 60` — reserved only if the player chooses to keep the flames
- `card.aoe_range = 0.5` — main sizes it from INT when the card is selected

### `composed_reaction`
The token Composed Response's overflow makes: a reaction that fires when
the player takes damage. Lingers, since it is born into a full hand.
- `card.card_id = "composed_reaction"` — id kept for saves; the sheet names it Whirling Weapon

### `spark`
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack

### `god_of_thunder`
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack
- `card.resolve_tick = 8` — Long channel for massive spell

### `hemotoxins`
- `card.element = "green"` — Feral Evocation slot color
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack

### `healing_tonic`
- `card.is_ranged = true` — "within 5 squares": base ranged reach

### `poison_bomb`
- `card.element = "green"` — Feral Evocation slot color
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack
- `card.range_modifier = 1` — range 6

### `chain_lightning`
- `card.element = "yellow"` — Feral Evocation slot color
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack
- `card.range_modifier = 3` — range 8

### `ice_grenade`
- `card.element = "blue"` — Feral Evocation slot color
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack
- `card.range_modifier = 0` — range 5
- `card.sticky = 2` — two throws before it discards

### `worms_armageddon`
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack

### `healthy_bliss`
- `card.card_id = "healthy_bliss"` — an instant on a timer: fires from hand (see main._process_healthy_bliss_cards)
- `card.reaction_trigger = "healthy_bliss_timer"` — fired by its own clock, never by an event
- `card.keywords = ["reaction", "utility", "spell"]` — an instant that is also a utility spell

### `wrath_of_the_sea`
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack

### `detonova`
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack

### `spirit_arrow`
- `card.aoe_range = 100.0` — pierces the full line, not just 1.5 tiles

### `sprinkle_bomb`
The Bladed Doughnut's level-3 skill: the single-target Sprinkle becomes
an AOE bomb.
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack

### `splinter`
Granted by the Wooden Sword — Olorin's teaching example for items that
provide cards. Travels with the sword on equip/unequip.
- `card.range_modifier = -2` — base 5 - 2 = range 3

### `improvised_ammo`
Granted by the Wrist Rocket (2 copies). Playing it hits and Weakens;
discarding it instead pops for 4 to the nearest enemy and permanently
sharpens Improvised Ammo's crit chance (+10% per discard, never reset).

### `cupids_golden_arrow`
Cupids Bow. The golden arrow of Eros — the struck heart is drawn in.

### `cupids_lead_arrow`
Cupids Bow. The leaden arrow — the struck heart flees.

### `territorial_mark`
Bow of Arash. The arrow's flight path stays marked in blue glistening
smoke; enemies standing in the mark are Weakened while inside it.
- `card.range_modifier = 5` — base 5 + 5 = range 10

### `balistic_arrow`
Belthronding. Hitting an enemy does not stop this arrow — same line
pierce as Spirit Arrow, much heavier head.
- `card.aoe_range = 100.0` — pierces the full line

### `close_is_favored`
Conjured by Belthronding whenever a slotted card is played. Sits in the
hand as a trap for anything that closes the distance.

### `spirit_bow`
Bow of Budding Blasts. A maintained spirit bow that fights alongside
you for as long as the mana stays reserved.
- `card.maintain_cost = 65` — Maintain reserve always equals the card's mana cost

### `tricks_of_alberich`
Ring of Nibelung. The dwarf-king's bargain: all eyes on you, and you
profit from every gaze.

### `the_nibelung_curse`
Ring of Nibelung. Five heals charge it; the card carries their summed
total in the "curse_value" meta — take it as healing, or give it as
damage. Only one may exist at a time.

### `huck`
Castle wall. Throw the wall itself: everything you were hiding behind,
delivered at once.

### `rain_of_arrows`
Castle wall's Overdraw payload — the wall answers with its archers. Never
held in hand; the shield fires it off a charge.

### `song_of_a_swords_sing`
Sword Breaker. Catch the blade in the notches and twist: the more the
enemy is already suffering, the more the shield takes from it.

### `curse_of_the_living`
Coffin Lid. The dead share what they are given, whether or not the living
wanted to.

### `bark_up`
Treebeards Branch. The bark hardens: everything green about you turns to
plating.

### `cinquedea`
Slotted Rope Half Sleeve. The little ox-tongue blades tucked into the
sleeve's loops — each one waiting there stiffens your guard.
- `card.range_modifier = -1` — base ranged reach is 5; this one throws 4

### `mage_shield`
Delfins Deterministic Round Shield. No dice: the block is simply there.
Instants in this game fire free and are spent out of the hand — the same
contract as Return Cut and Hard Helmet.

### `reverberate_regrowth`
Steve Rodgers Bastion of Reverberation. The blow that cracks the guard is
the blow the guard remembers.

### `bouncing_shield`
Steve Rodgers Bastion of Reverberation. It comes back. It always comes
back — and it brings something with it from every body it touched.

### `mind_over_matter`
Presence of Mind. Meet the blow with the mind instead of the body.

### `element_pollination`
Elemental Weaver maintain: cross-pollinates the three weather elements.

### `from_the_ashes`
Wand of the Phoenix Feather: purge every self-Burn and turn it outward.
Lv.3 heals x8 and regens 3/4 — read live off granted_by_item in main.

### `polymorph`
Circe's Wand instant: the 5th distinct debuff makes the enemy a pig.
Jailed 25 tempo after it fires (handled at the trigger site) — the
cauldron needs restirring between transformations.

### `clear_mind`
Wand of Clarity: shed what clouds you and read clearly again.

### `grounding`
Reaction Rod: earth the whole field through the wielder. The -5 mana per
absorbable Shock is kept live on the card by main each tempo tick and
read at cost time in DeckManager.play_card.
- `card.card_type_name = "Spell"` — an offensive SPELL: Offensive → Spell on the card web, not an Attack

### `defensive_sacrifice`
Abjurers Cane: an instant with a CHOICE — main prompts the wielder when
an enemy attack lands; declining leaves the card in hand unspent.

### `crops`
Shepherds Crook: sow the field with berries for the flock.

### `reapers_taking`
Reaper Scythe instant: an enemy dropping below a quarter within 5
squares pulls the reaper to them. Lv.3 deals 35 — read live off
granted_by_item at the trigger site in main.
