# Wiring audit — items, slice B

63 items, Emerald to Ring of Stone Hide. Each item's `description` (its `.tres`) was traced through the code that runs it, and each claim is asserted in `tests/test_wiring_items_b.gd`. That test boots `main.tscn` as the dojo and equips every item through the real `Inventory`. Cards resolve through main's own `_resolve_queued_card`, and gauntlet skills fire through `_fire_gauntlet_skill`.

Two checks run on all 63 items:
- **Stats.** The stat tokens in the description ("+6 STR", "+25 life", "+125 mana", "+1 hand size", "5% resistance", "+10% crit chance", "+5 to heals", "+4 block on block-applying cards") land on the wearer when the item is equipped and leave when it is taken off. Each item's check is `<id>: equipping gives exactly the described stats`.
- **Granted cards.** Every id in `granted_card_ids` reaches the deck and leaves it again (`<id>: granted [...] are in the deck`). Where the item's text quotes a granted card's price, the check is `<card> costs N mana, M tempo as its item says`.

All 63 stat blocks match their text, and all granted cards reach the deck.

**Counts:** 52 CORRECT · 9 FIXED · 0 MISSING · 2 FLAGGED.

In the table, `T` stands for `tests/test_wiring_items_b.gd`.

| name | type | status | what was wrong | what changed | test name |
|---|---|---|---|---|---|
| emerald | item | CORRECT | — | — | T::emerald: the 5th Poison zaps an enemy within 5 for 2 |
| equator | item | CORRECT | — | — | T::equator: a slotted Slash that hits applies 4 burn_stacks; T::serene_center costs 30 mana, 4 tempo as its item says |
| fallens_wrath | item | FIXED | The on-self "1.5x damage" scaled only the card's base and riders, before STR, so a hit landed short of 1.5x (19 instead of 21 in the dojo). The rebound was half of that smaller bonus. | `card.gd`: the overdrive now sets the end-of-pipeline `PlayerStats.hit_multiplier`, as Megingjörð does. `progression_triggers.modify_player_hit` records what the multiplier adds, and `Card.pay_overdrive_rebound` charges half of it when the play closes. | T::fallens_wrath: a slotted card deals 1.5x the whole hit; T::fallens_wrath: and you take half the bonus yourself; T::fallens_wrath: your attacks deal +Wrath damage; T::fallens_wrath: Wrath caps at 30; test_weapons_pass (10+ Wrath: hits land 50% harder) |
| fanned_bracers | item | CORRECT | — | — | T::fanned_bracers: Fan Save inflicts 1 Weaken; T::Fanned Bracers: 10 tempo cooldown |
| feathered_hat | item | CORRECT | — | — | T::feathered_hat: the 25th flash point arms a crit and resets the counter; T::feathered_hat: the next ranged offensive card crits and spends it; T::feathered_hat: a slotted card resolves with +10% crit damage |
| feral_evocation | item | FIXED | Its colored slots also ran the Staff label gate. Only Fireball and Peshtigo's Kiss carry that label, so the blue, yellow and green slots could never be filled and no conversion could happen. This is why `test_spell_weapons_pass` was failing on the base commit. | `item_data.gd` `_slot_gate_ok`: on a colored slot, the card's element alone decides. | T::feral_evocation: playing the red card turns the blue card in hand red; T::feral_evocation: the conversion deals 4 damage to an enemy within 4; T::feral_evocation: a converted card reverts once it has left the hand; test_spell_weapons_pass |
| fire_book | item | FIXED | *(Phase 6 re-check)* The Burn rides only cards aimed at one enemy; area and point cards (played with you as the target) get the +1 damage but never Burn. | *(Pass 2)* FIXED: point/area cards apply the Burn to every enemy they damaged (`Card.apply_on_hit_debuffs`). | test_pass2_fixes.gd::A point card carries the item riders; T::fire_book: an unslotted Slash applies 1 burn_stacks; T::fire_book: an unslotted Slash deals +1 |
| fire_quiver | item | CORRECT | — | — | T::fire_quiver: a slotted damaging card deals +2; T::fire_quiver: a slotted Slash that hits applies 1 burn_stacks |
| frankensteins_screws | item | CORRECT | — | — | T::frankensteins_screws: a summon below 25% beside you heals 3; T::its_alive costs 20 mana, 5 tempo as its item says |
| friendship_ring | item | CORRECT | — | — | T::friendship_ring: heals are 5 larger |
| frost_book | item | CORRECT | — | — | T::frost_book: an unslotted Slash applies 1 cold_stacks |
| frost_quiver | item | CORRECT | — | — | T::frost_quiver: a slotted Draw gains you 2 armor; T::frost_quiver: a slotted Slash that hits applies 1 cold_stacks |
| gauntlets_of_dungeon_mastering | item | FIXED | A card in one of its plain (vanilla) slots also summoned a wolf: `main._helm_card_world_effects` read the riders straight off the item. | `main.gd`: the riders are read through the card (`Card.get_on_self_bonus`), so a plain slot stays neutral. Shared helper; see below. | T::gauntlets_of_dungeon_mastering: any slotted card summons a wolf, up to a pack of 3; T::gauntlets_of_dungeon_mastering: a plain-slot card summons no wolf; T::gauntlets_of_dungeon_mastering: a wolf with one packmate bites for +20% and 2 Bleed; T::House Rule puts the picked discard card in your hand |
| girdle_of_aphrodite | item | CORRECT | — | — | T::girdle_of_aphrodite: a slotted offensive card Taunts its target for 15 tempo; T::girdle_of_aphrodite: a slotted defense card heals its target 15; test_item_feedback |
| gold_band | item | CORRECT | — | — | T::gold_band: 10 shield gained -> two zaps of 2 |
| gravity_gauntlets | item | CORRECT | — | — | T::gravity_gauntlets: a slotted offensive card holds the target 5 tempo; T::gravity_gauntlets: an enemy 2 squares off is pulled into the target area |
| guardian_greaves | item | FIXED | "Restore 6 health … to all allies (you included) within 4": among summons, only Frankenstein's Monsters were healed. Wolves, skeletons, bows, worms and the penguin were skipped, though `main._all_summons` defines them as allies for card text. | `main.gd` `_helm_on_cycle_passives`: the aura heals every summon from `_all_summons()` within the radius. | T::guardian_greaves: an ally summon within 4 regains 6 too; T::guardian_greaves: you regain 6 health a cycle; T::guardian_greaves: and 5% physical resistance inside the aura |
| hallowed_trunk | item | FLAGGED | *(Phase 6 re-check)* Only armor taken by hits counts toward "every 10 armor removed"; the 2-per-cycle armor decay does not. Should decay count? | — | T::hallowed_trunk: the 10th armor point removed grants 1 Regen; T::hallowed_trunk: imbue tree grants 5 Regen and 10 Thorns |
| hammer_of_ajax | item | CORRECT | — | — | T::hammer_of_ajax: a slotted offensive card adds 10% of max health |
| hannibals_mask | item | CORRECT | — | — | T::hannibals_mask: a slotted attack heals 15% of its damage; T::hannibals_mask: Resourceful Replenish maintained — attacks lifesteal 5% |
| harnessed_sun | item | CORRECT | — | — | T::harnessed_sun: a 1-Burn application lands as 3 (+2); T::harnessed_sun: the 25th Burn cleanses a debuff on you |
| heal_stone | item | CORRECT | — | — | T::heal_stone: a heal of 5+ zaps an enemy for 2; T::heal_stone: lifesteal does not count; T::heal_stone: regen does not count |
| hermes_boots | item | CORRECT | — | — | T::hermes_boots: any slotted card restores 1 flash point; T::hermes_boots: a trap springing on an enemy deals 25% more |
| hide_of_garmr | item | CORRECT | — | — | T::hide_of_garmr: equipping gives exactly the described stats; T::ragnarok costs 45 mana, 5 tempo as its item says |
| holster | item | CORRECT | — | — | T::holster: a slotted damaging card deals +2 |
| horned_nasal_helm | item | CORRECT | — | — | T::horned_nasal_helm: a slotted Slash that hits applies 1 bleed_stacks; T::horned_nasal_helm: at 15 tempo 2 random debuffs are purged |
| houdinis_slippers | item | FIXED | A plain-slot card also made you invisible, for the same reason as Dungeon Mastering. | Same `main.gd` fix. | T::houdinis_slippers: any slotted card makes you invisible for 5 tempo; T::houdinis_slippers: a plain-slot card does not |
| ice_orb | item | CORRECT | — | — | T::ice_orb: an unslotted Slash applies 2 cold_stacks; T::ice_orb: an unslotted Slash deals +2 |
| jordan_1s | item | FIXED | "Below 50% enemy health": the bonus also fired at exactly 50% (+25 on any hit). | `enemy.gd`: `<` instead of `<=` at both sites (the damage preview and `take_damage`). | T::jordan_1s: at exactly 50% no bonus; T::jordan_1s: at 40% a 10 hit gains 0.5 x 60 = 30 |
| kettle_hat | item | CORRECT | — | — | T::kettle_hat: at 15 tempo, +2 unerring armor; T::kettle_hat: unequipping resets the counter; test_unerring_armor |
| knife_toed_boots | item | CORRECT | — | — | T::knife_toed_boots: a melee crit lands the multiplied hit +10; T::knife_toed_boots: a ranged card does not; T::knife_toed_boots: Shiv is a 2-damage melee card |
| laurentius_lost_spear | item | FLAGGED | Both granted Psionic Flows fire together on the first trigger, because `trigger_reactions` fires every matching instant in hand. See the question below. | — | T::laurentius_lost_spear: a slotted self-target card may target an ally; T::laurentius_lost_spear: Psionic Flow adds 8 damage; T::laurentius_lost_spear: and shoves the target back 1 |
| leather_belt | item | CORRECT | — | — | T::leather_belt: a slotted damaging card deals +1 |
| leather_boots | item | CORRECT | — | — | T::leather_boots: equipping gives exactly the described stats |
| leather_cap | item | CORRECT | — | — | T::leather_cap: equipping gives exactly the described stats |
| leather_gauntlets | item | CORRECT | — | — | T::leather_gauntlets: equipping gives exactly the described stats |
| legend_has_it | item | CORRECT | — | — | T::legend_has_it: a 100 hit lands 5 lighter |
| lions_halberd | item | CORRECT | — | — | T::lions_halberd: a slotted damaging card deals +10 |
| long_bow | item | FIXED | "3 card slots (2 bonus, 1 plain)": a card in the plain slot still got +2 range. `main._helm_range_bonus` read the riders off the item. | `main.gd` `_helm_range_bonus` reads them through the card. | T::long_bow: a slotted offensive card gains +2 range; T::long_bow: a slotted damaging card deals +2 |
| magic_staff | item | CORRECT | — | — | T::magic_staff: an unslotted Slash deals +4; T::magic_staff / reaper_scythe: two-handed |
| mail_coif | item | CORRECT | — | — | T::mail_coif: at 15 tempo, +5 unerring armor |
| mane_of_narashimha | item | CORRECT | — | — | T::mane_of_narashimha: your hit lands 5% harder in the aura; T::mane_of_narashimha: 3 squares off, out of the aura |
| marvolo_gaunt | item | FIXED | In single player the save never applied "Marvolo's Misunderstanding deals 25 damage after 7 tempo unless purged": only Player 2 was connected to `marvolo_triggered`. | `main.gd`: Player 1 is wired through `_wire_marvolo_hooks` as well. This replaces P1's unbound `debuff_expired` connection and its `_wire_dot_log` call, which `_wire_marvolo_hooks` also makes. | T::marvolo_gaunt: Marvolo's Misunderstanding — 25 damage in 7 tempo; T::marvolo_gaunt: left alone it lands for 25; T::marvolo_gaunt: purged, the Misunderstanding deals nothing; test_rings_pass |
| mauls_sabre | item | CORRECT | — | — | T::mauls_sabre: blue slot +5 damage, 1 Weaken, +8 block; T::mauls_sabre: red slot +15 damage; T::mauls_sabre: blue right after red also applies 1 Vulnerable; test_weapons_pass (red after blue: -1 tempo) |
| medic_wraps | item | CORRECT | — | — | T::medic_wraps: heals 5 and gains 3 armor; T::Medic Wraps: 15 tempo cooldown |
| megingjord | item | CORRECT | — | — | T::megingjord: a slotted card costs double mana; T::megingjord: any card, not only damaging ones; test_item_feedback (the whole hit is doubled) |
| mits_of_chingiz | item | CORRECT | — | — | T::mits_of_chingiz: the second offensive card in a row adds a Switch Kick; T::mits_of_chingiz: then a 20 tempo cooldown |
| momentum_mits | item | CORRECT | — | — | T::momentum_mits: any slotted card draws you a card; T::momentum_mits: Continue to move draws a card |
| monocle | item | FIXED | A card in its plain slot still got the +5 range (same `_helm_range_bonus` cause as Long Bow). | Same `main.gd` fix. | T::monocle: a slotted ranged offensive card gains +5 range; T::monocle: a card in its plain slot gains no range; T::monocle: a slotted ranged offensive card resolves with +25% crit; T::monocle: 20/20 maintained gives ranged offensive cards +3 range |
| mountain_boots | item | CORRECT | — | — | T::mountain_boots: an offensive card from high ground deals 20% more; T::mountain_boots: a damaging non-offensive card gets nothing |
| nine_ruins_of_sanguine | item | FLAGGED | "can be hit (even by you)" is not implemented: player cards cannot target the penguin, and the player's AoE skips him. The basic attack also builds no Vitality. See the questions below. | — | T::nine_ruins_of_sanguine: 3 Vitality: +6 attack damage; T::nine_ruins_of_sanguine: and 3% lifesteal; T::nine_ruins_of_sanguine: no Vitality while he lives; T::nine_ruins_of_sanguine: damage he takes heals you half; test_item_feedback (the 5-tempo window) |
| orions_belt | item | CORRECT | — | — | T::orions_belt: granted [...] are in the deck |
| pick | item | CORRECT | — | — | T::pick: a slotted damaging card deals +5 |
| pocket_knife | item | CORRECT | — | — | T::pocket_knife: a DEX-proc'd 7-tempo attack takes 3 - 2 = 1 tempo and resolves on tick 1 |
| poseidons_trident | item | CORRECT | — | — | T::poseidons_trident: the square behind the target takes the same hit; T::poseidons_trident: a third square is out of reach |
| potion_belt | item | CORRECT | — | — | T::potion_belt: a slotted utility card costs 1 less tempo; T::potion_belt: granted [...] are in the deck |
| presence_of_mind | item | CORRECT | — | — | T::presence_of_mind: a slotted Block gains 10% of max mana as extra block; T::presence_of_mind: any card gets it |
| quiver_of_wet_stones | item | CORRECT | — | — | T::quiver_of_wet_stones: a slotted hit strips 4 extra armor on top of its +2 |
| reaction_rod | item | CORRECT | — | — | T::reaction_rod: an enemy striking from melee takes 4 Shock; T::grounding costs 200 mana, 10 tempo as its item says |
| reaper_scythe | item | CORRECT | — | — | T::reaper_scythe: above half health, 10% lifesteal; T::reaper_scythe: below half, 10% of the damage returns as mana; T::reaper_scythe: a card aimed below half costs 10% less |
| return_scroll | item | CORRECT | — | — | T::return_scroll: right-clicking it opens a portal; test_town_portal_return (walk in, twin in town, closes once used) |
| ring_of_nibelung | item | CORRECT | — | — | T::ring_of_nibelung: the 5th heal brings the Curse carrying the healed total; T::ring_of_nibelung: only one copy can exist |
| ring_of_stone_hide | item | CORRECT | — | — | T::ring_of_stone_hide: a Block gives +4; T::ring_of_stone_hide: 100 block gained -> 10% resistance for 15 tempo |

## Flagged

- **laurentius_lost_spear**: "Grants 2 Psionic Flows (instant): … Whichever comes first." With both Flows in hand, the first attack (or the first hit on an ally) fires both at once: +16 damage and two shoves, or 16 healing. Should each copy be a separate charge, with one firing per trigger? Or is both firing together intended? `trigger_reactions` fires every matching instant in hand for every card, so a fix here would change instant rules game-wide.
- **nine_ruins_of_sanguine**:
  1. "can be hit (even by you)": nothing lets the player's cards or AoE strike Sanguine. Only enemies target him. Should player AoE include him, and should he be a valid target for offensive cards? This needs a targeting decision. BLOCKED: it is a new targeting rule, beyond a wiring fix.
  2. "Every attack grants 1 Vitality": Attack cards build Vitality, and spells correctly don't, but the basic attack (the Attack button) builds none. Does the basic attack count as "an attack" for Vitality? The same question applies to Fallen's Wrath's "your attacks deal +Wrath damage", which the basic attack also doesn't get.

## Notes (no status change)

- **Gauntlet skill mana costs missing from the text.** Some descriptions leave the skill's mana cost out, though the code charges it (tested): Dungeon Mastering's House Rule costs 15, Medic Wraps' Slurp and pad 10, Hallowed Trunk's imbue tree 20, and Momentum Mits' Continue to move 10.
- **Jordan 1s and Mane auras refresh once per cycle.** The aura is stamped on enemies at each cycle. After the boots or helm are equipped or removed, the change shows up within 5 tempo, not at once. The text doesn't promise "at once".
- **Mend (Guardian Greaves' card) still heals only Frankenstein's Monsters among summons** (`main.gd` near `mend_pct`). That code belongs to the card, so it's left for the card slice. It is the same gap as the aura fix above.
- **Shared helper touched: `main._helm_range_bonus` and `main._helm_card_world_effects`.** They now read `card.get_on_self_bonus()`, which is neutral in a plain slot, not `card.slotted_in_item.get_on_self_bonus()`. This changes every item whose range, wolf, invisibility, Shamans-mask, Boot Holsters, Slotted Sash, Tactical belt or Shadow Cowl rider sits in a plain slot. That is the documented rule ("plain slots carry none").
- **Shared code touched: `PlayerStats.hit_multiplier`.** The new `hit_multiplier_rebound` and `hit_multiplier_extra` sit beside it, and `Card.close_play_scope` and the bare-execute cleanup now call `Card.pay_overdrive_rebound`. Megingjörð's behaviour is unchanged (its rebound share is 0).
