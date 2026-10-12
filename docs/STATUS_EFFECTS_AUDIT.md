# Status Effects Audit — sheet wording vs code

*2026-10-12. Every row of `docs/STATUS_EFFECTS_BUFFS.csv` (43) and `docs/STATUS_EFFECTS_DEBUFFS.csv` (59) was
checked column by column (Effect, Expiry, Default, Stacking, Amp, Sources) against the code. Read-only: nothing was
changed to produce this list. Line numbers are as of commit `42f89cd`.*

**2026-10-12 follow-up.** The designer ruled on items 1–5, 18, 19, 21, 27–31 and 39; those are fixed (marked below)
with tests `test_enemy_status_fixes.gd`, `test_buff_instances.gd`, `test_action_gating.gd`, `test_hex_lock_cards.gd`
and `test_coop_status_ticks.gd`. Rulings: Mark keeps the longer timer; Enlightened and Resilient keep separate
instances (highest % first; Resilient by damage type); Haste spends a charge on Flash moves too; Stun blocks every
action except Wait; Blind also misses the auto attack and Flash Cut; Weighted taxes card plays only (Quiver and
Manifest included, auto attack and Block not); hexes and locks belong to their card and leave with it; Misery spreads
up to the top value, never past it; Expel moves the remaining duration. Still open in co-op: batch "move together"
skips per-tile hazards, `tempo_manager.player_stats` (flash moves, free tiles) stays on player 1, player 2's
shadow-form end is not wired, and Wither / in-hand debuffs / the invisibility check remain active-player only.

**Tags.** **[CODE]** the game does something different from the sheet. **[WORDING]** the behaviour is sensible but
the sheet (or the in-game text) describes it wrongly or incompletely. **[SOURCE]** a source in the Sources column is
missing, wrong, or uses different numbers.

**Clean rows (no discrepancy):** Focused, Blessed, Fortify, Cleanse, Smith, Keen, Might, Phoenix Grace, Shield Ready,
Repelled Block, Raged Circulation, Approach, Shadow Form, Invulnerable, Gravebound, Staggered, Clumsy, Brittle,
Weakened, Regen Frozen, the four retired debuffs, Cold (enemy), Frozen (enemy), Narashimha, Taunt, Fear.

---

## 1. Bugs — the game does not do what the sheet says [CODE]

Ordered roughly by how often a player would hit them.

### Enemy statuses
1. **[Fixed 2026-10-12]** **Tripped never wears off on its own.** `_tick_timed_statuses` returns early unless another listed timer is
   running, and `tripped_tempo` is not in that list (enemy.gd:2574-2580, countdown at 2687). A Trip lasts until
   something else timed lands on the enemy. Its badge also has no hover text.
2. **[Fixed 2026-10-12]** **Exposed is never cleared.** `is_exposed` is set when armor breaks (enemy.gd:6915, 6928) and nothing ever sets it
   back, so "until it gains armor again" is false and the badge text promises it.
3. **[Fixed 2026-10-12]** **Mark is cut to 1 tempo by the "+1" riders.** Mark overwrites its timer (enemy.gd:7360), and Wither
   (main.gd:6297) and Territorial Death (progression_triggers.gd:1879) re-apply with value 1.
4. **[Fixed 2026-10-12]** **Misery Loves Company double-counts the additive timers.** For Disarm, Root and Cursed it now yields current +
   top (+ amp) instead of top (main.gd:8316-8318); Stun/Silence amps are added twice. Its `disarm_attacks` entry is
   dead (the field is always 0).
5. **[Fixed 2026-10-12]** **Expel Negativity sends timed debuffs as 1 tempo.** Player timed debuffs carry value 0, and the transfer uses
   `maxi(1, value)` (progression_triggers.gd:1708). A 15-tempo Stun arrives as 1.
6. **Silence and Polymorph drop the queued action but keep its wind-up**, so the replacement fires early
   (enemy.gd:7366, 7442). Silence also drops melee and moves, not only spells, and does not break a running channel.
7. **Polymorph** lasts 1–5 tempo instead of 5 (its cycle counter is not reset when the pig lands), does not stop
   Async actions or a running channel, and its badge shows cycles labelled "tempo" (enemy.gd:2458, 2558, 7891).
8. **Wear Down (enemy)** grows on every player hit — spells, AoE, each hit of a multi-hit card — not only attacks,
   and each hit refills the 2 charges even after the player's buff is gone (enemy.gd:6863-6866). The last charge also
   clears the reduction before that swing's log line prints it.
9. **Lowered Physical Defense** amplifies every PHYSICAL-typed hit, including DoT ticks (burn, poison, choke, shock,
   bleed default to physical) (enemy.gd:6809-6814, 6771).
10. **Choke** deals a flat 2 (card.gd:3913-3914), not "half the caster's auto-attack damage".
11. **Serial Killer Blindness** makes the enemy do nothing at all, not just ignore that player — it also stops
    acting against allies and summons (enemy.gd:2830).
12. **Cupid Mark:** a mark that lands while the enemy is already a Tree is kept, so after the Tree ends a single
    arrow turns it straight back (enemy.gd:7232).
13. **Stun Amp:** the Element Pollination stun skips it (enemy.gd:7396); it is added to the Sewer Cobra's self-stun on
    exposure; and every sphere amp is read from player 1 regardless of who applied the status (enemy.gd:6763-6769).
14. **Burn (enemy) tooltip** says "attacking while burning also triggers the current burn damage" — that is the
    player's rule; enemies have no such trigger (enemy.gd:7896).
15. **Brace (enemy)** charges are spent by every `take_damage`, including DoT ticks and self-damage (enemy.gd:6822).
16. **Thorns (enemy)** always hit `main.player`, not the attacker (wrong in co-op) (enemy.gd:3796-3803).
17. **Strengthen (enemy):** Cerberus's Swipe ignores it (enemy.gd:3681).

### Player buffs
18. **[Fixed 2026-10-12]** **Enlightened merge stacks the best of both.** A re-apply keeps the higher charge count *and* the higher percent
    (buff_manager.gd:70, 79-83). A 100% payout (Understanding, Scouted, Serial Killer) landing on Lady Luck's 30%×5
    becomes five guaranteed crits.
19. **[Fixed 2026-10-12]** **Resilient merge keeps the old damage type.** Harden (10% physical) then Succumb (20% all) becomes 20%
    physical-only; Smithed Excellence (2% all) then Harden becomes 10% against everything (buff_manager.gd:79-83).
20. **Thorns merge loses or spreads Vined Encasing's shed-by-damage flag** (buff_manager.gd:67-78).
21. **[Fixed 2026-10-12]** **Haste:** Flash moves still get the bonus tiles but never spend a charge, so Haste is unlimited while moving on
    Flash (player.gd:334-337, 404-409).
22. **Bolster** is only consumed by Smith thy Soul, not "the next Y times you gain armor" (player_stats.gd:2241,
    card.gd:5870) — and nothing grants it.
23. **Demonic Rage** pays its "health" through `take_damage`, so armor and temp HP absorb it and Invulnerable makes it
    free (deck_manager.gd:682, main.gd:14341). The Quiver path checks HP against the raw mana cost but charges
    cost/10 (main.gd:14333 vs 14340).
24. **Morphine's temp HP is not tied to the buff:** it sits in the shared temp-HP pool, which ticks per 5-tempo cycle
    and keeps the longest timer (player_stats.gd:1698-1703), while the buff ticks raw tempo. The HP can vanish before
    the 2-damage hit lands, or outlive it.
25. **Invisible:** leaving Shadow Form removes every Invisible buff, including a longer Shadows or Smoke Bomb one
    (main.gd:11187-11189).
26. **Enchanted Quiver / Tighten String** re-applies reset the charges to 3 instead of adding (card.gd:3755, 3761).

### Player debuffs
27. **[Fixed 2026-10-12]** **Stun** only blocks movement and card plays. Gauntlet skills, Sidestep / Flash Cut (an attack), Brain
    draw/peek and gear swaps still work while stunned (debuff_manager.gd:304-334; main.gd:3803, 6961, 7018, 2443).
28. **[Fixed 2026-10-12]** **Blind** only rolls a miss on Attack-type cards aimed at an enemy (card.gd:1401-1411). The Basic Attack and
    Flash Cut never miss.
29. **[Fixed 2026-10-12]** **Weighted's +2 tempo** is also charged on Basic Attack, Basic Block and Manifest/Quiver plays, but those never
    burn a stack (main.gd:2281, 2423, 14372).
30. **[Fixed 2026-10-12]** **Hexed (and Locked) drift onto the wrong card.** Index shifting only runs on a play, a Clumsy discard and a Harpy
    steal. Venom Tail's knock-out, Shed Weight, enchantment expiry, reactions fired from hand, jailing, Infest hatching
    and on-draw discards leave stale indices; a Clumsy-discarded hexed card passes its hex to the next card; a Sticky
    card's re-insert lands after the shift; and a new hex sits unassigned until the next hand change
    (deck_manager.gd:419, 750, 819, 852, 1039, 1091, 1231-1258, 1272-1335; main.gd:7258).
31. **[Fixed 2026-10-12]** **Locked:** the Labyrinth's hand scramble only carries the first lock over, and a Harpy steal removes hexes but
    not locks (deck_manager.gd:984-995; enemy.gd:5811). No live source yet.
32. **Slowed timer-over-stacks** overwrites rather than extends: Slowed 4 (20 tempo) plus a 3-tempo Snowball leaves 3
    tempo (debuff_manager.gd:49-56). Fire Web's 2-tempo refresh does the same.
33. **Petey the Pet Rock's Slowed** is only applied at cycle end and only when no Slowed exists, alternates between 2
    and 1 stacks, and lingers up to 10 tempo after Petey leaves the hand (main.gd:7739, 7874-7877).
34. **Poison under Elixir:** the tick-heal branch is dead (`elixir_stacks` is never set). Elixir only turns poison
    applied by your own card plays into healing; enemy poison still hurts (debuff_manager.gd:26-30, 184-187).
35. **Cursed (player)** applies the 20% self-damage only through card executors; the Basic Attack takes the 20%
    reduction but no self-damage (main.gd:2272-2276). No live source.
36. **Lost in the Labyrinth:** an Enchantment or Unplayable card at the front of the line freezes the whole hand,
    because the next-card picker does not skip them but `play_card` refuses them (main.gd:16553-16558,
    deck_manager.gd:483-489). In co-op only the active player's hand is scrambled.
37. **Marvolo's Misunderstanding** adds values on re-apply, so a second trigger means 50 damage
    (debuff_manager.gd:80); any other GENERIC debuff would merge into it too.
38. **Drain from Release Soul:** if Succumb's Drain merges into the held one, the whole merged Drain is removed when
    the card leaves the hand (main.gd:7906). Edge case.

### Co-op (both sides)
39. **[Fixed 2026-10-12]** Only the active player's per-cycle buff and debuff effects run (Regen, Focused, Blessed, Smith, Burn, Poison,
    Drain, Shocked, temp-HP and Raged Circulation timers), while their timed statuses still tick down
    (main.gd:7650-7713). Slowed movement pricing, Marvolo's expiry hook, fire walls and the Spiked Web are wired to
    player 1 only (main.gd:4175, 4232, 6626-6685).

---

## 2. Wording fixes for the sheet [WORDING]

**Stack-clock debuffs (Vulnerable, Weakened, Slowed, Staggered, Clumsy, Brittle, Blind; enemy Slow, Vulnerable,
Weaken).** Stacks fall one at a time on a single clock per debuff, so N stacks last 5×N tempo, but a stack added
mid-clock can fall in as little as 1 tempo. "Each stack lasts 5 tempo" is true of the total, not of each stack.
Suggested: *"Stacks fall one every 5 tempo."*

**Buffs**
- Regen: From the Ashes is "permanent" on the clock only; it still decays 1 per cycle.
- Enlightened: any crit roll spends a charge, spells included — not only attack rolls.
- Strengthen: two per-attack copies add their damage but keep the larger charge count.
- Steady: "next action" means the next card play or basic attack; movement neither uses nor spends it.
- Brace: a re-apply keeps the existing % and damage type and only extends the hits; the in-game text never says when
  Brace is physical-only (Parry).
- Life Steal: only Attack cards spend it — the basic attack and gauntlet strikes do not.
- Morphine: the 2 damage on expiry goes through armor and temp HP.
- Wear Down (player buff): the enemy status now lasts 2 enemy attacks; the buff text still says tempo (buff.gd:124).
- Armor Break: against an unarmored enemy the attack deals 0.
- Shield of Growth: armor equals the incoming hit before mitigation, not the damage actually taken.
- Poisoned Blood: a heal aimed at yourself or an ally damages *that* target; it does not become enemy damage (the
  in-game text says "deal damage to enemies").
- Elixir: during the window your own card plays' poison heals whatever it lands on, enemies included; enemy poison
  on you still hurts.
- Understanding: during the countdown the badge already says "your next attack will critically strike".
- Loaded Die: spent when a chance card is played, not on "the next roll".
- Temp HP: timers drop per 5-tempo cycle, so a 5-tempo grant lasts 1–5 tempo.
- Enchantment (in hand): Movement gives +15 max Flash points, not "+1 movement".
- Brace (enemy): every fresh drop below half by another unit counts again after healing; a unit already below half
  when first seen never counts.
- Sealed: the seal lasts 10 tempo (not stated).

**Debuffs**
- Disarm (player): only physical-school attack cards are blocked from the hand, so attack spells still play; Manifest
  and Quiver block every attack; attack reactions are not blocked. In-game text says "all attack cards".
- Burn (player): "attacking deals the current burn damage" actually deals the *next* tick's doubled value.
- Cuffed: blocks tempo draws, Blessed draws and Brain draws, but not card draw effects (deliberate in code).
- Shocked (player): arcs only to players and dojo allies, never summons — in solo it does nothing. In-game text has
  enemy wording.
- Slowed: Shift free tiles and Flash moves skip the price; pass-through tiles are a flat 2.
- Hexed: the in-game text leaves out the 25-tempo timer.
- Rooted: Blink and other card teleports still move you.
- Vulnerable (player): applies to direct hits only; DoT ticks, Bleed, Burn-on-attack and Cobra thorns are not
  amplified.
- Blind: the sheet's note about `PlayerStats.is_blinded` is out of date — the debuff is now the source of truth.
- Silence / Cuffed / Rooted defaults: the code default is 15 tempo, not the sheet's 5 / 10 / 5; every live source
  passes its own timer, so this only matters for future sources.
- Slow, Disarm and Shock (enemy) Notes columns are out of date: the Slow tooltip now says "+2 tempo per move", Disarm
  is additive (Wither extends it), and Shock does arc.
- Disarmed (attacks): Disarm Amp applies once per application.
- Marked, Vulnerable (enemy): apply to any player hit (spells and AoE included), not only attacks.
- Silenced (enemy): badge says "cannot cast spells" and leaves out ranged specials and the dropped action.
- Shock (enemy): Shock Amp is added on every application, including the +1 from Laced Arrow and Wither.
- Bleed (enemy): with Bleed Amp each tile deals 1 + amp but removes only 1 stack.
- Rooted (enemy): Root has no stacks; "5 tempo per stack" is Gravity Gauntlets multiplying by 5.
- Tree: does not reset the action clocks the way Stun and Frozen do, so a counting action fires the moment the Tree
  ends.
- Exposed: the "reactions" are the enemy's own exposed triggers; the player's on-exposed reactions fire only when
  the player is exposed.
- Lowered Physical Defense: the Notes say "no badge"; it now shows "Exposed Defense".
- Serial Killer Blindness: the 100% crit is applied at the ambush, not while armed.
- Global debuff riders: Laced Arrow fires on a 50–100% chance by rank; Wither is on a 15→1 tempo cooldown; Territorial
  Death fires on entering or leaving melee and turns a zone-only Weaken into a real stack; the Amp column leaves out
  Poison Amp, Curse Amp, Curse Pain and Shatter.

---

## 3. Source corrections [SOURCE]

- Regen: Hallowed Trunk at Lv3 also banks health lost, not only armor; From the Ashes gives 75% of the burn at Lv3.
- Bleed (player): Sabertooth is missing — Bleed 6 on a crit, 8 on Sunken Bite. The Large Bear heal applies to every
  enraged bear on the level, not only the one that bled you.
- Stun (player): Weregoat Charge landing (3) is listed; Bull Rush's chance counts the banked leap spaces too.
- Stun (enemy): the generic sphere passive "stun_enemy" (5 tempo) is missing.
- Frozen (player): Snow Wraith's Snowball (Cold 2) can also complete a freeze.
- Cold (player): Clobber's 50 is level-band scaled.
- Poison (enemy): under Elixir, a poison application heals the enemy instead.
- Cursed (enemy): Expel Negativity delivers it as 1 tempo; Territorial Death only extends an existing curse.
- Thorns (enemy): Sewer Cobra (5 while armored) is missing, and its hover text shows Roar's text and "Thorns: 0".
- Strengthen (enemy): Spirit Collector (+5 from Release Soul) and Sabertooth Track (+15, spent on the next blow) are
  missing; the latter contradicts "never fades".

---

## 4. Dead code and stale text (no gameplay effect)

- card.gd:2513-2550 — the on-self Burn/Cold(30)/Bleed branches that target a player's debuff manager can never run.
- `elixir_stacks` branches (debuff_manager.gd:184-187, buff_manager.gd:308-314); `shadow_form_entered_at`.
- Burn's expiry-reset in `advance_time` never fires (duration is always -1).
- `process_turn_start` still returns the retired pull fields; main.gd:7709 comment mentions Magnetize.
- `Debuff._init` turns an explicit Cold duration of 15 into 5 (15 doubles as "no duration given").
- Stale strings: "Enemy is now Frozen!" printed on the player (debuff_manager.gd:106); keyword "bleed" says X per tile
  (card.gd:1198); Fan Save says a stack is consumed per attack (item_data.gd:1722); "enemies have no bleed track"
  comments (progression_triggers.gd:2193, 2296); Narashimha log says cycles; Demonic Rage log says "Next 50 mana".
- Display: buff descriptions with counts are not refreshed after a charge or tick (the hover's "Remaining" line is);
  charge-based GENERIC badges show "Remaining: ∞".
- Hydra's +40 health on the 4th hit ignores the Narashimha heal cap (enemy.gd:6847).
