# New sheet cards — batch A (aura / maintain / ally-buff)

Logic: `scripts/cards/new_cards_a.gd` (`NewCardsA`). Tests: `tests/test_new_cards_a.gd`.

Shared across the batch:

- **"Allies" are heroes** — the party and the dojo's practice allies (`main._all_allies()`), the caster included. Summons are not covered: they have no Strengthen, Keen, Attune or armor pool for these buffs to land on (the same line `main.SUMMON_ALLY_CARDS` draws for ally-target cards). **Open question:** should summons in the radius benefit, and if so what do Strengthen / armor mean on a wolf or a skeleton?
- **"Within N squares"** is a circle measured in grid cells (`NewCardsA.within`): straight-line cell distance <= N, so (2,0) is within 2 and (2,1) is not. This is how the flame and AoE circles are measured.
- The maintains are co-op aware: each player's own maintained pile is read, and the aura / field is centred on that player.
- Hooks in shared files (one line each): `Card._execute_card` (one match branch for the nine ids), `main._apply_card_world_effects_inner` (`"war_shout"` branch), `main._on_tempo_advanced` and `main._sync_maintained_passives` (`NewCardsA.tick`), `main._process_maintained_card_effects` (`NewCardsA.cycle`), the four jail sites in `DeckManager` and the one in `OverflowManager._process_jailed` (`NewCardsA.on_card_jailed`), `Enemy._tick_status_durations` (Shock's decay asks `NewCardsA.holds_shock`), `BuffManager.apply_buff` (a Strengthen never merges into the Howl's aura instance).
- Art: none added. The cards use the default cast animation and the existing buff / debuff badges (Strengthen, Keen, Attune, Focused, Thorns, Slow, Burn, Shock). No aura ring or field visual is drawn for The Wolf's Howl, Spirit Armor or Lodestone Field — no pack piece covers one and no placeholder was made. **Open question:** whether these want a ground ring (the existing AoE / range indicator could be reused).

---

- **The Wolf's Howl** — `the_wolfs_howl`
  - Rarity: Rare. Cost: 180 mana (maintained: 180 reserved), 5 tempo, resolves on tick 5. Targets: self. Slots: Sword, Crown.
  - Sheet text: Maintain: grant all allies in a 2 square radius 5 strengthen.
  - Card text: Maintain: you and allies within 2 squares of you have Strengthen 5 (attacks +5) while they stand in the howl.
  - Code: UTILITY with `auto_maintain`, so `play_card` puts it in the maintained pile and reserves 180 mana. `NewCardsA.tick` (every tempo advance, and whenever a maintained pile changes) calls `_sync_wolfs_howl`: every hero within 2 squares of a howler, the howler included, carries one aura buff — a clock Strengthen of 5 marked with the `wolfs_howl_aura` meta, whose clock is reset to 5 every tempo it stands. No attack spends it (a clock Strengthen has no charges), it is removed the tempo the hero is out of range or the card leaves the maintained pile (dismiss, break), and `BuffManager.apply_buff` skips it when merging, so a carded Strengthen stands beside it and counts down its own attacks. Two howlers do not stack: a hero has the aura or not.
  - Mismatch / open question: the aura takes effect when the card is PLAYED (it enters the maintained pile then), not at its tick-5 resolve — the same as Barbed Exterior and Forever Armor. The 5 is flat: the sphere grid's Strengthen amp is not applied to the aura. Its badge reads "5 tempo" permanently (the refreshed clock); the hover text says it lasts while inside the howl. Strengthen is attacks only (designer, 2026-10-30), so spells gain nothing. Summons: see top.

- **Spirit Armor** — `spirit_armor`
  - Rarity: Rare. Cost: 90 mana (maintained: 90 reserved), 4 tempo, resolves on tick 1. Targets: self. Slots: Wand, Buckler, Bulwark, Spear.
  - Sheet text: Maintain: all allies in a 5 square radius gain 2 armor per cycle.
  - Card text: Maintain: every cycle, you and all allies within 5 squares of you gain 2 armor.
  - Code: UTILITY with `auto_maintain`. `NewCardsA.cycle` (called from `main._process_maintained_card_effects`, at each cycle start beside Halo's heal) runs `_spirit_armor`: every hero within 5 squares of the maintainer, the maintainer included, gets `PlayerStats.add_armor(2)`.
  - Mismatch / open question: it is an ordinary armor gain (like Smith's per-cycle armor), so the receiver's flat block bonuses (enchantment / sphere block) add to it and it decays like any armor — the caster's 2 is granted before that cycle's armor decay runs. If the sheet meant unerring armor (as the per-tempo armor items give), say so. The scaffold had no tempo; the engine default (4 tempo, resolve tick 1) matches the sheet's 4 / 1.

- **Ember Heart** — `ember_heart`
  - Rarity: Legendary. Cost: 90 mana (maintained: 90 reserved), 1 tempo. Targets: self. Slots: Wand, Staff, Hammer.
  - Sheet text: Each cycle, 2 stacks of your burn are transferred to a random enemy within 4 squares. Each stack dealing 3 damage upon transfer.
  - Card text: Maintain: each cycle, 2 stacks of the Burn on you are transferred to a random enemy within 4 squares. Each stack deals 3 damage as it transfers.
  - Code: POWER, maintained. `NewCardsA.cycle` → `_ember_heart`: if the maintainer carries Burn (the player debuff) and a living enemy stands within 4 squares, min(2, stacks) leave the maintainer (the Burn is removed and its doubling counter reset at 0), one random enemy in reach gains that many Burn stacks (`apply_debuff("burn", n)`) and takes 3 damage per stack moved, as separate 3-damage instances through `Enemy._dot_hit` (flat, armor soaks it first, not a hit: no on-hit riders). No Burn or no enemy in reach: nothing moves. It runs before the cycle's own status ticks, so the stacks leave before the maintainer's Burn bites that cycle.
  - Mismatch / open question: "your burn" is read as Burn stacks on yourself, per the brief. All moved stacks go to ONE random enemy (not one enemy per stack). The 3 per stack is flat (no INT, no crit). The maintainer's Burn doubling counter is not reset by a partial transfer.

- **Lodestone Field** — `lodestone_field`
  - Rarity: Legendary. Cost: 100 mana (maintained: 100 reserved), 5 tempo, resolves on tick 1. Targets: self. Slots: Hammer, Gem. Spell.
  - Sheet text: Enemies within 2 are Slowed 1 at each cycle start, and Shock on them does not decay while they stand in the field.
  - Card text: Maintain: enemies within 2 squares of you are Slowed 1 at the start of each cycle, and Shock on them does not decay while they stand in the field.
  - Code: POWER, maintained; the field is centred on the maintainer and follows them. `NewCardsA.cycle` → `_lodestone_slow`: every living enemy within 2 squares gets `apply_debuff("slow", 1)` (one stack = 5 tempo) at each cycle start. `NewCardsA.tick` keeps `lodestone_casters` (who maintains it) current every tempo; `Enemy._tick_status_durations` asks `NewCardsA.holds_shock(self)` before Shock sheds its per-cycle stack — inside a field the Shock still deals its damage and arcs but keeps its stacks.
  - Mismatch / open question: only the per-cycle decay is held; Element Pollination's "Shock at 5 stacks discharges" still clears it. Slow stacks add (a stack sheds every 5 tempo, so an enemy that stays in the field stays Slowed and banks no extra). Shock on summons / heroes is untouched (the text says enemies).

- **Warden's Hound** — `wardens_hound`
  - Rarity: Legendary. Cost: 60 mana (maintained: 60 reserved), 0 tempo. Targets: self. Slots: Axe, Crown.
  - Sheet text: When you Jail a card, gain 2 keen and 5 thorns.
  - Card text: Maintain: when you Jail a card, gain Keen 2% for 10 tempo and 5 Thorns.
  - Code: UTILITY with `auto_maintain`. `NewCardsA.on_card_jailed(deck, card)` is called wherever a card is sent to that deck's jail: jail-on-play, a slotted item's jail-after-play (Rapid Recurve), a Burden card jailed from hand (`jail_burden_card`), a reaction jailed on its cooldown (`trigger_one_reaction_jailed`, Polymorph) and the Jailed overflow. While the Hound is in the maintained pile its owner gains `Buff.create_keen(2, 10)` (timed Keen stacks its value and keeps the longer clock) and `Buff.create_thorns(5, 15)` per card jailed (per maintained Hound).
  - Mismatch / open question: **"2 keen" is read as Keen +2% on the clock for 10 tempo** — the sheet gives no unit or duration; 2% is small, confirm (it could mean 2 crit rolls, or a larger %). The Thorns use the factory's default 15-tempo clock and wear 1 per hit like ordinary thorns; the sheet gives no duration. A jailed card returned by re-equipping its item (`Inventory`) and a jail pile restored from a save do not count as jailing.

- **War Shout** — `war_shout`
  - Rarity: Common. Cost: 30 mana, 3 tempo, resolves on tick 1. Targets: self. Slots: Axe, Crown, Bulwark.
  - Sheet text: Provide strengthen 3 to all allies within 3 squares of you.
  - Card text: You and all allies within 3 squares gain Strengthen 3 for 3 attacks.
  - Code: `main._apply_card_world_effects_inner` → `NewCardsA.war_shout`: the caster and every hero within 3 squares get `Buff.create_strengthen(3, 3, "War Shout")` through their own buff manager (so each receiver's Strengthen amp applies, and it stacks with a Strengthen they already hold).
  - Mismatch / open question: the sheet gives no count; 3 attacks is the usual one (Biscuit, Hope This Works). Summons: see top.

- **Stone Wheel** — `stone_wheel`
  - Rarity: Common. Cost: 50 mana, 2 tempo, resolves on tick 1. Targets: an ally or self, range 5. Slots: Sword, Wand.
  - Sheet text: Grant an ally Keen 15% for 10 tempo.
  - Card text: Grant an ally Keen 15% for 10 tempo.
  - Code: `Card._execute_card` → `NewCardsA.execute`: `Buff.create_keen(15, 10, "Stone Wheel")` on the buff manager handed in — the targeted ally's for an ally cast (`DeckManager.execute_deferred_card` swaps in the target's stats and managers, as for Lady Luck), the caster's for a self cast. Timed Keen stacks its value with other timed Keen and keeps the longer clock. A summon cannot be picked (not in `SUMMON_ALLY_CARDS`); range is checked by the targeting code (`is_ranged`, range 5).
  - Mismatch / open question: a dojo practice ally's buff clock is not ticked by main (only party members' are), so on a dummy the Keen does not count down — a property of the dummies, not of this card.

- **Arcane Tide** — `arcane_tide`
  - Rarity: Common. Cost: 30 mana, 2 tempo (scaffolded — **the sheet's cost cells are blank, confirm**). Targets: an ally or self, range 5. Slots: Gem, Wand, Sword. Spell (utility).
  - Sheet text: Grant Attune 3.
  - Card text: Grant an ally Attune 3 (+3 damage on their next 3 offensive spells).
  - Code: `NewCardsA.execute`: `Buff.create_attune(3)` (the default 3 spells) on the target's buff manager, self allowed. Arcane Tide is a utility spell, not an offensive one, so it neither gains nor spends Attune itself. Re-applying adds the value and keeps the higher count (`BuffManager`).
  - Mismatch / open question: costs as above.

- **Clarity** — `clarity`
  - Rarity: Common. Cost: 10 mana, 3 tempo, resolves on tick 3. Targets: self. Slots: Crown, Wand, Staff.
  - Sheet text: Focused for 2 cycles and Attune 2.
  - Card text: Focused for 2 cycles (+10 mana at each cycle start) and Attune 2 (+2 damage on your next 3 offensive spells).
  - Code: `NewCardsA.execute`: a Focused buff on an 11-tempo clock and `Buff.create_attune(2)`. Focused pays +10 mana at a cycle start (`BuffManager.process_turn_start`); nothing else applies Focused today, so there was no duration convention to copy. A buff's clock ticks before that tempo's cycle start runs, and 11 tempo is the one length that always meets exactly two cycle starts wherever in the cycle the card resolves (10 would miss the second when it resolves on a boundary) — tested at all five cycle offsets.
  - Mismatch / open question: the Focused badge therefore reads "11 tempo" when applied, not 10. If Focused should be counted in cycles outright (like Blessed's charges) that is a change to the buff itself.
