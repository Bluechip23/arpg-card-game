# Item design notes

Comments carried over from the item factories when the items moved to
`data/items/*.tres` (E5). The data itself lives in the `.tres` files; this is
the designer intent that `.tres` cannot hold. Grouped as the factories were.

## WEAPONS

### `return_scroll`
Utility scroll every adventurer carries: right-click it in the
inventory to open a town portal where you stand. The portal's twin
appears in town, and stepping through either end crosses over. Coming
back through it closes the portal (it is spent; no re-open).
- `item.item_type = ItemType.SCROLL` — utility scroll — never equips

## TUTORIAL GIFT (Olorin's trade for the Bladed Doughnut)

### `wooden_sword`
No stats at all — its worth is the lesson: a card slot with an on-self
bonus, plus a granted card (Splinter) that travels with the item.

## MYTHIC ITEMS (max level 3)

### `bladed_doughnut`
Tutorial mythic: the first rat of the story drops it; the player cannot
wear a mythic yet, so Olorin sends it to the Blacksmith to be melded
into a Mythic Piece. It remains a real mythic — redeemable later via a
Mythic Mold.

## HELMS (first item pass

HELMS (first item pass — head slot)
Shared setup for every helm so the 19 factories stay declarative.
### `dragon_skull`
- `item.on_self_range_offensive = 1` — +1 range on any offensive slotted card
- `item.crit_fire_cone_damage = 10` — on crit: 10 + INT/2 fire damage...
- `item.crit_fire_cone_range = 3` — ...in a 3-range cone in front of the wearer

### `feathered_hat`
- `item.flash_crit_threshold = 25` — spend 25 flash → next ranged offensive card crits

### `frankensteins_screws`
- `item.summon_heal_aura = 3` — summons below 25% HP within 3 tiles heal 3/cycle

### `horned_nasal_helm`
- `item.on_self_apply_bleed = 1` — on-self: "if an offensive card apply 1 bleed"
- `item.auto_purge_per_cycle = 2` — purge 2 random debuffs...
- `item.auto_purge_interval_cycles = 3` — ...every 3 cycles (15 tempo)

### `the_headbandz`
Out of Guesses dropping to 1 tempo at Lv.3 is read live off item_level
(see Card.get_burden_tempo_cost).

### `scholars_cap`
- `item.on_self_brain_regen = 2` — slotted cards regain 2 brain points on play

### `hannibals_mask`
- `item.on_self_lifesteal_percent = 15.0` — slotted cards only, per the description
Resourceful Replenish maintaining at 8% at Lv.3 is read live off item_level
(see the maintained-lifesteal block in Card.execute).

### `mane_of_narashimha`
- `item.void_resistance_percent = 5.0` — nearby enemies take +5% damage (lowered resistance)

### `shamans_mask`
- `item.on_self_utility_heal = 3` — utility cards heal 3
- `item.on_self_utility_spell_damage = 1` — ...and deal 1 spell damage to a random enemy in 3

### `wizard_hat`
- `item.spell_power_per_attacks = 3` — every 3rd attack...
- `item.spell_power_bonus = 5` — ...arms +5 spell power on the next spell card

### `summoners_cap`
- `item.on_self_heal = 3` — +3 to a slotted card's heal; non-healing slotted cards heal the wearer 3 directly
- `var summoner_cards: Array[String] = ["heal"]` — the existing basic "Heal" card

## BOOTS (first boots pass

BOOTS (first boots pass — feet slot)
### `blink_boots`
Carrier for GRANT_BLINK_CARD: the boots travel with two Blink cards —
first-pass numbers.

### `titanium_toe_tuckers`
- `item.on_self_armor_any = 8` — ANY slotted card grants +8 armor

### `rollerblades`
- `item.on_self_reaction_armor = 10` — slotted instant → +10 armor
- `item.movement_flash_discount = 1` — movement flash costs 1 less

### `cyde_livingstons_sneakers`
- `item.consecutive_attack_draw = 5` — 5 consecutive attacks → draw a card

### `houdinis_slippers`
- `item.on_self_invisible_tempo = 5` — slotted card → invisible 5 tempo

### `boots_of_the_balancer`
- `item.on_self_armor_per_missing_health10 = 5` — 5 armor per 10% missing health

### `hermes_boots`
- `item.on_self_flash_regen = 1` — slotted card restores 1 flash point
- `item.trap_damage_percent = 25.0` — traps deal +25% damage (main's trap damage step reads it)

### `jordan_1s`
- `item.missing_life_damage_rate = 0.5` — +0.5 damage per missing enemy-health %
- `item.missing_life_threshold = 50` — ...only while the enemy is at/below 50% health

### `guardian_greaves`
Mend restoring 40%/40% at Lv.3 is read live off item_level (see the mend
world effect in main.gd); no field changes at Lv.3.
Modelled on DOTA 2's Guardian Greaves.

### `knife_toed_boots`
- `item.melee_crit_flat_bonus = 10` — melee crits deal +10 flat (no scaling)

### `boots_of_speed`
- `item.movement_flash_tempo_threshold = 36` — 36 movement-flash spent → -1 tempo from a hand card

### `caster_boots`
- `item.on_self_int_damage_percent = 10.0` — +10% of INT as bonus damage on slotted cards

## GAUNTLETS (first gauntlets pass

GAUNTLETS (first gauntlets pass — hands slot)
Skill cooldowns tick once per 5-tempo cycle, so the spec's tempo values are
stored as cycles (20t=4, 15t=3, 10t=2, 8t=2, 25t=5).
### `mits_of_chingiz`
"3 count" is a cooldown passive handled in main: two offensive cards in a
row add a Switch Kick to the hand (20 tempo CD).
- `item.gauntlet_skill_cooldown = 4` — 20 tempo, read by main's 3 count trigger

### `spidey_web_shooters`
- `item.on_self_disarm_offensive = 1` — 1 stack = 5 tempo of Disarm: the target cannot attack while it lasts

### `gravity_gauntlets`
- `item.on_self_root_offensive = 1` — hold for 1 cycle (5 tempo)

### `spiked_mitts`
- `item.on_self_armor_any = 5` — ANY slotted card grants +5 armor

### `momentum_mits`
- `item.on_self_draw_card = 1` — slotted card play draws a card

### `roman_bracers`
- `item.on_self_melee_damage = 5` — slotted melee offensive cards +5 damage

## BELTS (first belts pass

BELTS (first belts pass — waist slot)
### `tactical_belt`
- `item.on_self_target_aoe_damage = 2` — radius-1 blast around the card's target, enemies only

### `orions_belt`
Balance of Alnilam reads the belt's level live: it draws 10 at Lv3.

### `girdle_of_aphrodite`
- `item.on_self_taunt_cycles = 3` — 15 tempo

## WEAPONS (first weapons pass

WEAPONS (first weapons pass — both hands)
### `pocket_knife`
Carrier for POCKET_KNIFE_PROC: sharpens the DEX proc — first-pass numbers.

### `bessy`
weapon_damage removed for now — the stat is inert (no combat path reads
it); design will revisit how weapon damage should work.

### `mauls_sabre`
The first colored-slot item: a blue slot and a red slot, each carrying
its own payload, with combos for weaving one immediately after the
other. The colored-slot system debuted here (the Crooked Dueling Shield
and Feral Evocation followed).

### `poseidons_trident`
Wrath of the Sea granting 18 mana per enemy at Lv.3 is read live off
item_level (see main's wrath_of_the_sea world case).

### `umbral_eclipse`
Monk of the Night converting 15% at Lv.3 is read live off item_level
(see the maintained-block conversion in Card.execute).

## CHESTS (first chests pass

CHESTS (first chests pass — torso slot)
### `bloodbound_plate`
Carrier for OVERFLOW_HEAL_ARMOR's armor half (value_2): every armor
instance grants bonus armor — first-pass numbers.

### `adimantium`
Adimantium Wall granting 55 block at Lv.3 is read live off item_level
(see Card.execute's adimantium_wall case).

### `hide_of_garmr`
Ragnarok healing 15 / granting 7 STR per released card at Lv.3 is read
live off item_level (see Card.execute's ragnarok case).

## RANGED (first ranged pass

RANGED (first ranged pass — bows & quivers)
Bows are two-handed (Inventory.is_two_hand_only) and admit only a quiver
alongside them; the quiver rides in the other hand slot and takes that
slot's off-hand modifier like any hand item. The Boomerang and Wrist Rocket
are the one-handed exceptions — thrown "bows" that still pair with a quiver.
## SHIELDS (first shields pass

SHIELDS (first shields pass — the off hand that fights back)
Shields are hand items like any other weapon (Inventory gates them purely by
weight), and their slots take Buckler-labelled cards. Three ideas run through the
set: flat damage reduction that shrugs off chip damage, punishment for the
enemy who chose to swing at you, and Overdraw — a full hand turning an
unwanted draw into a payout.
### `elemental_emblem`
The design sheet gives this legendary a stat line and nothing else — no
bonus slots, no card, no rider. Left exactly as specified. (Since the
2026-10-20 slot table it has 2 plain slots.)

### `delfins_deterministic_round_shield`
Mage Shield's block reads the shield's level live at play time (see the
mage_shield case in Card.execute), so it isn't listed here.

### `steve_rodgers_bastion`
Bouncing Shield's temp-mana duration reads the shield's level live (see
the bouncing_shield case in main), so it isn't listed here.

### `crooked_dueling_shield`
The second colored-slot item after Mauls Sabre: a blue slot that Weakens
and a red slot that makes the target Vulnerable, rewarding the duelist
who plays them back to back in either order.

## SPELL WEAPONS (spell weapons pass 1)

Wands, books and orbs share a hand; anything marked STAFF demands both
(Inventory.is_two_hand_only). Orbs are wands with a rounder silhouette.
The books (Fire/Frost/Earth Book) keep the TOME weapon subtype, but the
Tome slot label was folded into Wand on 2026-10-20: their slots take Wand cards.
### `wand_of_the_phoenix_feather`
From the Ashes healing x8 / regen 3/4 at Lv.3 is read live off item_level
(see _execute_from_the_ashes in Card).

### `reaper_scythe`
Reaper's Taking hitting for 35 at Lv.3 is read live off item_level
(see _execute_reapers_taking in Card).

### `feral_evocation`
The third colored-slot item (after Mauls Sabre and the Crooked Dueling
Shield) — and the first where the slots hold ELEMENTS: red Burn, blue
Cold, yellow Shock, green Poison. Playing one color converts every other
slotted card currently in hand to that color; conversion resets when a
card leaves the hand. Each conversion zaps a random nearby enemy.

## RINGS (first rings pass)

The game's first real rings. Most carry bespoke cumulative counters
(ring_counters) — one journey, no battles, no resets — with world-side
payloads executed by main off Inventory.custom_ring_fired. Random-enemy
procs reach 5 squares.
Rings are the mana slot. Rather than sprinkling a few points of mana across
every helm, belt and boot — leaving the player hunting for a pool one item at
a time — the whole budget lives here, granted by rarity. A caster builds
their pool out of rings and spends the other slots on what those slots are
actually for. Every ring gets this automatically, including future ones.
