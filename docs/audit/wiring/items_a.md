# Wiring audit — items, slice A

The 63 items `abjurers_cane` … `elvish_cloak`, each checked against its level-1 `description` in `data/items/<id>.tres`. All checks live in `tests/test_wiring_items_a.gd`. That file boots `main.tscn` as the dojo (Brad) and equips every item through the real `Inventory`. It runs three checks on every item:

- **Stats.** Each stat the text names moves by exactly that number on equip and comes back on unequip. The check message is `<id>: stats match its text`.
- **Granted cards.** The exact cards the text names reach the deck and leave with the item (`<id> grants [...]`). Where the item text quotes a granted card's mana, tempo or damage, the card data is checked against it.
- **Riders.** Each described rider is run through its real consumer: `Card.execute`, `DeckManager.compute_play_cost`, `Inventory.process_turn`, or main's world effects and hooks.

The behaviour of a granted card itself belongs to the card slices. Here the item is held to granting the right card at the quoted numbers. Level-2 and level-3 texts are out of scope; existing pass tests cover some of them.

T = `tests/test_wiring_items_a.gd`

| name | type | status | what was wrong | what changed | test name |
|---|---|---|---|---|---|
| abjurers_cane | item | CORRECT | — (note: an instant firing from hand also counts as a discard for the +3 block, as `trigger_reactions` emits `non_play_discard`) | — | T::Abjurers Cane: discarding a card grants 3 block; T::abjurers_cane is two-handed (its text says so); T::abjurers_cane grants ["defensive_sacrifice", "defensive_sacrifice"] |
| adimantium | item | CORRECT | — | — | T::Adimantium: an attack slotted in it gains 8 armor; T::Adimantium: each tile costs 1 extra tempo while worn; T::adimantium_wall: 35m / 4t, block 40; tests/test_chest_pass.gd (Adimantium: +10 armor when Exposed, cooldown armed (15 cycles)) |
| alchemeist_belt | item | CORRECT | — | — | T::Alchemeist belt: a 5-heal card heals 5 + 4% of max health; T::hemotoxins: 50m / 5t |
| armor_chopper | item | CORRECT | — | — | T::Armor Chopper: a melee attack card strips 10 more armor; tests/test_item_feedback.gd (auto attack shred) |
| assasian_belt | item | CORRECT | — | — | T::Assasian Belt: a slotted attack that hits applies 1 Vulnerable; T::assasian_belt grants ["shuriken", "shuriken"] |
| axes_axe | item | CORRECT | — | — | T::axes_axe: stats match its text; T::axes_axe grants ["death_vortex", "death_vortex", "death_vortex"]; tests/test_weapons_pass.gd (Axe's Axe banks 5 flash past the cap) |
| band_of_aid | item | CORRECT | — | — | T::Band of Aid: a slotted card that doesn't heal heals you 1 (+INT bonus); T::Band of Aid: a slotted 5-heal card heals 6 (+INT bonus) |
| baseball_hat | item | CORRECT | — | — | T::baseball_hat: stats match its text |
| belt_of_scrolls | item | CORRECT | — | — | T::belt_of_scrolls grants ["chain_lightning", "fire_punch", "ice_grenade"] |
| belt_of_wumbology | item | CORRECT | — | — | T::Belt of Wumbology: any slotted card grants Strengthen 10 for 2 attacks; T::m_for_mini: 15m / 2t |
| belthronding | item | CORRECT | — | — | T::Belthronding: four slotted plays leave 3 Close is Favored in hand; T::balistic_arrow: 75m / 5t, base_damage 30; tests/test_item_feedback.gd (Belthronding share: 10% within 3) |
| bessy | item | FLAGGED | The +25% vs Weakened is 25% of the card's base + flat bonuses before stat (STR) scaling, so it is well under 25% of the actual hit: +2 on a 161-damage Slash at high STR. | — | T::Bessy: a slotted attack on a Weakened enemy hits harder; T::Bessy: the attack-speed threshold is 5 higher while wielded; T::earth_rattle: 60m / 6t |
| bladed_doughnut | item | CORRECT | — | — | T::bladed_doughnut: stats match its text; tests/test_bladed_doughnut.gd (kill with doughnut equipped -> Sprinkle conjured into hand) |
| blast_stick | item | CORRECT | — | — | T::Blast Stick: an offensive spell costs 10% more; T::Blast Stick: +20% of the 88-mana cost as damage; T::blast_stick is two-handed |
| blink_boots | item | CORRECT | — | — | T::blink_boots grants ["blink", "blink"] |
| bloodbound_plate | item | FLAGGED | "+3 armor" has no consumer. `armor_bonus` is read only as a shield's Basic Block amount, so on a chest it does nothing. The "+2 on every armor gain" part works. | — | T::Bloodbound Plate: gaining 5 armor gains 7; T::Bloodbound Plate: '+3 armor' is data only — equipping it grants no armor (flagged) |
| blue_robe | item | CORRECT | — | — | T::blue_robe: stats match its text; tests/test_item_feedback.gd (a slotted Slash on a physical-resister lands as fire, unresisted) |
| boomerang | item | FLAGGED | The text says it "pairs with a quiver", but the 2026-10-25 ruling allows a quiver only beside a bow, so equipping a quiver next to the boomerang is refused. | — | T::Boomerang: a quiver is refused beside it (flagged: text says it pairs with one); tests/test_ranged_pass.gd (a quiver is refused beside the boomerang) |
| boot_holsters | item | FIXED | "If an instant, deal 10 damage to the nearest enemy within 3" never fired. The rider sat in `_helm_card_world_effects`, which runs only for played cards, and instants fire from the hand. Separately, cards in its plain slot read the item's riders (see dragon_skull). | The rider moved to `main._slotted_instant_fired`, hooked on `deck_manager.reaction_triggered` (emitted however an instant fires). It reads `card.get_on_self_bonus()`, so a plain slot gets nothing. | T::Boot Holsters: a slotted instant firing deals 10 to the nearest enemy within 3; T::Boot Holsters: an instant in the plain slot deals nothing; T::Boot Holsters: a slotted attack costs 1 less tempo |
| boots_of_speed | item | CORRECT | — | — | T::Boots of Speed: after 36 flash spent moving, a hand card loses 1 tempo |
| boots_of_the_balancer | item | CORRECT | — | — | T::Boots of the Balancer: +20 armor at 4 steps missing; T::boots_of_the_balancer grants ["tight_rope"] |
| bow_of_arash | item | CORRECT | — | — | T::Bow of Arash: a ranged offensive card gains 2 range; T::Bow of Arash: a slotted card pays half its 80 mana as life; T::territorial_mark: 45m / 5t, health_cost 35; T::Territorial Mark: range 10 |
| bow_of_budding_blasts | item | CORRECT | — | — | T::Budding Blasts: buds cap at 4; T::a bud: 6 damage every 5 tempo, 2 shots; T::a bud dies to any damage; T::Budding Blasts: a slotted attack gains +2 per living bow; T::Budding Blasts: a crit with a slotted attack buds a bow; T::spirit_bow: 65m / 3t |
| brass_knuckles | item | CORRECT | — | — | T::Brass Knuckles: a melee offensive card deals +2; T::Brass Knuckles: 1 unerring armor at 20 tempo |
| briarhide_plate | item | CORRECT | — | — | T::briarhide_plate: stats match its text; T::vined_encasing: 50m / 4t; tests/test_chest_pass.gd (Briarhide exposed armor) |
| brown_boots | item | CORRECT | — | — | T::brown_boots: stats match its text |
| buckler | item | CORRECT | — | — | T::Buckler: a 20 hit lands 3 lighter |
| buffed_leather | item | CORRECT | — | — | T::buffed_leather: stats match its text |
| burgonet | item | CORRECT | — | — | T::burgonet: 2 unerring armor every 5 tempo; T::burgonet: the counter resets when unequipped |
| capacious_extremus | item | CORRECT | — | — | T::Capacious Extremus: a slotted card costs 10% less; T::Capacious Extremus: 5 slots, 4 bonus and 1 plain |
| captain_planets_circlet | item | CORRECT | — (note: with a 4-card hand the payout of draw 3 plus Fireball plus Rise overflows, and a full hand turns cards away) | — | T::Captain Planet: all five heal 15; T::Captain Planet: draw 3 and add a Fireball and a Rise; T::Captain Planet: the conjured pair carries Erase 10 |
| car_battery | item | CORRECT | — | — | T::Car Battery: a slotted attack applies 3 Shock; T::Car Battery: a card in the plain slot applies none; T::car_battery is two-handed |
| caster_boots | item | CORRECT | — | — | T::Caster Boots: a slotted damaging card deals +10% of INT |
| castle_wall | item | CORRECT | — | — | T::Castle wall: hand size 3 smaller; T::Castle wall: a slotted block card blocks 8 more; T::huck: 100m / 5t; tests/test_overdraw_riders.gd, tests/test_shields_pass.gd (Overdraw heal + Rain of Arrows, 3 charges, one per 15 tempo) |
| chain_crocs | item | CORRECT | — | — | T::Chain Crocs: a slotted card costs 20% less; T::chain_crocs: 5 unerring armor every 15 tempo |
| chain_gloves | item | CORRECT | — (note: the text omits Guard's 5-mana cost) | — | T::chain_gloves: 1 unerring armor every 15 tempo; T::Chain Gloves: Guard gains 2 armor; T::chain_gloves: ready again after 20 tempo |
| chain_mail | item | CORRECT | — | — | T::chain_mail: 8 unerring armor every 15 tempo; T::chain_mail: the grant stops at the unerring cap; T::clang_up: 20m / 5t, block 10 |
| chewbaccas_bandolier | item | CORRECT | — | — | T::Chewbaccas: a slotted ranged attack costs 1 less tempo; T::Chewbaccas: a slotted ranged attack deals +5; T::Chewbaccas: after 5 tempo it explodes for 8; T::Chewbaccas: an enemy stepping on it sets it off at once; T::Chewbaccas: the casing never hurts you |
| circes_wand_of_cauldron_stirring | item | CORRECT | — | — | T::Circe's Wand: an attack (slotted or not) Silences 5 tempo; T::circes_wand_of_cauldron_stirring grants ["polymorph", "polymorph"] |
| cloth_bracer | item | CORRECT | — (note: the text omits Band aid's 10-mana cost) | — | T::Cloth bracer: Band aid heals 5 (+INT bonus); T::cloth_bracer: ready again after 20 tempo; T::cloth_bracer: stats match its text |
| cloth_slippers | item | CORRECT | — | — | T::cloth_slippers: stats match its text |
| coffin_lid | item | CORRECT | — | — | T::Coffin Lid: a slotted attack heals 10% of its 159 damage; T::Coffin Lid: below half health, +8% lifesteal; T::curse_of_the_living: 65m / 7t |
| concealed_carry | item | CORRECT | — | — | T::Concealed Carry: Lethal Poke is a 0-base melee hit; T::Concealed Carry: a Lethal Poke crit deals x1.5 on top of the crit; T::concealed_carry: ready again after 15 tempo; T::concealed_carry grants ["smoke_bomb"] |
| construction_hammer | item | CORRECT | — | — | T::construction_hammer grants ["hard_helmet"]; T::hard_helmet is an instant |
| copper_bracers | item | CORRECT | — | — | T::Copper Bracers: Clang gains 8 armor for 25 mana; T::copper_bracers: ready again after 15 tempo |
| corset_of_cure | item | FIXED | Two bugs in the cleanse. (1) It subtracted 3 from `Debuff.stacks`, which counts applications and is almost always 1, so it removed the whole debuff instead of 3 stacks; the stack count lives in `value`. (2) A slotted card with no target (an instant firing, an untargeted play) errored out of `Card._execute_card` on `null.has_method`, skipping the rest of the play's cleanup. | `card.gd`: the cleanse takes 3 off `value` (removing the debuff at 0) and is guarded against a null target. | T::Corset of Cure: a slotted card aimed at you cleanses 3 stacks; T::Corset of Cure: a slotted card with no target resolves cleanly (no error mid-play); T::Corset of Cure: a debuff leaving you puts a Healing Tonic in hand; T::Healing Tonic: 0m/0t, range 5, heal 5 |
| crooked_dueling_shield | item | CORRECT | — | — | T::Crooked: the blue card applies 1 Weaken; T::Crooked: the red card applies 1 Vulnerable; T::Crooked: red right after blue gains 10 armor; T::Crooked: a fully blocked attack Weakens the attacker 2; T::Crooked: blocking an already-Weakened attacker deals 5; tests/test_shields_pass.gd (crit riders) |
| cross_bow | item | CORRECT | — | — | T::cross_bow: stats match its text; T::cross_bow (a bow) needs both hands |
| cuffs_of_current | item | CORRECT | — | — | T::Cuffs of Current: a free draw on the 3rd cycle; T::Cuffs of Current: Zeet deals INT/2 for 35 mana; T::cuffs_of_current: ready again after 15 tempo |
| cupids_bow | item | CORRECT | — | — | T::cupids_bow grants ["cupids_golden_arrow", "cupids_lead_arrow"]; T::cupids_golden_arrow: 45m / 3t, base_damage 10; T::cupids_lead_arrow: 45m / 3t, base_damage 10 |
| cyclops_ring | item | CORRECT | — | — | T::Cyclops Ring: the third 25+ hit grants Strengthen 15 for 2 hits; T::Cyclops Ring: the two strengthened hits don't feed the counter |
| cyde_livingstons_sneakers | item | CORRECT | — | — | T::Cyde: the 5th consecutive attack draws a card; T::Cyde: a non-attack card breaks the streak; T::donate_cleats: 35m / 0t |
| delfins_deterministic_round_shield | item | CORRECT | — | — | T::Delfins: a 90% roll becomes 100% slotted; T::Delfins: Overdraw peaks the next 4 cards of the draw pile; T::mage_shield: 0m / 0t, block 10 |
| diamond_ring | item | CORRECT | — | — | T::Diamond Ring: a 100 hit lands as 97 |
| divine_resistance | item | CORRECT | — | — | T::Divine Resistance: 6% resist at 50% missing; T::preemptive_answer is an instant |
| dragon_skull | item | FIXED | A card in its plain (vanilla) slot still got "+1 range". `main._helm_range_bonus` read `slotted_in_item.get_on_self_bonus()` (the item's riders) instead of the card's own bonus, which is neutral in a plain slot. `_helm_card_world_effects` did the same. | Both read `card.get_on_self_bonus()`. This is a shared helper, so Monocle, Shamans mask, Tactical belt, Houdinis Slippers, Slotted Sash, Dungeon Mastering and Shadow Cowl get the same plain-slot rule. | T::Dragon Skull: any slotted offensive card gains 1 range; T::Dragon Skull: a card in the plain slot gains no range; T::Dragon Skull: a crit breathes 10 + INT/2 fire in the cone; T::Dragon Skull: the cone reaches 3 squares, not 5 |
| draupnir | item | CORRECT | — | — | T::Draupnir: the 9th hit drips a duplicate; T::Draupnir: the duplicate has a quarter of your health; T::Draupnir: swings every 7 tempo, moves 2 squares per 3 tempo; T::Draupnir: only one at a time; T::Draupnir: the duplicate dying grants Strengthen 10 for 2 attacks |
| dunce_cap | item | CORRECT | — | — | T::dunce_cap: stats match its text |
| earth_book | item | CORRECT | — (note: the on-self 3 armor makes any slotted card armor-granting, so the book's own +1 block rides it: 4 armor) | — | T::Earth Book: an offensive card deals +1; T::Earth Book: an armor-granting card grants +1 block; T::Earth Book: any slotted card gains you 3 armor (+1 from the book's own block bonus) |
| elemental_emblem | item | CORRECT | — | — | T::elemental_emblem: stats match its text; T::Elemental emblem is a shield with plain slots only |
| elemental_trail_blazers | item | CORRECT | — | — | T::Trail Blazers: a tempo move leaves no fire; T::Trail Blazers: a flash move leaves a fire spot (INT/5, 3 tempo); T::Trail Blazers: an enemy on it takes INT/5 and the fire goes out; T::Trail Blazers: it burns out at 3 tempo |
| elemental_weaver | item | CORRECT | — | — | T::Elemental Weaver: 3 Burn applied deals 3; T::Elemental Weaver: 2 Shock applied deals 2; T::elemental_weaver is two-handed; T::element_pollination is a Maintain |
| elvish_cloak | item | CORRECT | — | — | T::Elvish Cloak: a slotted ranged attack deals +2; T::Elvish Cloak: a slotted melee attack gains nothing |

**Counts:** 57 CORRECT, 3 FIXED, 0 MISSING, 3 FLAGGED.

## Flagged

- **bessy**: "Offensive cards deal +25% damage to Weakened enemies." The bonus is 25% of the card's base plus flat bonuses, computed before STR scaling, so on a stat-heavy hit it is a few points rather than a quarter more. Tigers Sunday Red and Purge Wrath use the same pre-scaling base; Megingjörð's multiplier is applied at the end. Should Bessy's +25% apply to the final hit, as Megingjörð's x2 does?
- **bloodbound_plate**: What should "+3 armor" do on a chest? Today nothing reads `armor_bonus` outside a shield's Basic Block. Possible meanings: 3 armor on equip, 3 armor at each battle start, or +3 to the unerring cap. Or should the text drop it?
- **boomerang**: The text says "a one-handed throwing arm; pairs with a quiver", but the 2026-10-25 ruling (`test_ranged_pass`) refuses quivers beside anything but a bow. Should the text change, or should the boomerang be the exception that takes a quiver?

## Notes for the designer (not flagged)

- Instants firing from the hand count as true discards (`trigger_reactions` emits `non_play_discard`), so they feed the Abjurers Cane's +3 block. Defensive Sacrifice alone is spent without counting.
- Every heal carries the INT heal bonus (`PlayerStats.get_effective_heal_amount`). Band of Aid's "heals you 1", Band aid's "heal 5" and Coffin Lid's drained life therefore all land a little higher than their raw number.
- The Cloth bracer and Chain Gloves texts omit their skill's mana cost (10 and 5).
