# New cards — batch D (attacks and small offensive / utility cards)

Behaviour lives in `scripts/cards/new_cards_d.gd` (`NewCardsD`); tests in
`tests/test_new_cards_d.gd`. Hooks in shared code: `Card._execute_card`
(one match branch → `NewCardsD.execute`), `main._apply_card_world_effects_inner`
(one match branch → `NewCardsD.world_effects`), `Card.clear_temp_mods` and the
end of main's world effects (→ `NewCardsD.end_feint`),
`DeckManager.tick_temp_mods` (→ `NewCardsD.tick_tithe`), `CardUI.setup`
(→ `NewCardsD.place_face_ticker`).

- **Berserker's Tithe** (`berserkers_tithe`) — Legendary · 0 mana, 6 tempo · Conditional (melee; ranged 5 and +1 tempo with a bow) · targets enemy · slots: Axe / Arrow · sheet: Attack
  - Card text: 12 damage. Glut 10. If this kills an enemy, it is shuffled into your draw pile and its tempo is halved; if not, it goes to your discard and its tempo is doubled. The tempo change lasts 40 tempo.
  - Code: `NewCardsD._tithe`: one hit through `Card._execute_slash` (12, STR scaling, Strengthen, crit), then `tithe_settle`. A kill takes the card out of the discard pile (where the play put it) and `shuffle_card_into_draw_pile`s it, with `tempo_cost = max(1, base / 2)` (6 → 3); no kill leaves it in the discard pile with `tempo_cost = base * 2` (12). The base is the card's own tempo, kept in card meta, so a replay while the effect lasts sets 3 or 12 again and restarts the 40 — it never compounds. `tick_tithe` (from `DeckManager.tick_temp_mods`, every tempo) counts the 40 down in the hand, draw pile, discard pile and jail; at 0 the card is back to 6. Glut 10 is the generic `glut_tempo`. The face shows `Tempo halved: N` / `Tempo doubled: N` on its bottom edge while the effect lasts (`NewCardsD.TempoTicker`, placed by `CardUI.setup`), and the hourglass number shows the changed tempo.
  - Mismatch / open question: "add it to your draw pile" is read as *shuffled in* (not placed on top). The 40 starts when the card resolves (its first tick), so the play's own remaining 5 tempo and the Glut come out of it. A Blind miss counts as "no kill" (doubled). A copy the Rapid Recurve jails after the play stays jailed on a kill. The countdown is not written to save files (a loaded card is back at 6). Card faces had no countdown readout to reuse (Erase fuses, hatch timers and Volatile Mixture are not drawn on the face on this branch), so the ticker is a new small label in the face's own label style.

- **Internal Sickness** (`internal_sickness`) — Legendary · 80 mana, 1 tempo · ranged 5 · targets enemy · slots: Dagger / Wand / Axe · sheet: Offensive
  - Card text: Deal 10 damage. If this kills an enemy, draw 2 and Jail this card for 15 tempo.
  - Code: `NewCardsD._internal_sickness`: one hit through `Card._execute_slash` (10, physical, STR scaling, crit). On a kill the card moves from the discard pile to the jail pile (`jail(15)`) and then the deck draws 2 (jailed first, so an empty draw pile cannot reshuffle it back in). Plain Offensive: not an attack and not a spell — Disarm and Silence pass it by, it does not tick the DEX counter, takes no Strengthen (only Circle of Life's offensive one) and fires no attack procs; offensive riders (Deadly, on-hit debuffs, Surprise Opener) do apply.
  - Mismatch / open question: the sheet gives no range — scaffolded as ranged 5. Jail clocks fall 5 per cycle, so "15 tempo" is 3 cycle ticks (11–15 tempo depending on where in the cycle the kill lands), like every other jail. Released, it goes to the discard pile (the engine's jail rule).

- **Fan of Knives** (`fan_of_knives`) — Rare · 65 mana, 8 tempo · ranged 2 · targets self · slots: Dagger / Pocket · sheet: Attack
  - Card text: Discard up to 5 cards. Each card discarded deals 4 damage to a random enemy within range 2.
  - Code: `NewCardsD._fan_of_knives` (world effects): when the card resolves, Crack of Mintaka's hand picker (`main.show_hand_multi_picker`) opens; the chosen cards (the first 5 if more are toggled) are discarded with `discard_card_from_hand`, so their on-discard effects fire. `_throw_knives` then rolls one hit per discarded card — `Card._roll_hit_damage(4)`: STR scaling, Strengthen (a charge per knife), its own crit — on a random living enemy inside the card's reach (`_is_target_in_card_range`, i.e. the range ring: 2 tiles straight-line plus range bonuses, line of sight), re-picked per knife. On-hit debuffs and the attack's life steal apply. Knives with no enemy in reach are lost; the discards are spent either way.
  - Mismatch / open question: the cards are chosen when the card resolves (tick 1 of its 8), not when it is clicked — Mintaka's flow. The picker has no ceiling of its own, so picking more than 5 discards the first 5 picked and says so. It counts as one attack for the DEX counter, however many knives fly.

- **Static Sting** (`static_sting`) — Rare · 30 mana, 2 tempo · ranged 5 · targets enemy · slots: Wand / Fist / Dagger / Arrow · sheet: Offensive
  - Card text: Deal 2 damage and apply 2 Shock. If the target already had Shock, the charge arcs: 1 Shock to the nearest other enemy within 2.
  - Code: `NewCardsD._static_sting`: reads whether the target had Shock, deals the hit through `Card._execute_slash` (2, lightning `damage_type`), applies 2 Shock to a surviving target, and if it had Shock before, applies 1 Shock to the nearest other living enemy within 2 grid cells of the target (the Shock debuff's own arc measure) with the `LightningFX.arc` visual. Plain Offensive, as Internal Sickness.
  - Mismatch / open question: not being a spell, the 2 damage scales with STR like every non-spell hit in the engine (lightning in type only). The arc still happens when the 2 damage kills the target.

- **Feint** (`feint`) — Common · 60 mana, 0 tempo · melee · targets enemy · slots: deck only · sheet: type, slots and rarity blank (scaffolded Utility)
  - Card text: Apply 2 Vulnerable to an enemy. A random attack card in your hand gains +2 tempo and +5 damage until it is played or leaves your hand.
  - Code: `NewCardsD._feint`: `apply_debuff("vulnerable", 2)` on the target, then one random `is_attack()` card in the caster's hand gets `apply_untimed_tempo_cut(-2)` and `bonus_damage += 5` (noted in card meta). The hourglass and the damage number on the face show both. `end_feint` removes them when the card's play has resolved (main, beside Empower's reset) or when it leaves the hand (`Card.clear_temp_mods`: discard, redraw).
  - Mismatch / open question: with no attack card in hand only the Vulnerable lands. A second Feint may pick the same card again (it stacks: +4 tempo, +10 damage). Offensive spells are not "attack cards".

- **Cadence** (`cadence`) — Rare · 10 mana, 1 tempo · targets self · slots: Dagger / Arrow / Fist / Swift · sheet: Utility, Self
  - Card text: Advance your attack-speed counter by 5. If that triggers the proc, also gain Haste 1 for your next move.
  - Code: `NewCardsD._cadence`: five `PlayerStats.register_attack(false)` ticks (counter only — no Wizard Hat / sneakers / free-hand count, as Sabre Tooth's bought tick). A tick that empties the counter fires the DEX proc exactly as an attack would (half tempo + mana discount on the next attack, or Killing Rhythm's damage burst) and the leftover ticks start the next count; if any tick procced, `Buff.create_haste(1, 1)`.
  - Mismatch / open question: Killing Rhythm's burst counts as "the proc" for the Haste.

- **Grit** (`grit`) — Rare · 30 mana, 2 tempo · targets self · slots: Bulwark / Buckler · sheet: Defensive, Self
  - Card text: Gain 2 armor per 10% of health you are missing. If you are below 30% health, gain Bolster 2.
  - Code: `NewCardsD._grit`: steps = `(max_health - current_health) * 10 / max_health` (whole 10% steps, temp HP ignored); `add_armor(2 * steps)` plus any Bolster already up (one charge spent); then, if `current_health < 30%` of max, `Buff.create_bolster(2, 3)`.
  - Mismatch / open question: the sheet's costs are blank — scaffolded 30 mana / 2 tempo. "2 Bolster" is read as Bolster 2 (the value, as "3 Strengthen" is Strengthen 3) for the buff's default 3 armor gains. Exactly 30% is not "below". Bolster is today only spent by Smith thy Soul and Grit, not by every armor gain (the known gap in docs/STATUS_EFFECTS_AUDIT.md).

- **Spine Release** (`spine_release`) — Rare · 70 mana, 2 tempo · targets all_nearby (the 8 tiles around you) · slots: Bulwark · sheet: Spell
  - Card text: Spend all your Thorns and deal that damage, split equally, among the enemies in the 8 tiles around you.
  - Code: `NewCardsD._spine_release` (world effects): total = the summed value of the THORNS buff(s); the buff is removed and the total is split by integer division among the living enemies on the 8 adjacent tiles, the remainder going one point each to the nearest (straight neighbours before corners). Flat `take_damage` — no INT scaling, no crit. With no Thorns or no adjacent enemy nothing is spent (mana and tempo still are). A utility spell: Silence blocks it, it is not offensive.
  - Mismatch / open question: Barbed Exterior's maintained thorns and the sphere grid's thorns "never wear down" and are not spent or dealt. No dedicated visual — it plays the generic utility cast animation.
