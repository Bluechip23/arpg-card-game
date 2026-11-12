# New cards — batch B (instants, jail, deck order)

Sheet rows of 2026-11-11. The behaviour lives in `scripts/cards/new_cards_b.gd`
(`NewCardsB`); main, Card and DeckManager each carry one-line hooks into it.
Tests: `tests/test_new_cards_b.gd`.

Shared notes for the whole batch:

- **Instant damage is flat.** Soul Consumption's 6, Not So Fast's 6 and Pocket
  Shiv's 5 are dealt as printed (`take_damage(card.damage, true)`), not scaled
  by STR / INT — the same as every existing instant that hurts (Death Vortex,
  Psionic Flow, Whirling Weapon, Hard Helmet).
- **Co-op.** Like the other instant sites in main.gd, these act for the active
  player (`main.player` / `main.deck_manager`); the listeners stand down while
  the second player's deck is the active one. Not So Fast alone walks every
  player's hand, the way Cover does.
- **Lethal Recall.** All four instants resolve in `_fire_instant_site_effect`,
  so Lethal Recall arms on them and replays them. A replay has no trigger
  context and falls back to what is around the player (see each card).
- **Distances** are straight-line squares as Cover / Psionic Flow measure them
  (flat world distance); "within 1" / "melee range" / "surrounding" is the 1.5
  radius every melee check uses, i.e. the 8 neighbours.
- **Art.** Nothing new: the instants use the existing instant card animation,
  the pickers are the existing hand-card and full-card pickers.

### Instant (4)

- **Soul Consumption** (`soul_consumption`) — Legendary · 0 mana, 0 tempo · targets self · slots: Wand, Gem, Dagger · sheet: Instant, spell
  - Card text: Instant: when an enemy dies, deal 6 damage to the nearest other enemy within 3 squares of it and draw a card.
  - Code: REACTION, reaction_trigger `on_enemy_killed` (new). `NewCardsB.connect_main` listens to `enemy_spawner.enemy_killed`; `on_enemy_killed` fires the copies in hand one at a time (`DeckManager.fire_reaction`, so Silence stops this spell instant) and routes each through `_fire_instant_site_effect` → `instant_site_effect`: 6 flat damage to the nearest living enemy within 3.0 of where the dead enemy stood (the dead one excluded), then `draw_card()`. With no enemy in reach it still fires and draws. A kill made by its own damage re-enters the same handler, so a second copy in hand answers that second death from the second enemy's position (the chain).
  - **Mismatch / open question:** "When *you* kill" — kills are not attributed to a killer anywhere in the game, so any enemy death counts (a summon's kill, a poison tick), as with every existing on-kill effect; the description says "when an enemy dies". The draw goes through the normal draw (a full hand overflows as usual). A Lethal Recall replay measures the 3 squares from the player.

- **Not So Fast** (`not_so_fast`) — Rare · 0 mana, 0 tempo · targets ally · slots: Swift, Wand, Pocket · sheet: Instant, attack
  - Card text: Instant: when an ally within 6 squares is hit, swap places with them and deal 6 damage to every enemy next to where you left or where you land.
  - Code: REACTION, reaction_trigger `on_ally_hit_within_6` (renamed from the scaffold's `on_ally_damage_taken`, which is Cover's trigger: left as it was, Cover's soak would have fired this card as a Cover on your own hits too). Hooked at the end of `main._cover_mitigation` — the one site that sees heroes, dojo allies and summons being hit — via `NewCardsB.on_ally_hit(victim)`: every player other than the victim, within 6.0, fires ONE copy. The effect swaps the two through `NewCardsB.swap_positions` (the Swap card's position trade, moved there; Swap now calls it too), then deals 6 flat damage to every enemy within 1.5 of the take-off tile or the landing tile, each enemy once.
  - **Mismatch / open question:** (1) One copy per hit, not every copy in hand — a second copy would only swap you straight back. (2) It fires where Cover fires: as the hit is about to land (before armor), so a hit fully absorbed by armor still sets it off, and the ally still takes that hit. (3) Summons only count if they can be moved like a hero (`target_position`); the others are skipped, matching Swap, which refuses summons. (4) No walkability check on the trade, same as Swap. (5) A Lethal Recall replay swaps with the nearest ally within 6.

- **Spiteful Sting** (`spiteful_sting`) — Common · 0 mana, 0 tempo · targets self · slots: Dagger · sheet: Instant, attack
  - Card text: Instant: when an enemy within 1 square hits you, apply 4 Poison to it and draw a card.
  - Code: REACTION, reaction_trigger `on_melee_hit_taken` (renamed from the scaffold's `on_damage_taken`, which is Whirling Weapon's unconditional trigger and has no attacker). Hooked in `main._on_enemy_attacked_player` (an enemy's blow landed on you — not a tick, not a cost you paid): if that enemy stands within 1.5 squares, every copy fires; each applies `apply_debuff("poison", 4)` to the attacker and draws a card.
  - **Mismatch / open question:** "Incoming damage" is read as an enemy's attack reaching you, whether or not armor ate it. If the attacker died to the exchange (Thorns) the card still fires and draws. A Lethal Recall replay poisons the nearest enemy in melee range.

- **Pocket Shiv** (`pocket_shiv`) — Common · 0 mana, 0 tempo · targets self · slots: Dagger, Pocket, Swift · sheet: Instant, attack
  - Card text: Instant: when you discard another card from your hand, gain 10 mana and deal 5 damage to the nearest enemy in melee range.
  - Code: REACTION, reaction_trigger `on_card_discarded` (new). `NewCardsB` listens to `DeckManager.non_play_discard` and skips the announcements flagged `non_play_discard_is_spend` (an instant firing, a jail release). Every copy in hand fires: `gain_mana(10)` and 5 flat damage to the nearest enemy within 1.5; with none there the mana is still gained. A played card going to the discard pile does not trigger it; discarding the Shiv itself does not (it is no longer in hand), though a second Shiv would answer it.
  - **Mismatch / open question:** (1) The fire is deferred to the end of the frame: discards are announced from inside loops over the hand, and firing removes the Shiv from that hand. (2) "Discard" is every non-play discard the deck announces — card effects, the manual discard, Clumsy, an Enchantment or Volatile Mixture timing out in hand, a discard-on-draw card. Ragnarok's hand-full overflow also announces one, though that card never sat in the hand.

### Utility (4)

- **Deep Breaths** (`deep_breaths_spell`) — Legendary · 100 mana, 6 tempo (resolves on 4) · targets self · slots: Gem, Crown · sheet: Utility, spell
  - Card text: Jail every instant card in your hand, draw pile and discard pile for 20 tempo. Gain 10 temp HP for each. Each grants 10 armor, on top of its own effect, the next time it triggers.
  - Code: `main._apply_card_world_effects_inner` → `NewCardsB.world_effect` → `_deep_breaths`: every REACTION card in hand, draw pile and discard pile goes to the jail pile through `Card.jail(20)`, marked with the meta `deep_breaths_armor`; `add_temp_health(10 × jailed, 20)`. They come back the way every jailed card does (`DeckManager.process_turn`, 5 off per cycle, released to the discard pile). On `reaction_triggered`, a marked card grants `add_armor(10)` once and loses the mark. The item-granted `deep_breaths` (Trench of Tranquility, heal) is untouched.
  - **Mismatch / open question:** (1) **The sheet gives no jail length — 20 tempo is a guess** (Self Admission's and Meister of Faustmesser's number). (2) The sheet gives no length for the temp HP either: it lasts 20 tempo, as long as the jail. (3) Instants already in jail, and maintained cards, are not touched or counted. (4) The description says "instant card" in lower case on purpose: Lethal Recall treats any card whose text contains "Instant" as an instant.

- **Self Admission** (`self_admission`) — Rare · 10 mana, 0 tempo · targets self · slots: Gauntlet, Gem, Crown · sheet: Utility
  - Card text: Jail a card from your hand for 20 tempo. When it is next in your hand: Strengthen 5, heal 20, gain 20 mana, and it costs 1 less tempo until played.
  - Code: clicking to play opens the hand-card picker (`picked_card`, as Reposition); `_self_admission` jails the pick with `Card.jail(20)` and marks it (`self_admission_payoffs`). Jailed cards are released to the DISCARD pile, so "returns to your hand" is read as the next time the card is in the hand: `NewCardsB._on_hand_updated` (drawn again, or freed straight to the hand by Ragnarok) pays out once — `Buff.create_strengthen(5, 3)` (+5 on the next 3 attacks, the default count), `heal(20)`, `gain_mana(20)`, and `apply_untimed_tempo_cut(1)` on the card.
  - **Mismatch / open question:** (1) **The −1 tempo uses the game's existing in-hand tempo cut (Clean Exchange's): it lasts until that card is played or leaves the hand**, not for the rest of the fight. Cards are persistent objects with no fight-scoped cost reset, so a "rest of the fight" cut would need a new mechanism; say if that is what is wanted. (2) "5 strengthen" = Strengthen 5 on the next 3 attacks. (3) With no pick (a Lethal Recall replay, a scripted play) a random hand card is jailed, as Reposition does; with an empty hand the card is spent for nothing. (4) The mark is not saved, so a jailed card carried across a save/load returns without the payoff.

- **Reverse Reverse** (`reverse_reverse`) — Rare · 50 mana, 3 tempo (resolves on 1) · targets self · slots: Gauntlet · sheet: Utility
  - Card text: Draw 1, then put a card from your hand on top of your draw pile.
  - Code: `_reverse_reverse` draws 1 when the card resolves (the play holds a hand slot for it via `get_effect_draw_count`), then opens the hand-card picker; the chosen card leaves the hand and is appended to the draw pile (its top), so it is the next draw. The pick is owed: Cancel re-opens the picker. With one card in hand it goes back without a question (the picker's own rule). `resolve_tick = 1` was added to the .tres (the sheet's tempo trigger).
  - **Mismatch / open question:** the card just drawn may be the one put back.

- **Foresight** (`foresight`) — Rare · 20 mana (−2 per Brain point held, min 0), 0 tempo · targets self · slots: Gem, Fist, Crown · sheet: Utility, self
  - Card text: Look at the top 3 cards of your draw pile. Put one in your hand and one on the bottom. Costs 2 less mana per Brain point you hold.
  - Code: price — `NewCardsB.price_foresight` at the top of `DeckManager.compute_play_cost` sets `mana_cost = max(0, 20 − 2 × current_brain_points)`; the same number is stamped on every Foresight in hand whenever the hand or the Brain pool changes (`_on_hand_updated`, `main._on_brain_points_changed`), so the face shows it, as Summon Skeleton's does. Brain points are read, not spent. Effect — `_foresight` shows the top 3 in the full-card picker: pick one for the hand (`add_card_as_drawn`, so on-draw passives see it), then one of the other two for the bottom; the third stays on top. Both picks are owed (Cancel re-opens).
  - **Mismatch / open question:** (1) With 2 cards in the pile: one to the hand, the other to the bottom; with 1: it is taken; an empty pile reshuffles the discard first, like any draw. (2) A full hand cannot take the card: it stays on top of the draw pile rather than being lost. (3) The sheet's tempo-trigger cell is blank; the card is 0 tempo and resolves at once.

## Shared-code hooks

- `scripts/core/main.gd`: `_ready` (`NewCardsB.connect_main`, placed before main's own `hand_updated` handler); `_on_brain_points_changed` (Foresight's price); `_on_enemy_attacked_player` (Spiteful Sting); `_cover_mitigation` (Not So Fast); `_fire_instant_site_effect` (one match arm for the four instants); `_apply_card_world_effects_inner` (one match arm for the four played cards; the `swap` arm now calls `NewCardsB.swap_positions`); the click-to-play branch (Self Admission's picker, beside Reposition's).
- `scripts/cards/deck_manager.gd`: first line of `compute_play_cost` (Foresight's price).
- `scripts/cards/card.gd`: `get_effect_draw_count` (Reverse Reverse = 1); a `pass` arm in `_execute_card` for the eight ids (main resolves them).
- No jail choke point was added: both jail cards go through `Card.jail()` and `DeckManager.jail_pile` (`NewCardsB.jail_card`), like the existing jails.
