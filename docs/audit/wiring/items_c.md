# Wiring audit — items slice C

63 items, Ring of Thomas the Train Tracks → Wrist Rocket. Every item is checked
in a booted `main.tscn` (the dojo) by `tests/test_wiring_items_c.gd`, equipped
through the real `Inventory`:

- **Every item** (`_test_equip_all`): the stat block lands on the wearer and
  comes back off on unequip, hand size, and each `granted_card_ids` entry
  reaches the deck (one copy per id) and leaves with the item.
- **Slot counts** the tooltips spell out (`_test_slot_counts`), **granted-card
  prices** the tooltips quote (`_test_granted_card_prices`), and each item's
  own riders, played through `Card.execute` + main's world-effects step (the
  play scope), `main.play_selected_card`, the gauntlet skill bar
  (`main._fire_gauntlet_skill`), real enemy hits (`Enemy._deal_damage_to_player`),
  the cycle (`Inventory.process_turn`, `main._shield_on_cycle_passives`) and
  Overdraw (`main._on_overdraw_processed`).

Notes that apply to several rows:

- Heals from riders go through `PlayerStats.heal`, which adds the wearer's
  INT bonus and healing bonus to every heal ("INT also boosts healing"), so a
  rider's "heal 3" lands as `get_effective_heal_amount(3)`. Treated as the
  global heal rule, not a mismatch.
- Granted cards' own behaviour belongs to the card slices; this slice checks
  that each granted card exists, reaches the deck, and carries the numbers
  the item's tooltip quotes (plus the item-specific parts: Out of Guesses at
  1 tempo on a Lv.3 Headbandz, From the Ashes, Detonova, Shift, Cinquedea).

T = `tests/test_wiring_items_c.gd`

| name | type | status | what was wrong | what changed | test name |
|---|---|---|---|---|---|
| ring_of_thomas_the_train_tracks | item | CORRECT | — | — | T::Thomas: a shuffle grants 7 Regen; T::Thomas: every 3rd shuffle also heals 25; T::Thomas Lv.3: every 2nd shuffle heals 35 (also tests/test_rings_pass.gd) |
| rollerblades | item | CORRECT | — | — | T::Rollerblades: a slotted instant (5 armor) gains 10 more; T::Rollerblades: a flash move costs 1 less; T::Rollerblades: Shift moves you 2 spaces |
| roman_bracers | item | CORRECT | — | — | T::Roman Bracers: a slotted melee attack deals +5; T::Roman Bracers: Slice costs 2 tempo; T::Roman Bracers: Slice has a 10 tempo cooldown |
| rusty_dagger | item | CORRECT | — | — | T::Rusty Dagger: a slotted card crits ~15% of the time from 0% |
| sabre_tooth | item | CORRECT | — | — | T::Sabre Tooth: an offensive hit applies 5 Bleed; T::Sabre Tooth: striking the same target again rakes 5 more Bleed; T::Sabre Tooth: ...and ticks the attack-speed counter once more |
| sack_of_bone_arrows | item | FLAGGED | Its +5 WIS / +3 INT land as +4 / +2: a quiver always sits in the off hand, which takes the 0.9 off-hand modifier (rounded down). The kill-skeleton rider is a boolean and works in full. | — | T::sack_of_bone_arrows: stat block lands on the wearer; T::Sack of Bone Arrows: a kill with a slotted offensive card raises a skeleton; T::Sack: up to 3 at once |
| scholars_cap | item | CORRECT | — | — | T::Scholars Cap: +5 max brain points (on top of its +5 WIS); T::Scholars Cap: Peek costs 1 less; T::Scholars Cap: any slotted card regains 2 brain points; T::Scholars Cap Lv.3 |
| scholars_signet | item | CORRECT | — | — | T::scholars_signet: stat block lands on the wearer |
| shadow_cowl | item | CORRECT | — | — | T::Shadow Cowl: a slotted offensive card deals +2; T::Shadow Cowl: ...and makes the next 2 tiles free; T::Shadow Cowl: the 2 tiles cost no tempo |
| shadow_obi | item | CORRECT | — | — | T::Shadow Obi: +5 damage while invisible; T::Shadow Obi: an unslotted 1-tempo card deals 3 to a random enemy; T::Shadow Obi: a 2-tempo card zaps nothing |
| shamans_mask | item | FIXED | "Utility cards" read only the Utility type, so a utility-tagged instant (Healthy Bliss) got neither the heal nor the zap — CARD_TAXONOMY makes Utility the type OR the tag. | card.gd utility-heal rider and main._helm_card_world_effects' zap read the type or the `utility` tag; on_self_rules.qualifies("utility") too. | T::Shamans mask: a slotted utility card heals 3; T::Shamans mask: 1 spell damage to the enemy within 3, not the one at 5; T::Shamans mask: a utility-tagged instant counts as a utility card |
| shepherds_crook | item | CORRECT | — | — | T::Shepherds Crook: all your healing heals 5 more; T::Shepherds Crook: a targeted card pulls its target 1 square toward you; T::Shepherds Crook: allies are pulled too; T::Shepherds Crook is two-handed |
| shock_quiver | item | FLAGGED | In play it applies 1 Shock and +4.5% crit, with +2 AGI / +1 WIS / +1 DEX: the off-hand 0.9 modifier every quiver sits under halves the 2 Shock (rounded down) and trims everything else. | — | T::Shock Quiver (FLAG): the off hand makes 2 Shock / 5% crit into 1 / 4.5%; T::Shock Quiver: a slotted hit applies its (off-hand) Shock |
| short_bow | item | CORRECT | — | — | T::Short Bow is two-handed; T::Short Bow: no second weapon; T::Short Bow: pairs with a quiver |
| short_sword | item | CORRECT | — | — | T::short_sword: grants 1 x slice into the deck; T::Short Sword: Slice (10 mana, 3 tempo); T::Slice deals 15 damage |
| side_card_sabre | item | CORRECT | — | — | T::Side Card Sabre: weightless beside a main-hand sword; T::Side Card Sabre: its slotted cards cost 1 less tempo; T::Side Card Sabre: a shield in the main hand doesn't count |
| sleeved_katar | item | CORRECT | — | — | T::Sleeved Katar: +25% crit damage; T::Sleeved Katar: +5% crit chance; T::Sleeved Katar: the skill grants 5 armor; T::Sleeved Katar: the next melee card deals +5; T::Sleeved Katar: 25 tempo cooldown; T::Return Cut is an Instant |
| slotted_rope_half_sleeve | item | FLAGGED | Its on-self "+3 block (armor on a card that blocks nothing)" nets 0 on a non-block card: the +3 is that card's first armor grant, and the sleeve's own "-3 block from your block cards" rides the any-type armor channel (PlayerStats.add_armor, the Thick Steel ruling), so it eats the +3. Everything else matches. | — | T::Rope Sleeve (FLAG): a slotted card that blocks nothing nets 3 - 3 = 0 armor; T::Rope Sleeve: a slotted block card gets +3 block; T::Rope Sleeve: any slotted card discards a card; T::Rope Sleeve: Overdraw drops a Cinquedea into the manifest zone, up to 5; T::Rope Sleeve: each waiting Cinquedea gives block cards +1; T::Rope Sleeve: spending a Cinquedea takes its point with it |
| smithed_excellence | item | CORRECT | — | — | T::Smithed Excellence: with block up, 10% more physical resistance; T::Smithed Excellence: a slotted card grants 2% resistance to all types for 3 tempo |
| spartan_spear | item | CORRECT | — | — | T::Spartan Spear: nothing without a shield; T::Spartan Spear: a shield grants Reach; T::Spartan Spear: Reach — a melee card hits 2 squares away; T::Spartan Spear: ...and +2 melee damage |
| spidey_web_shooters | item | CORRECT | — | — | T::Spidey: a slotted offensive card Disarms for 5 tempo; T::Spidey: Coming in! pulls you to a target 5 squares away; T::Spidey: Coming in! has a 10 tempo cooldown |
| spiked_mitts | item | CORRECT | — | — | T::Spiked Mitts: ANY slotted card provides +5 armor; T::Spiked Mitts: 25 armor gained -> 5 thorns; T::Spiked Mitts: Well placed guard — 5 thorns, 15 mana, 15 tempo CD |
| spiked_shield | item | CORRECT | — | — | T::Spiked Shield: 1 Thorns every cycle |
| standard_quiver | item | FLAGGED | Its only rider, +1 range on offensive cards, is 0 in play (and its +1 AGI / +1 DEX are 0): a quiver always sits in the off hand, and the 0.9 off-hand modifier floors 1 to 0. Only Stephen's empowered 1.1 off hand gets it. | — | T::Standard Quiver (FLAG): the off hand floors its +1 range to 0; T::standard_quiver: stat block lands on the wearer |
| steel_boots | item | CORRECT | — | — | T::Steel Boots: nothing after 10 tempo; T::Steel Boots: 1 unerring armor at 15 tempo |
| steel_plate | item | CORRECT | — | — | T::Steel Plate: nothing at 15 tempo; T::Steel Plate: 8 unerring armor every 20 tempo with room under the cap; T::Steel Plate: at 20 tempo, up to your unerring cap |
| steve_rodgers_bastion | item | CORRECT | — | — | T::Bastion: an enemy hit gives you 5 mana; T::Bastion Lv.2: 7 mana per hit; T::Bastion: Bouncing Shield (55 mana, 4 tempo); T::Reverberate Regrowth is a 55-mana Maintain |
| strap_of_stone | item | CORRECT | — | — | T::Strap of Stone: 10 unerring armor every 20 tempo; T::Strap of Stone: ...up to your unerring cap; T::Strap of Stone: a slotted card grants 10% physical resistance for 10 tempo; T::Stone Encase: gain 50 armor and become stunned |
| stringless_sender | item | CORRECT | — | — | T::Stringless Sender: 1 less tempo; T::Stringless Sender: 10 more mana; T::Stringless Sender: ~20% of shots bounce; T::Stringless Sender: the bounce lands at full damage |
| studded_belt | item | CORRECT | — | — | T::Studded belt: any slotted card gains you 3 thorns |
| suit_and_tie | item | CORRECT | — | — | T::Suit and Tie: obtaining gold heals 3; T::Suit and Tie: Negotiate (20 mana, 3 tempo) |
| summoners_cap | item | CORRECT | — | — | T::Summoners Cap: a slotted heal heals 3 more; T::Summoners Cap: a slotted card that doesn't heal heals you 3; T::summoners_cap: grants 1 x heal into the deck |
| supernova_cuirass | item | CORRECT | — | — | T::Supernova: a 100 hit lands as 88, 10 harnessed as one stack; T::Supernova: with no stack room (10) it absorbs nothing; T::Supernova: Detonova deals the absorbed 10 within 2 squares, unscaled by INT (also tests/test_chest_pass.gd) |
| sword_breaker | item | CORRECT | — | — | T::Sword Breaker: any slotted card gains 4 armor and Fortify for 5 tempo; T::Sword Breaker: melee damage the armor swallows whole costs that enemy 2 tempo; T::Sword Breaker: ...on its next melee attack's wind-up |
| sword_of_theseus | item | CORRECT | — | — | T::Sword of Theseus: 5% lifesteal; T::Sword of Theseus: a hit applies 2 Slow; T::Sword of Theseus: +1 damage per Slow on the target; T::Sword of Theseus Lv.3 |
| tactical_belt | item | FIXED | "A card aimed at an enemy detonates": any slotted card with a target detonated, so a self-cast card (a heal on yourself) blasted every enemy next to you; and a card in its plain slot detonated too (main read the item's bonus, not the card's). | main._helm_card_world_effects: the blast needs an Enemy target, and the step reads `card.get_on_self_bonus()` (neutral in a plain slot). | T::Tactical belt: the enemy beside the target takes 2; T::Tactical belt: a card aimed at yourself detonates nothing; T::Tactical belt: a card in the plain slot detonates nothing; T::Tactical belt: the wielder (an ally beside the target) is unharmed |
| tattered_cloth | item | CORRECT | — | — | T::tattered_cloth: stat block lands on the wearer |
| techno_wraps | item | CORRECT | — | — | T::Techno Wraps: the discard pile shuffles into the draw pile; T::Techno Wraps: 15 tempo cooldown |
| the_headbandz | item | CORRECT | — | — | T::The Headbandz: a slotted card costs 20% less mana; T::The Headbandz Lv.3: 35% off slotted cards; T::The Headbandz Lv.3: Out of Guesses costs 1 tempo |
| the_precious | item | CORRECT | — | — | T::The Precious: the 4th enemy hit drags you into shadow form for 10 tempo; T::The Precious: max mana is halved inside; T::The Precious: THREE ring wraiths hunt you; T::The Precious: a wraith has 100 HP, 15 damage every 2 tempo, moves every 4; T::The Precious: after 1 tempo, clicking the badge leaves shadow form; T::The Precious: they return as they were left; T::The Precious Lv.3: TWO wraiths |
| the_rapid_recurve | item | CORRECT | — | — | T::Rapid Recurve: 1.5x mana; T::Rapid Recurve: Double Shot hits a second time at full damage; T::Rapid Recurve: the card is jailed 20 tempo after play |
| the_slotted_sash | item | FIXED | "Defense cards" / "utility cards" read only the raw type, so Vengeful Shield (a defense-tagged instant) got no +2 armor and a utility-tagged instant Weakened nobody; and a card in its plain slot still Weakened (main read the item's bonus, not the card's). | card.gd defense-armor rider reads the type or the `defense` tag; main's Weaken step reads the type or the `utility` tag and the card's own (plain-slot-neutral) bonus; on_self_rules.qualifies("defense"/"utility") too. | T::Slotted Sash: offensive cards +2 damage; T::Slotted Sash: defense cards +2 armor; T::Slotted Sash: a defense-tagged instant counts as a defense card; T::Slotted Sash: a utility card Weakens a random enemy within 5; T::Slotted Sash: a utility card in the plain slot Weakens nothing |
| theif_hat | item | CORRECT | — | — | T::theif_hat: stat block lands on the wearer |
| thick_steel_helm | item | CORRECT | — | — | T::Thick Steel Helm: 10% resistance to all damage; T::Thick Steel Helm: an armor card grants 2 more; T::Thick Steel Helm: ...of any type |
| tigers_sunday_red | item | CORRECT | — | — | T::Tigers: +1 range on a ranged offensive card; T::Tigers: +(HP-gap / 4)% damage; T::Tigers: a slotted offensive card heals 3% of max health; T::Tigers Lv.3 |
| tightened_cross_bow | item | CORRECT | — | — | T::Tightened Cross Bow: +5 damage; T::Tightened Cross Bow: +1 tempo |
| titanium_toe_tuckers | item | CORRECT | — | — | T::Titanium Toe Tuckers: a slotted attack provides +8 armor; T::Titanium Toe Tuckers: side step gives 2 more armor |
| treebeards_branch | item | CORRECT | — | — | T::Treebeards Branch: any slotted card gains you 3 Thorns; T::Treebeards Branch: Overdraw grants 3 Regen; T::Treebeards Branch: Bark Up (45 mana, 3 tempo) |
| trench_of_tranquility | item | CORRECT | — | — | T::Trench: a slotted heal card heals 5 more; T::Trench: a slotted card that doesn't heal heals you 5; T::Mind Mend costs 15 HEALTH; T::Deep Breaths heals 20 |
| umbral_eclipse | item | CORRECT | — | — | T::Umbral Eclipse: gaining armor deals 5 to the enemy in melee range; T::Umbral Eclipse: nothing when no enemy is in melee range; T::Umbral Eclipse: an Insight draw restores 2 flash points; T::Umbral Eclipse Lv.3 |
| vanguard | item | CORRECT | — | — | T::Vanguard: a hit is 3 damage lighter; T::Vanguard: 1 Regen every cycle |
| velvet_plate | item | CORRECT | — | — | T::Velvet Plate: a slotted attack heals you 5 |
| vengeful_shield | item | CORRECT | — | — | T::Vengeful Shield: the enemy target is shoved back 1; T::Vengeful Shield: a card with no enemy target shoves every adjacent enemy |
| waistband | item | CORRECT | — | — | T::Waistband: any slotted card gains you 2 armor |
| wand_of_clarity | item | CORRECT | — | — | T::Wand of Clarity: no debuffs -> ALL cards 15% less mana; T::Wand of Clarity: a debuff takes the discount away; T::Wand of Clarity: a slotted card regains 2 brain and 2 flash |
| wand_of_deliverance | item | CORRECT | — | — | T::Wand of Deliverance: all your cards gain +2 range; T::Wand of Deliverance: damaging offensive cards deal +2 |
| wand_of_the_phoenix_feather | item | CORRECT | — | — | T::Phoenix Feather: applying Burn burns you 1 — once per play; T::From the Ashes: enemies within 3 take 5 per stack; T::From the Ashes: heal 5 per stack; T::From the Ashes: Regen equal to half of it; T::Phoenix Feather Lv.3 |
| wizard_hat | item | CORRECT | — | — | T::Wizard Hat: the 3rd attack arms +5 spell power; T::Wizard Hat: the next spell deals +5; T::Wizard Hat: ...and spends it |
| wooden_plank | item | CORRECT | — | — | T::Wooden Plank: the hit that drops you below half grants 1 Regen; T::Wooden Plank: further hits below half grant no more |
| wooden_shield | item | CORRECT | — | — | T::Wooden Shield: an enemy that strikes you in melee takes 1 Bleed; T::Wooden Shield: a ranged striker does not |
| wooden_spear | item | CORRECT | — | — | T::Wooden Spear: an offensive hit applies 1 Bleed |
| wooden_sword | item | CORRECT | — | — | T::Wooden Sword: +1 damage; T::Wooden Sword: 1 card slot; T::wooden_sword: grants 1 x splinter into the deck |
| wrist_rocket | item | FLAGGED | The tooltip says "One-handed; pairs with a quiver", but a quiver is refused beside it: the designer ruled (2026-10-25, docs/ITEM_NOTES.md "RANGED") that a quiver is only worn beside a bow and the Wrist Rocket "take[s] no quiver". Its +10% crit, one-handedness and 2 Improvised Ammo are right. | — | T::Wrist Rocket: +10% crit chance; T::Wrist Rocket is one-handed; T::Wrist Rocket (FLAG): a quiver is refused beside it; T::wrist_rocket: grants 2 x improvised_ammo into the deck |

## Flagged

- **Quivers in the off hand (standard_quiver, shock_quiver, sack_of_bone_arrows).**
  A quiver can only be worn beside a bow, so it is always in the off hand,
  and every off-hand item takes the 0.9 modifier (rounded down). That makes
  Standard Quiver's +1 range and +1 AGI/DEX zero for everyone but Stephen,
  Shock Quiver's 2 Shock into 1, and trims every quiver stat. Should quivers
  be exempt from the off-hand modifier (they never have a main-hand option),
  or should their tooltips state the off-hand numbers?
- **Wrist Rocket: "pairs with a quiver".** The 2026-10-25 hand rule refuses a
  quiver beside it. Should the tooltip drop "pairs with a quiver", or should
  the Wrist Rocket be the one thrown weapon a quiver may accompany?
- **Slotted Rope Half Sleeve: its +3 on a card that blocks nothing.** The
  sleeve's "-3 block from your block cards" uses the same any-type channel as
  Thick Steel (the resolving card's first armor grant), so the on-self "+3 …
  armor on a card that blocks nothing" always nets 0. Should the -3 apply only
  to the card's own block (so a non-block card keeps the full +3 armor), or is
  the rider meant to cancel out there?

## Shared code touched

- `scripts/core/main.gd` `_helm_card_world_effects` and `_helm_range_bonus`
  now read `card.get_on_self_bonus()` (neutral in a plain/vanilla slot)
  instead of `card.slotted_in_item.get_on_self_bonus()`. This also stops
  plain-slot cards from firing Boot Holsters' instant damage, Gauntlets of
  Dungeon Mastering's wolf, Houdinis Slippers' invisibility, Shadow Cowl's
  shift and the helms' on-self range — the plain-slot rule
  (ItemData.get_on_self_bonus_for) says they confer nothing.
- `scripts/progression/on_self_rules.gd` `qualifies("defense"/"utility")`
  reads the type or the tag (tooltip "applies" marks). Potion Belt's
  `utility_tempo_refund` consumer (card.gd `get_burden_tempo_cost`) still
  reads the raw Utility type; its slice may want to align it (the only
  utility-tagged non-Utility card, Healthy Bliss, costs 0 tempo, so nothing
  differs today).
- `scripts/cards/card.gd`: the Slotted Sash defense-armor and Shamans
  utility-heal riders read the type or the tag.
- Observation for the cards slice (not changed): Parry's executor grants a
  hard-coded 5 armor and ignores `block`, so an on-self "+X block" rider
  never reaches a slotted Parry.
