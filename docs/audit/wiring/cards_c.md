# Wiring audit: cards, slice C

51 cards, Heavy Swing to Poison Bomb. Each card's `description` (its `.tres`) was checked against what actually runs: `Card._execute_card` in `scripts/cards/card.gd`, the card's branch in `Main._apply_card_world_effects` and the trigger sites in `scripts/core/main.gd`, and `DeckManager.play_card`.

**The test.** All checks are in `tests/test_wiring_cards_c.gd`. It boots `main.tscn` as the dojo (Brad) and finishes in about 15 seconds. The innate 5% crit is cancelled during the run so that damage numbers are exact.

**Costs.** Every playable card is played through the real input path: `Main.select_card`, then `play_selected_card`, then the tick clock is drained. Each one charges exactly the `mana_cost` and `tempo_cost` in its `.tres`, and Mind Mend also charges its 15 health. Five cards rely on the default `tempo_cost = 4` because their `.tres` leaves the field out: Lethal Recall, Life Swap, Mend, Oops and Monk of the Night. The five unplayable or instant cards are refused from the hand.

**Effects.** Each card's effect is resolved through `Main._resolve_queued_card`, the same entry the tick clock calls, or through the card's real trigger site.

**Heals.** "Heal X" numbers run through `PlayerStats.heal`, which adds the INT and healing-gear bonus (`get_effective_heal_amount`). Damage numbers are scaled the same way, by STR or INT. This applies to every heal in the game, so it is not counted as a mismatch for Hope This Works, Life Steal or Mend.

| name | type | status | what was wrong | what changed | test name |
|---|---|---|---|---|---|
| Heavy Swing | card | CORRECT | — | — | test_wiring_cards_c.gd::Heavy Swing is refused while a non-offensive card (Block) is in hand; ::with only offensive cards beside it, it deals 20 (+STR); ::heavy_swing: played for its 30 mana / 3 tempo |
| Hemotoxins | card | CORRECT | — | — | test_wiring_cards_c.gd::Hemotoxins: 10 Poison on a healthy target; ::…20 Poison on a target below 50% health |
| Heroic Leap | card | CORRECT | — | — | test_wiring_cards_c.gd::Heroic Leap jumps STR (3) tiles; ::…and the landing hits for damage from the distance; ::a 1-tile hop deals less than the full leap |
| Hold the Line | card | CORRECT | — | — | test_wiring_cards_c.gd::Hold the Line: +5 armor; ::…+2 DET; ::…+2 STR (Might) for 15 tempo; ::…on every ally, not only you |
| Hope This Works | card | FLAGGED | "Provide STR for 3 attacks" is built as Strengthen +2 damage for the next 3 attacks. It is not +STR, and the text gives no amount. The heal, the 50% roll and ally targeting work. | — | test_wiring_cards_c.gd::Hope This Works (success): heals the ally 5 (+INT); ::…and Strengthens their next 3 attacks; ::…(fail) does nothing; ::…aimed at an ally, the ally is healed and strengthened, not the caster |
| House Money | card | CORRECT | — | — | test_wiring_cards_c.gd::House Money: the next odds are boosted to certain; ::…the chance card in hand re-rolls and triggers; ::…a multi-outcome card lands its best outcome |
| Huck | card | CORRECT | — | — | test_wiring_cards_c.gd::Huck: deals your armor (30) and you lose all of it |
| Hunker Down | card | CORRECT | — | — | test_wiring_cards_c.gd::Hunker Down: Fortify for 30 tempo |
| Ice Grenade | card | CORRECT | — | — | test_wiring_cards_c.gd::Ice Grenade: 5 damage (+INT) within 2 squares of the aim; ::…2 Cold on each enemy hit; ::…two shots: the grenade stays in hand after the first; ::…the second, aimed separately, lands where it is aimed and spends the card |
| If Pigs Could Fly | card | CORRECT | — | — | test_wiring_cards_c.gd::If Pigs Could Fly: 15 to the target and the area around it; ::…the area is INT/8 wide (INT 16: the next tile only) |
| Improvised Ammo | card | CORRECT | — | — | test_wiring_cards_c.gd::Improvised Ammo: 8 damage and 3 Weaken; ::…discarded: 4 damage to the nearest enemy; ::…and Improvised Ammo gains +10% crit; ::…permanently (saved with the character) |
| Infest | card | CORRECT | — | — | test_wiring_cards_c.gd::…hatches at 5 tempo in hand; ::…played (50 mana, 0 tempo) it is erased; ::…discarded it is erased and never hatches; the 2 Wererats: tests/test_rat_king_infest.gd |
| Internal Combustion | card | CORRECT | — | — | test_wiring_cards_c.gd::Internal Combustion: removes half your armor; ::…and deals that much around you |
| Item Mastery | card | CORRECT | — | — | test_wiring_cards_c.gd::Item Mastery: a card an item grants comes to hand; ::…and a card slotted in an item; ::…but no plain deck card |
| ITS ALIVE!!!!! | card | CORRECT | — | — | test_wiring_cards_c.gd::ITS ALIVE: the nearby corpse rises as Frankensteins Monster |
| Lady Luck | card | CORRECT | — | — | test_wiring_cards_c.gd::Lady Luck: the blessed ally gets +30% crit for 5 attacks; ::…aimed at an ally, the ally is blessed |
| Last Breath | card | FLAGGED | The text says "3 damage per mana spent". The code deals 3 per **10** mana (`mana * 0.3`), and its comment says this keeps the feel from before the x10 mana rescale. The HUD shows raw mana (for example 50/50), so the text no longer matches what the player sees. Consuming all mana works. | — | test_wiring_cards_c.gd::Last Breath consumes all remaining mana; ::…3 damage per 10 mana (x10 scale): 40 mana → 12 (+STR) |
| Lead Arrow | card | CORRECT | — | — | test_wiring_cards_c.gd::Lead Arrow: 1.8x damage; ::…clicking an enemy from flat ground does not fire it; ::(control: the same click fires Mixed Bag) |
| Lethal Recall | card | CORRECT | — | — | test_wiring_cards_c.gd::Lethal Recall: the last instant's effect triggers 2 more times |
| Life Steal | card | CORRECT | — | — | test_wiring_cards_c.gd::…the next attack heals for the damage it did (+INT, the heal pipeline); ::…once |
| Life Swap | card | FLAGGED | The text says "1 mana = 1 HP". The code exchanges 10 mana for 1 HP (the x10 rescale), and the HUD shows raw mana. The swap and the strike on the enemy in melee range work. | — | test_wiring_cards_c.gd::Life Swap: HP and mana pools exchange at 10 mana = 1 HP; ::…the HP lost (280) hits the enemy in melee range |
| Lightly Dazed | card | CORRECT | — | — | test_wiring_cards_c.gd::Lightly Dazed: Linger — joins a full hand; ::…erased after 40; ::lightly_dazed cannot be played from hand |
| Living Armor | card | CORRECT | — | — | test_wiring_cards_c.gd::Living Armor: Regen back up to the Fortify's number (3); ::…and never past it |
| Loaded Die | card | CORRECT | — | — | test_wiring_cards_c.gd::Loaded Die: the next chance card is +10%; ::…spent by the next card with a probability |
| M for Mini | card | CORRECT | — | — | test_wiring_cards_c.gd::M for Mini: 2 Vulnerable and 2 Weaken |
| Mage Shield | card | CORRECT | — | — | test_wiring_cards_c.gd::Mage Shield: taking damage fires it for 10 block |
| Magic Barrier | card | CORRECT | — | — | test_wiring_cards_c.gd::Magic Barrier: an incoming attack fires it for 8 armor; ::…and it is consumed (erased) |
| Mana Surge | card | FLAGGED | The text says "gain 1 mana". The code gives 10 mana (`gain_mana(10)`), which is 1 mana on the scale used before the x10 rescale. The HUD shows raw mana, so the player sees +10. The 5 damage and Erase work. | — | test_wiring_cards_c.gd::Mana Surge: 5 damage; ::…erased after play; ::…gains 10 mana on the x10 scale (text: 'gain 1 mana') |
| Mark | card | FLAGGED | The text says "extra damage from your **attacks**". The code raises **every** player hit by 15%, including spells (shown with Fireball), and any `take_damage(x, true)`. CARD_TAXONOMY treats "attack" as the Attack shape. The 15% and the 25 tempo work. | — | test_wiring_cards_c.gd::Mark: 25 tempo; ::…your hits on it land 15% harder; ::…and it wears off after 25 tempo; ::…(as built, a spell's hit is marked up too) |
| Meditate | card | CORRECT | — | — | test_wiring_cards_c.gd::Meditate: discards the hand and draws to full -2; ::…heals to 80%; ::…Glut 5 |
| Meister of Faustmesser | card | CORRECT | — | — | test_wiring_cards_c.gd::Meister of Faustmesser: zero-cost cards in the discard pile come to hand, others stay; ::…and the card is jailed for 20. (The hand cap still applies, as it does to every non-Linger card.) |
| Mend | card | FIXED | *(Phase 6 re-check)* Only heroes and Frankenstein's Monsters were restored; wolves, skeletons, worms, spirit bows, clones and the penguin in range got nothing. | Every friendly summon within 4 is restored (as Halo and the Greaves aura already were). | test_recheck_fixes.gd::Mend; test_wiring_cards_c.gd::Mend: 20% health (+INT) and 20% mana restored; ::…and armor equal to the health restored; ::…an ally within 4 squares too; ::…not one 6 squares away. (Of the summons, only Frankensteins are healed.) |
| Mind Mend | card | CORRECT | — | — | test_wiring_cards_c.gd::Mind Mend: costs 15 health, no mana; ::…restores 60 mana |
| Mind over Matter | card | CORRECT | — | — | test_wiring_cards_c.gd::Mind over Matter: the next hit is halved and paid in mana, 1 per point; ::…only the next hit; also tests/test_shields_pass.gd |
| Minor Wounds | card | CORRECT | — | — | test_wiring_cards_c.gd::Minor Wounds: 2 damage to self on draw; ::…Erase 40 |
| Mirror Mirror | card | CORRECT | — | — | test_wiring_cards_c.gd::Mirror Mirror: the chosen card is duplicated into the hand; ::…the duplicate has Erase 5 |
| Misery Loves Company | card | FLAGGED | The text says "your next AOE **attack**". The code fires on the next AOE of any kind, spells included: Ice Grenade, Poison Bomb, Fireball and Internal Combustion all call `_apply_misery_spread`. Spreading the debuffs (theirs and yours) works once. | — | test_wiring_cards_c.gd::Misery Loves Company: the next AOE spreads a hit enemy's debuff to every enemy hit; ::…and your own debuffs too; ::…once |
| Mixed Bag | card | CORRECT | — | — | test_wiring_cards_c.gd::Mixed Bag: a standard ranged arrow |
| Monk of the Night | card | CORRECT | — | — | test_wiring_cards_c.gd::Monk of the Night: maintained (50 mana held); ::…an attack grants 10% of its damage as block; ::…a spell does not |
| Morphine | card | FLAGGED | The text says "After 15 tempo, lose it and take 2 damage". The 2 damage lands at exactly 15 tempo (the buff's own timer). The 4 temp HP sit in the shared temp-HP pool, though, and that pool counts down 5 per **cycle** (`PlayerStats.process_turn`). So the temp HP goes at the third cycle boundary, anywhere from 11 to 15 tempo after the play. | — (fixing it means changing the shared temp-HP clock, and `test_coop_status_ticks.gd` asserts the cycle clock) | test_wiring_cards_c.gd::Morphine: +4 temp HP; ::…the temp HP goes on the third cycle boundary, 11-15 tempo; ::…then you take 2 damage |
| Multishot | card | CORRECT | — | — | test_wiring_cards_c.gd::Multishot: 7 damage 3 times; ::…Glut 5; ::…each hit gains 10% crit chance |
| Negotiate | card | CORRECT | — | — | test_wiring_cards_c.gd::Negotiate: steal 5 gold |
| Neither Man nor Beast | card | CORRECT | — | — (the comment on `_execute_neither_man_nor_beast` says "5 base damage", but the code reads `base_damage` = 10; left alone to avoid touching card.gd) | test_wiring_cards_c.gd::Neither Man nor Beast: 10 damage through armor and resistance; ::…the target cannot heal it back; ::…after 10 tempo it can |
| Oops | card | CORRECT | — | — | test_wiring_cards_c.gd::Oops outcome 0: 5 hits of 3; ::Oops outcome 1: 3 hits of 3; ::Oops outcome 2: 2 hits of 3; ::…30% / 40% / 30% |
| Out of Guesses | card | CORRECT | — | — | test_wiring_cards_c.gd::Out of Guesses: discards the hand and draws that many; ::…the old hand is in the discard pile |
| Paralysis | card | CORRECT | — | — | test_wiring_cards_c.gd::Paralysis: you cannot move while it is in hand; ::…play it (10 mana, 5 tempo) to tear it free — it is gone; ::…and you can move again |
| Parry | card | CORRECT | — | — | test_wiring_cards_c.gd::Parry: 5 armor, 5 damage; ::…10% physical resistance for 1 attack |
| Patience | card | CORRECT | — | — | test_wiring_cards_c.gd::Patience: the draw is due 15 tempo after the play; ::…in 15 tempo, draw 3 |
| Peshtigo's Kiss | card | CORRECT | — | — | tests/test_peshtigo_live.gd (hits for 10 + 5 per enemy in the INT/8 circle, asks to Maintain, burns for half every cycle, goes out when dismissed); test_wiring_cards_c.gd::peshtigos_kiss: played for its 60 mana / 5 tempo |
| Petey the Pet Rock | card | FIXED | *(Phase 6 re-check)* The Slowed went on only at a 5-tempo cycle boundary, only when none was there, so it fell to 1 stack between cycles, and nothing lifted it when Petey left the hand. | `main._sync_held_slow`: put on when drawn, topped back to 2 each cycle, lifted with the last copy (mirrors Release Soul's Drain). | test_recheck_fixes.gd::Petey; test_wiring_cards_c.gd::Petey: on draw, draw 3 cards; ::…while in hand: Slowed 2; ::…on discard: discard 2 cards |
| Poison Bomb | card | CORRECT | — | — | test_wiring_cards_c.gd::Poison Bomb: 6 Poison on every enemy within 2 squares; ::…none 3 squares out |

The cost table also covers every playable card above: `test_wiring_cards_c.gd::<id>: played for its M mana / T tempo`. Lightly Dazed, Minor Wounds, Petey, Mage Shield and Magic Barrier are covered by `::<id> cannot be played from hand (unplayable / instant)`.

## Flagged

- **Mana Surge, Last Breath, Life Swap.** Mana numbers in these texts are still on the scale used before the x10 rescale. The code was rescaled on purpose, and the HUD and card badges show raw mana. Should the text change to "gain 10 mana", "3 damage per 10 mana" and "10 mana = 1 HP"? Or should the code follow the text as written: 1 mana, 3 per mana, 1:1?
- **Hope This Works.** For "provide STR for 3 attacks", should it be the Strengthen it is now (+2 damage on the next 3 attacks) or +STR? And how much: is 2 right?
- **Mark.** "Extra damage from your attacks": should the +15% apply only to the Attack shape (`is_attack()`), or to every hit you deal as now (spells, AoE splashes, summons that pass `from_player`)?
- **Misery Loves Company.** "Your next AOE attack": should an AoE spell (Ice Grenade, Poison Bomb, Fireball, Internal Combustion) spend and spread it as now, or only an AoE attack?
- **Morphine.** The 4 temp HP can run out 1 to 4 tempo before the stated 15, because temp HP is counted per cycle. Should temp HP tick on raw tempo? That is a shared change to `PlayerStats.process_turn` / `process_tempo` and to `test_coop_status_ticks.gd`. Or should Morphine take its temp HP back itself when its buff ends?
