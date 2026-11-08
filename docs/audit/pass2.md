# Audit pass 2 (`audit/full-pass-2`)

Phases 1, 2, 3 and 5 were run again on the code as it stood after pass 1. This page lists **new findings only**.

## Summary

| Phase | Re-run | New findings |
|---|---|---|
| 1 — restructure / tech debt | `tools/audit/inventory.py` re-run, with its passive parser fixed | None in the code. The inventory now counts all **60** passives; pass 1 counted 58 because two ids contain an apostrophe. Still 0 dead functions, and still only the 2 accepted duplicate idioms. Communal Donation, which `restructure.md` asked about, is a card, not town code, so it stays. |
| 2 — wiring | An independent re-read of **all 396 CORRECT rows** the Phase 6 sample didn't cover. Seven verifiers had no access to the pass-1 reports or tests, and were told to test the edge paths that broke in Phase 6. | **270 agree, 106 disagree, 20 unclear.** This is the main finding of pass 2; see below. |
| 3 — environment | `env_dump.gd` + `env_audit.py` re-run on all 13 maps | None. The same 266 findings came back, identical except for Godot's auto-generated node names. |
| 5 — needs update | `needs_update.py` re-run; facts for all 74 enemies compared with Phase 5 | None. The facts are identical. |

## Phase 2 again: what the re-read found

Pass 1's CORRECT rows mostly proved each description's main path: one enemy target, one hit, a fresh state. The re-read went after the paths around it, and 126 rows failed or were unclear. Most of them come from a handful of shared causes. Each shared cause was fixed once in shared code, where that could be done safely; the rest are logged with a plan.

| Status | Rows | Meaning |
|---|---|---|
| FIXED | 28 | Code now matches the text, proved in `tests/test_pass2_fixes.gd` |
| PARTLY FIXED | 5 | The shared fix covers part of the row; the rest is BLOCKED with its cause |
| BLOCKED | 38 | Shared cause too wide or risky for the audit; plan below |
| FLAGGED | 33 | The text is ambiguous, or it's a rule-level design question; listed for you |
| OPEN → FIXED | 22 | Confirmed single-entity bugs: 21 fixed 2026-11-08, 1 kept by ruling (below) |

### Shared causes, fixed

1. **Point and area plays lost their item on-hit riders and life steal** (8 rows fixed, 5 partly).
   - A point or area card (Fireball, Spirit Arrow, Heroic Leap…) is played with you as its target, and `main.gd` lands its hits. The rider block in `Card.execute` only ran for an enemy target, so it skipped all of them:
     - Burn, Cold, Shock, Silence, Vulnerable from Fire/Frost Book, Ice Orb, Car Battery, Circe's Wand;
     - quiver, spear and belt on-self debuffs;
     - Mauls Sabre slot debuffs.
   - Life steal fell back to the card's printed damage, so a whiff still healed.
   - **Fix:** the rider block is now `Card.apply_on_hit_debuffs(enemy, stats)`, and life steal is `Card.apply_life_steal_for(dealt, …)`. `Main._apply_card_world_effects` notes every enemy's health and armor before a point/area play's effects. Afterwards it runs the riders once on each enemy that lost some, and life steal from the total actually dealt. Single-target plays are unchanged.
2. **A summon picked as the "ally" landed the effect on the caster** (10 rows). Picking a summon gave the caster the crit, heal, mana or stats instead, or aborted the swap with a script error. This hit Lady Luck, Provider, Raged Circulation, Gargle and Spit, The Light's Favor, Swap, Donate Cleats, Adrenaline Shot, Succumb and Try This.
   - **Fix:** `Main.SUMMON_ALLY_CARDS` lists the ally cards whose code does handle a summon: Heal, Healing Tonic, Gulped Potion, Fortify Alliance, Shepherd's Mark. Every other ally card refuses a summon pick, and nothing is spent. This replaces Phase 6's two-card list.
3. **Summons and a multi-tempo advance** (5 rows). Basic Block advances 4 tempo in one go. The Spirit Bow and Bull Worms took a single step for it, against their "1 square per tempo". Wolves, Draupnir's duplicate, Frankenstein's Monster and the bow also banked attack time while walking, then swung back to back on arrival, against "attacks every N tempo".
   - **Fix:** worms run once per tempo, and the bow steps once per tempo until it is in reach. Attack timers are capped at one swing, as skeletons already were.
4. **"When a hit drops you below X%" triggers judged the hit before armor.** A hit fully soaked by armor could still fire Tight Rope or Preemptive Answer.
   - **Fix:** `PlayerStats.last_health_lost` records the health a hit actually took, and the triggers use it.

### Single fixes

- **Exhausted Assault** is free at zero mana after every surcharge. Staggered used to make it unplayable.
- **Communal Donation**'s heals are capped by the health given. Each slider could reach the whole pool, so 10 HP could hand out 20.
- **Donate Cleats**' 5-tempo loan is never written to the save (`PlayerStats.lent_agility`/`lent_dexterity`). Saving mid-loan used to keep +5 AGI / +4 DEX for good.
- **Frankenstein's Screws** heals every healable summon below 25%. Clones and specters were left out.

### BLOCKED, with plans

- **Point/area plays, the rest** (12 rows): Armor Chopper, Feathered Hat, Quiver of Wet Stones, Sabre Tooth, Stringless Sender, The Rapid Recurve, the Bone-arrow skeleton, Deadly, Ladder Work, Scouted, Seance, Surprise Opener, plus the remaining halves of Reaper Scythe, Sword of Theseus and Crooked Dueling Shield. Each of these reads the card's single `target` somewhere else (armor shred before the hit, crit arming, "same target" counters, first-strike marks, kill checks).
  - **Plan:** give each the same per-enemy pass the riders now get. Move each check from `target` to the hit list `_apply_card_world_effects` builds, one item per commit, gated by the sim. Some (Ladder Work, Scouted, Surprise Opener) also need a call on what "your first/next attack" means for a card that hits three enemies.
- **Co-op: Player 2 and the hero you aren't controlling** (16 rows). Three wiring gaps:
  - (a) `Inventory.process_turn` only ticks Player 1's inventory, so Player 2's unerring armor and gauntlet cooldowns never run;
  - (b) the per-cycle helm/shield passives and the Narashimha aura read only the controlled hero;
  - (c) ring procs, `deck_shuffled`, `maintained_changed` and `damage_taken` are connected for Player 1 only.

  This hits Barbed Exterior, Cultish Wounds, Feed into the Pain, Mail Coif, Steel Plate, Strap of Stone, Medic Wraps, Momentum Mits, Techno Wraps, Spidey Web Shooters, Vanguard, Spiked Shield, Mane of Narashimha, Ring of Stone Hide, Ring of Thomas, The Precious.
  - **Plan:** route every per-hero signal and tick through `_deck_for_player`/`_stats_for_player` for both heroes, the way status ticks already loop over `_all_players()`. Add a co-op test per item.
  - FLAGGED alongside: should the inactive hero's hand and enchantments pause, as they do today? That decides Close is Favored, Defensive Sacrifice and Enchantment: Attack/Movement.
- **Generic bonuses a card's executor never reads** (6 rows). Castle Wall's and Presence of Mind's +block, Mauls Sabre's +8 block, Wooden Sword's +1 and Swing for the Fences' damage go into `block`/`bonus_damage`. Shield Ready, Repelled Block, Hunker Down, Turtle Power, Exposed Artery and Hemotoxins never read those fields. Alchemist Belt only reads `heal_amount`, which the computed-heal cards don't set. Magic Staff's +4 is lost on Chain Lightning and Ice Grenade, which recompute their damage.
  - **Plan:** each executor reads its effective value (`get_effective_block()` etc.). Where a card has no armor or damage of its own, decide with you whether "any card gets +8 block" means armor granted directly.
- **Card faces don't show item-level numbers** (3 rows): Mage Shield, Monk of the Night, Ragnarok (and Resourceful Replenish's 8%). The item's level text gives the new number, but the card face keeps the base one.
  - Related, raised by the verifiers: about 10 Legendary/Mythic items have no `level_2_description`, so at Lv.2 their text is 1 low on every stat.
  - **Plan:** card text reads the granting item's level for its numbers, and every item gets generated level-2 text.
- **Girdle of Aphrodite**: its +15 on a slotted heal aimed at a summon still goes to the caster, because the rider reads hero stats only.

### FLAGGED for you (33 rows)

- **A buff meeting one already up** (8 rows). This is one rule decision, like the open Wither note in `CLAUDE.md`. Today a re-applied non-stacking buff only refreshes its timer, and a per-attack Strengthen merges with any other Strengthen. So:
  - a second Shield Ready loses its delayed 5 armor;
  - Smith from Best Offense doesn't add;
  - Protection From Alnitak's Brace is thrown away if any Brace is up;
  - Tight Rope's or Belt of Wumbology's "+X on your next attack" rides every attack of a timed Strengthen;
  - a second Understanding restarts the first;
  - a foreign Resilient blocks Endured Tolerance's +5 tempo;
  - Dominate merges.

  Should copies stack, or run as separate instances?
- **Mana units in card text** (4 rows): Energy, Give In, Enchantment: Mana Regen, Specific Strike. This is the open x10 question from pass 1, with more cards.
- **Level-band note vs flat numbers** (6 rows): Bugbear, Earth Totem, Sabertooth Tiger, Sewer Cobra, Succubus, Weregoat. Already raised in pass 1 (`wiring/enemies_b.md`); these are the extra enemies.
- **Ambiguous text** (11 rows):
  - Enchanted Quiver's "0-cost" (mana or tempo?);
  - Sky Attack with a 0-damage card;
  - Smoke Bomb and summons;
  - Hydra's flat +40 HP;
  - Shepherd's Crook (healing received or given?);
  - Side Card Sabre (all slots or bonus slots?);
  - Smithed Excellence (does unerring armor count as block?);
  - Easy Target (any expose or yours?);
  - Let's Dance (straight-line or grid range?);
  - Territorial Death (what "re-apply" means, the Wither question again);
  - Turtle Power ("its allies").
- **Co-op pausing** (4 rows), above.

### The 22 single bugs: fixed 2026-11-08

On your go-ahead, all 22 rows that were OPEN are now dealt with. 21 are fixed, each proved in one of four test files: `tests/test_open_fixes_cards.gd`, `test_open_fixes_enemies.gd`, `test_open_fixes_items.gd`, `test_open_fixes_passives.gd`. Each test file fails without its fixes.

- **Cards:**
  - **Choke:** every Sticky use's 2 damage lands at the next cycle.
  - **Harness Lightning:** its 3-space reach counts grid steps.
  - **Lead Arrow:** needs high ground from the Bottomless Quiver too.
  - **Mirror Mirror:** copies the card itself (rank, engraving), not a fresh card.
  - **Release Tension:** can also lift Polymorph and Narashimha.
  - **Reverberate Regrowth:** fires on every armor break, one return queued per break.
  - **Savage Strike:** its copy ignores the deck-building copy cap.
  - **Shield of Growth:** DoTs and bare hits grow it too.
  - **20/20:** the +3 also applies to the point-aim click.
- **Enemies:**
  - **Archer Rat:** a nest rat follows its tooltip once it has reached its perch.
  - **Cerberus:** the third head feeds only on the wound it made; the venom aftermath lands even if he dies; summons dropping below half feed his Brace.
  - **Vampire:** each Bat Form gets its own Absorb, 20 then 10.
  - Plus `Enemy._unit_health` now reads a summon's health; it read every summon as 0.
- **Items:**
  - **Axe's Axe:** only your kills bank flash points, and only enemy blows count as "hits".
  - **Belthronding:** shares the Seance Specter's death burst.
  - **Cupid's Bow:** a blinded miss isn't "struck". Fixing it also closed a leak of `Card._exec_depth` on every Blind miss.
  - **Cyclops Ring:** excludes only hits that actually drew Strengthen.
  - **Phoenix Feather wand:** "once per play" resets for instants and quiver plays.
  - **Wizard Hat:** the +5 goes to the next spell card only, once.
- **Passives:**
  - **Directed Strength:** strictly below 50%.
  - **From the Hip:** gives back only its own discount, so Consecutive Snap keeps its reduction.
  - **Keep Them Guessing:** an instant firing or a jail release is no discard.
- **I Heal You: ruling kept.** `docs/PASSIVE_REFERENCE.md` records "Jeremy is a heal target too", so he still heals himself.

New FLAGGED from the fixes:
- **Shield of Growth.** Should self-paid costs (`take_direct_damage`: card health costs, Demonic Rage, the Bow of Arash) grow it? Self-damage cards such as Cultish Wounds and Self Infliction go through the same path. Not changed yet. Also, a hit Mind over Matter pays in mana now grows it by the full hit.
- **Axe's Axe.** Your own DoT ticks don't count as "your kill". Traps and fire tiles don't count as hits.
- **Ifrit.** The burning 5×5 hurts whoever steps in; someone standing in it is not hit again each tempo. A per-tempo hit would need a number.
- **Ice Troll.** Clobber or Club is picked 50/50 when he's in reach; the sheet gives no rule.

### What pass 2 says about pass 1

Pass 1's CORRECT rows were wrong about **27%** of the time (106 of 396), far above the 8% the Phase 6 sample suggested. The sample's verifiers were told only to "trace the description". The pass-2 verifiers were also given the edge paths to try. Treat pass 1's remaining CORRECT verdicts as "the main path works", and the 270 rows that agree here as the stronger check.

## Every pass-2 row

| # | entity | type | verdict | status | cause | evidence (verifier) |
|---|---|---|---|---|---|---|
| 1 | Adrenaline Shot (`adrenaline_shot`) | card | UNCLEAR | FIXED | A summon picked as the "ally" landed the effect on the caster | main.gd:12697-12702 — a summon "ally" target has no hand, so the caster's hand (deck_manager) is cut instead of "the target's hand" |
| 2 | Barbed Exterior (`barbed_exterior`) | card | DISAGREE | BLOCKED | Co-op: Player 2 or the hero you are not controlling | co-op: P2's maintain lifecycle is unwired (main.gd:617/3791 hook only P1's deck/stats; 6890 breaks the ACTIVE deck) so P2's 5 thorns (card.gd:4255) outlive the maintain rule |
| 3 | Best Offense is a Good Defense (`best_offense`) | card | DISAGREE | FLAGGED | A buff meeting one already up (merge / refresh rules) | buff_manager.gd:129-139 + 189-194: Smith is not stackable, so a 2nd copy (or 6-Smith play) over a live Smith keeps the OLD value (decayed by 1/cycle at 381-390) |
| 4 | Choke (`choke`) | card | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | enemy.gd:7553-7554 stacks add, 1871-1874 pop ONE stack per cycle: a 2nd/3rd Sticky use in the same cycle deals its 2 dmg 1-2 cycles later, not "at the next cycle" |
| 5 | Close is Favored (`close_is_favored`) | card | UNCLEAR | FLAGGED | Co-op: Player 2 or the hero you are not controlling | solo OK (main.gd:6099-6111, 11161-11172); co-op: only the ACTIVE hero's distance/hand is checked, so the inactive hero's copy never springs |
| 6 | Communal Donation (`communal_donation`) | card | DISAGREE | FIXED | Single-entity bugs | **Heals capped by the health given.** main.gd:15383-15400 each ally slider max = whole pool, 15424-15440 no sum cap: with 2+ allies you heal more than the HP you gave |
| 7 | Cultish Wounds (`cultish_wounds`) | card | DISAGREE | BLOCKED | Co-op: Player 2 or the hero you are not controlling | co-op: main.gd:7539 ticks only the ACTIVE deck's maintained pile, and 3791/6890 break the active deck on P1's mana-out: "Repeat every 5 tempo"/Maintain don't follow the owner |
| 8 | Defensive Sacrifice (`defensive_sacrifice`) | card | UNCLEAR | FLAGGED | Co-op: Player 2 or the hero you are not controlling | solo OK (main.gd:5527-5560 halve, +10 mana, decline keeps); co-op: 5533 refuses when the struck hero isn't the active one, so the inactive hero's copy is never offered |
| 9 | Donate Cleats (`donate_cleats`) | card | DISAGREE | FIXED | Single-entity bugs | **Saving mid-loan no longer keeps the stats; a summon pick is refused.** main.gd:12620-12633 mutates base_agility/base_dexterity and reverts via an unsaved delayed effect (7823); a ? save or town travel inside the 5 tempo bakes +5/+4 in (player_stats.gd:883). Summon "ally" target -> caster gets it |
| 10 | Enchanted Quiver (`enchanted_quiver`) | card | UNCLEAR | FLAGGED | Description ambiguous | main.gd:9455-9460 Quick Arrow added; data/cards/quick_arrow.tres is 0 mana but tempo_cost 2 — "free 0-cost" = 0 mana, or nothing at all? |
| 11 | Enchantment: Attack (`enchantment_attack`) | card | UNCLEAR | FLAGGED | Co-op: Player 2 or the hero you are not controlling | solo OK (main.gd:7629-7651, player_stats.gd:1628/1646, 7725-7740); co-op: _process_enchantment_cycles runs on the active hand only, so a held copy never fades while its hero is inactive |
| 12 | Enchantment: Mana Regen (`enchantment_mana_regen`) | card | DISAGREE | FLAGGED | Mana units in card text (x10) | main.gd:7647 adds 10.0 regen; character_panel.gd:657 shows regen raw (base 10.0/cycle), so "+1 mana regen" is 10x off |
| 13 | Enchantment: Movement (`enchantment_movement`) | card | UNCLEAR | FLAGGED | Co-op: Player 2 or the hero you are not controlling | solo OK (player_stats.gd:1300 +5 moves of flash per refresh); same co-op no-fade issue as Enchantment: Attack |
| 14 | Endured Tolerance (`endured_tolerance`) | card | DISAGREE | FLAGGED | A buff meeting one already up (merge / refresh rules) | buff_manager.gd:71-83 merges into ANY all-type Resilient; if Smithed Excellence/Succumb's came first, source differs and a 2nd copy only max()es duration, not +5 |
| 15 | Energy (`gain_mana`) | card | DISAGREE | FLAGGED | Mana units in card text (x10) | card.gd:2785-2788 gain_mana(20) vs "Gain 2 mana" — raw-scale mana elsewhere (Defensive Sacrifice "10 mana" = 10, main.gd:5552) |
| 16 | Exhausted Assault (`exhausted_assault`) | card | DISAGREE | FIXED | Single-entity bugs | **Free at zero mana after every surcharge.** deck_manager.gd:616-617 zeroes the cost, then 666-669 add Staggered/Hex surcharges on top: at 0 mana under Stagger it isn't 0 and can't be played |
| 17 | Feed into the Pain (`feed_into_the_pain`) | card | DISAGREE | BLOCKED | Co-op: Player 2 or the hero you are not controlling | main.gd:3790 hooks only P1's damage_taken; 15814-15840 read the ACTIVE hero's health/hand: P2 hits never fire, P1 hits while P2 active fire P2's copy |
| 18 | Gargle and Spit (`gargle_and_spit`) | card | DISAGREE | FIXED | A summon picked as the "ally" landed the effect on the caster | card.gd:4324-4331 ignores target: a summon "ally" target (allowed, ally in target_types) heals and buffs the CASTER, the summon gets nothing |
| 19 | Give In (`give_in`) | card | DISAGREE | FLAGGED | Mana units in card text (x10) | card.gd:4387-4393 gain_mana(30) vs "Immediately gain 3 mana" (same 10x scale issue); skip draw OK (draw_timer.gd:39-40) |
| 20 | Harness Lightning (`harness_lightning`) | card | DISAGREE (minor) | FIXED (2026-11-08) | Single-entity bugs | 6 ticks x5 tempo main.gd:13210-13213; INT via get_effective_spell_damage main.gd:7916; but range is 3D `distance_to <= 3.0` main.gd:7911 — an enemy 3 tiles straight away on a different floor elevation (y differs, ELEV_STEP 0.06) is never picked |
| 21 | Lady Luck | card | DISAGREE | FIXED | A summon picked as the "ally" landed the effect on the caster | "Bless an ally": a summon is a legal ally pick (main.gd:13991-13995, not in HERO_ONLY_ALLY_CARDS main.gd:4601) but execute_deferred_card keeps the caster's buff_mgr for non-Player targets (deck_manager.gd:1029-1039) so the CASTER gets the +30% crit (card.gd:3381-3384) |
| 22 | Lead Arrow | card | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | "Requires high ground" only checked on the hand enemy-click path main.gd:13960; a Bottomless Quiver manifest play (overflow_manager.gd:216, main.gd:14620-14628 -> 13929-13934 -> play_quiver_card main.gd:14727-14784) never checks it |
| 23 | Mage Shield | card | DISAGREE (item level) | BLOCKED | Card faces don't show the item-level numbers | face "gain 10 block"; Delfins Lv.2+ gives 15 (card.gd:2094-2097) and the face is never updated (vacuum block main.gd:8804-8825 ignores it) |
| 24 | Mirror Mirror | card | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | "Duplicate a card": copy is a fresh create_by_id(card_id) card.gd:4104 — loses per-instance state: a rank-scaled Magic Barrier ("Gain 12 armor", card.gd:4447-4452) copies as "Gain 8 armor"; an engraved Regal Etching copy is unslotted so unplayable (deck_manager.gd:747-749) |
| 25 | Monk of the Night | card | DISAGREE (item level) | BLOCKED | Card faces don't show the item-level numbers | face "10% of their damage"; Umbral Eclipse Lv.3 gives 15% card.gd:2508; face not updated |
| 26 | Preemptive Answer | card | DISAGREE | FIXED | "Drop below X%" triggers judged on the hit before armor | **Fires on the health the hit actually took.** "when you drop to 25% health": trigger compares pct<=0.25 with prev_pct=(hp+amount)/max main.gd:15818,15826, but `amount` is the PRE-armor/pre-resist hit (player_stats.gd:1996), so a hit armor fully absorbs while you're already <=25% fires it with no drop |
| 27 | Protection From Alnitak | card | DISAGREE | FLAGGED | A buff meeting one already up (merge / refresh rules) | "Brace percentage equals your empty hand slots": if any Brace is already up, apply_buff keeps the old value (BRACE not stackable, value never replaced) buff_manager.gd:129-141,192-197 — new % is lost (a 0% or Parry's typed Brace stays) |
| 28 | Provider | card | DISAGREE | FIXED | A summon picked as the "ally" landed the effect on the caster | "Heal an ally 6 health and give them 1 mana": summon pick allowed (main.gd:13991-13995); non-Player target keeps caster stats (deck_manager.gd:1029-1034) and _execute_provider heals/gives mana to player_stats card.gd:4378-4385 — caster healed, summon not |
| 29 | Raged Circulation | card | DISAGREE | FIXED | A summon picked as the "ally" landed the effect on the caster | "Target receives 30% more…": summon pick allowed (main.gd:13991-13995) but boost lands on caster's stats card.gd:3408-3413 via deck_manager.gd:1029-1034 |
| 30 | Ragnarok | card | DISAGREE (item level) | BLOCKED | Card faces don't show the item-level numbers | face "heal 10 … 5 STR"; Hide of Garmr Lv.3 does 15 / 7 card.gd:2021-2023; face not updated |
| 31 | Release Tension | card | DISAGREE (minor) | FIXED (2026-11-08) | Single-entity bugs | "Remove a stack of any debuff": RELEASE_TENSION_DEBUFFS main.gd:5190-5200 omits polymorph and narashimha (enemy.gd apply_debuff arms) — those can't be picked or removed |
| 32 | Resourceful Replenish | card | DISAGREE | PARTLY FIXED | Point and area plays (target = you) skipped the item on-hit riders and life steal | **Life steal now follows the hits and skips a whiff; the Lv.3 8% vs the card's 5% is the item-level text cause (BLOCKED).** "heal you for 5% of the damage dealt": lifesteal reads last_damage_dealt set before any hit (card.gd:2476-2480); Heroic Leap/Peshtigo set it in execute (card.gd:3179, 4406) so landing on empty ground still heals; multi-target AoE heals off one hit; Hannibals Mask Lv.3 8% vs face 5% |
| 33 | Reverberate Regrowth | card | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | "when your armor is broken through": only fires when try_expose() succeeds player_stats.gd:1929-1933 -> main.gd:11831-11840; a break inside the 10-tempo Exposed cooldown returns nothing; a second break within 5 tempo overwrites the pending return |
| 34 | Savage Strike | card | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | card.gd:4205 add_card_to_deck_from_id → deck_manager.gd:1341 copy cap (copy is RARE, card.gd:344 → cap 4, card.gd:60); copies only burn in hand (deck_manager.gd:1211) so 5th play adds nothing |
| 35 | Shield of Growth | card | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | player_stats.gd:1991 needs the buff_mgr arg; DoTs call take_damage(dmg) without it (debuff_manager.gd:233, 592, 610) so Burn/Poison/Bleed damage grows no armor |
| 36 | Shield Ready | card | DISAGREE | FLAGGED | A buff meeting one already up (merge / refresh rules) | buff_manager.gd:129-134: a 2nd SHIELD_READY (not stackable, :192) only refreshes the duration → one delayed +5 for two copies, and the first copy's armor comes later |
| 37 | sky_attack | card | UNCLEAR | FLAGGED | Description ambiguous | card.gd:3590-3593: a 0-damage discard whiffs (0 dealt, no +4 High Ground); text "use its damage … then gain the High Ground damage bonus" could mean 0+4 |
| 38 | smoke_bomb | card | UNCLEAR | FLAGGED | Description ambiguous | main.gd:11613-11633 covers only _all_allies() (players + dojo), never summons, though main.gd:4610-4612 calls summons "allies for card text"; also effect only from next tick, lingers 2 tempo |
| 39 | specific_strike | card | UNCLEAR | FLAGGED | Mana units in card text (x10) | deck_manager.gd:613-614 adds +10 mana per other card; text says "+1m" (project's "card-counted mana" ×10, cf. CARD_REFERENCE try_this) |
| 40 | spirit_bow | card | DISAGREE | FIXED | A multi-tempo advance moved a summon one step; a walk banked attacks | main.gd:10766-10768 at most 1 square per tempo_advanced call (`if`, not `while`); a 4-tempo Basic Block (main.gd:2858/2898, one emit) moves it 1 square, not 4 |
| 41 | succumb | card | UNCLEAR | FIXED | A summon picked as the "ally" landed the effect on the caster | main.gd:12686 `caster = target if target is Player else player`: a summon picked as the ally (main.gd:13991-13995 allows it) makes the CASTER take the buffs, 20 damage and debuffs |
| 42 | swap | card | DISAGREE | FIXED | A summon picked as the "ally" landed the effect on the caster | main.gd:13534-13543 sets target.target_position; summons only have _target_position (summon.gd:43) → script error aborts; summon glides back onto the player's tile. Probe confirmed |
| 43 | the_lights_favor | card | DISAGREE | FIXED | A summon picked as the "ally" landed the effect on the caster | card.gd:4306-4312: a summon target (allowed, main.gd:13991-13995) isn't a Player → the CASTER heals 5 and draws; the summon gets nothing |
| 44 | tight_rope | card | DISAGREE | FLAGGED | A buff meeting one already up (merge / refresh rules) | **Trigger half FIXED (health actually lost); the Strengthen merge half FLAGGED.** (a) buff_manager.gd:107-118/129-139 Strengthen merge: with Strengthen already up, the +15 rides every attack of the existing buff, not just the next one; (b) main.gd:15817 prev_pct uses the pre-armor amount (player_stats.gd:1996) → fires when already <20% if armor absorbed the hit |
| 45 | try_this | card | UNCLEAR | FIXED | A summon picked as the "ally" landed the effect on the caster | main.gd:13217-13240 gives +30 max mana for "+3 mana pool" (×10 convention); with no partner (or a summon picked) it lands on the caster (tt_stats fallback) although the text says "Ally" |
| 46 | twenty_twenty | card | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | main.gd:14052-14055: a point-aimed ranged offensive card (Fireball, Sprinkle Bomb, Poison Bomb…) is capped by card.get_effective_range() with no _helm_range_bonus → no +3 (the indicator at main.gd:8642 does show +3) |
| 47 | understanding | card | DISAGREE | FLAGGED | A buff meeting one already up (merge / refresh rules) | card.gd:3481 `understanding_tempo = 10` overwrites: a 2nd copy during the delay restarts the clock and only one auto-crit is ever granted (buff_manager.gd:340-345) |
| 48 | worms_armageddon | card | DISAGREE | FIXED | A multi-tempo advance moved a summon one step; a walk banked attacks | the worms' "1 movement per tempo": main.gd:5757 _update_summoned_worms() takes no amount and moves 1 tile per call (main.gd:14956) → 1 tile on a 4-tempo Basic Block |
| 49 | Archer Rat | enemy | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | enemy.gd:2626-2632: a nest-released rat (perch_cell set) shoots at range ≤2 and never closes in past 6, against the tooltip enemy.gd:1213 "≤2: Scurries… >6: Moves 2 tiles closer" |
| 50 | Bugbear | enemy | DISAGREE | FLAGGED | Flat numbers vs the level-band note | band-note: First Strike "+8 damage" is raw at enemy.gd:3842 while note says damage x1.30 (Strike 6→8 is scaled) |
| 51 | Cerberus | enemy | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | 3rd head heals full `dmg` even if no wound (2985); venom aftermath lost if he dies (1576 return before 1651); Guardian scans players only, not summons (3062, 2940-2953) |
| 52 | Earth Totem | enemy | DISAGREE | FLAGGED | Flat numbers vs the level-band note | band-note: thorns "costs the attacker 5" raw at 7173 (TOTEM_EARTH_THORNS) while note says damage x1.25; heal 4/5 tempo ok 4624-4629 |
| 53 | Hydra | enemy | UNCLEAR | FLAGGED | Description ambiguous | "+40 max HP" is flat at 6970 while note says "actual HP x1.30" — note may mean only base HP |
| 54 | Sabertooth Tiger | enemy | DISAGREE | FLAGGED | Flat numbers vs the level-band note | band-note: Bite 6 / Claw 3 / Sunken Bite 10 raw at 5375, 5377, 5385 while note says damage x1.30 |
| 55 | Sewer Cobra (SEWER_CROC) | enemy | DISAGREE | FLAGGED | Flat numbers vs the level-band note | band-note: Venom Spray "10 damage" raw at 2875 (comment says deliberate) while note says damage x0.90 |
| 56 | Succubus | enemy | DISAGREE | FLAGGED | Flat numbers vs the level-band note | band-note: Damaging Snap "+ 4" raw at 5961 while note says damage x1.30 |
| 57 | Vampire | enemy | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | two hits under 50% before Absorb fires spend both charges (7127-7135) → one Absorb of 10 (4426); probe confirmed |
| 58 | Weregoat | enemy | DISAGREE | FLAGGED | Flat numbers vs the level-band note | band-note: Charge "8 damage" raw at 5172 / 5135 while note says damage x1.30 |
| 59 | alchemeist_belt | item | DISAGREE | BLOCKED | Generic bonuses (+block, +damage, +heal) added to a field the card's executor never reads | +4% only when heal_amount > 0 (card.gd:1501); the game's own heal cards with computed heals (Card.HEAL_CARD_IDS 1387: Biscuit, Meditate, Hope This Works, Down but not out…) get nothing |
| 60 | armor_chopper | item | DISAGREE | BLOCKED | Point and area plays: riders that still read the card's single `target` | shred hits only the single `target` (card.gd:1774-1779); point melee attacks (Charge, Heroic Leap) pass the caster as target → no shred on anything hit |
| 61 | assasian_belt | item | DISAGREE | FIXED | Point and area plays (target = you) skipped the item on-hit riders and life steal | Vulnerable rider needs a non-player `target` (card.gd:2586, 2611-2613); its own Shuriken (target self, hit resolved in main 13242-13251) and point cards apply none |
| 62 | axes_axe | item | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | flash points bank on every enemy death, not your kills (enemy_spawner 214-217 → inventory 1173-1180): Ice Totem fusing itself, mimics collapsing, Sear Wounds kills |
| 63 | belt_of_wumbology | item | DISAGREE | FLAGGED | A buff meeting one already up (merge / refresh rules) | Strengthen +10/2 attacks merges into an existing Strengthen (buff_manager.gd:105-117 timed → every attack; 129-138 charges=max, value stacks) |
| 64 | belthronding | item | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | share wired for every summon's damage except the Seance Specter's death burst (main.gd:10190-10198 calls killer.take_damage with no _belthronding_share); conjure cap 3 OK main.gd:11233-11244 |
| 65 | car_battery | item | DISAGREE | FIXED | Point and area plays (target = you) skipped the item on-hit riders and life steal | Staff subtype → bonus slots take only STAFF cards (item_data.gd:925), nearly all point/AoE (Fireball etc.); their target is the player so card.gd:2586 guard skips the Shock, and main.gd:12704-12716 applies none |
| 66 | castle_wall | item | DISAGREE | BLOCKED | Generic bonuses (+block, +damage, +heal) added to a field the card's executor never reads | "+8 block (armor on a card that blocks nothing)": a slotted DEFENSE card with no block of its own (Hunker Down, Buckler label) takes the block-field branch card.gd:1464-1466; its executor card.gd:4277-4281 never reads block → 8 lost |
| 67 | circes_wand_of_cauldron_stirring | item | DISAGREE | FIXED | Point and area plays (target = you) skipped the item on-hit riders and life steal | "Your damaging offensive cards Silence": rider only in card.gd:2586-2660 single-target post-hit block (target must not be a player); point/AoE cards (Fireball, Spirit Arrow…) get target=player (main.gd:14044) → no Silence. Polymorph trigger also UNCLEAR (see report) |
| 68 | crooked_dueling_shield | item | DISAGREE | PARTLY FIXED | Point and area plays (target = you) skipped the item on-hit riders and life steal | **1 Weaken on hit FIXED for point/area plays; the crit Weaken still falls back to the caster on an area crit (BLOCKED).** slot Weaken/Vulnerable (card.gd:2662-2668) and crit rider (card.gd:2752-2765) need an enemy target; Heroic Leap (Buckler-labelled point AoE) passes the player → no Weaken on hit, no crit Weaken (Player has no apply_debuff) |
| 69 | cupids_bow | item | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | "An enemy struck by both arrows": a blinded miss returns before damage (card.gd:1443-1445) but main.gd:13119-13138 still lays Vulnerable/Weaken, taunt/fear and the Cupid mark (world effects run unconditionally main.gd:9412) |
| 70 | cyclops_ring | item | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | "the strengthened hits don't feed the counter": exclusion is a blind 2-hit counter main.gd:11598-11601 that any damaging card consumes; spells don't spend Strengthen (buff_manager.gd:603-619) → a spell eats a slot and the 2nd Strengthened attack then feeds the counter |
| 71 | cyde_livingstons_sneakers | item | DISAGREE | FIXED | A summon picked as the "ally" landed the effect on the caster | Donate Cleats "to an ally": target_types ally lets a summon be clicked (main.gd:13991-13995, not in HERO_ONLY_ALLY_CARDS main.gd:4601) but main.gd:12622 falls back to the caster (summons lack get_stats) |
| 72 | feathered_hat | item | DISAGREE | BLOCKED | Point and area plays: riders that still read the card's single `target` | "next ranged offensive card crits": armed crit consumed by any ranged offensive card card.gd:1699-1703, but Balistic Arrow (card.gd:2434-2435 _compute_attack_damage w/o buff_mgr, card.gd:4402) never rolls a crit → wasted |
| 73 | fire_quiver | item | DISAGREE | FIXED | Point and area plays (target = you) skipped the item on-hit riders and life steal | "offensive cards that hit apply 1 Burn": Spirit Arrow (ARROW-labelled point line) gets target=player → card.gd:2586 guard skips Burn; main.gd:12854-12866 only take_damage |
| 74 | frankensteins_screws | item | DISAGREE | FIXED | Single-entity bugs | **Every healable summon (clones and specters were left out).** "When your summons are below 25%… heal 3": aura list main.gd:12081-12087 omits _specters and _clones (both HealableSummon) |
| 75 | frost_book | item | DISAGREE | FIXED | Point and area plays (target = you) skipped the item on-hit riders and life steal | "Your damaging offensive cards apply 1 Cold": point/AoE cards (Fireball main.gd:12704-12716) never get it; card.gd:2586 needs a non-player target (+1 damage does land) |
| 76 | frost_quiver | item | DISAGREE | FIXED | Point and area plays (target = you) skipped the item on-hit riders and life steal | same as Fire Quiver: slotted Spirit Arrow → no Cold (card.gd:2586, main.gd:12854-12866) |
| 77 | girdle_of_aphrodite | item | DISAGREE | BLOCKED | A summon picked as the "ally" (item rider) | **The +15 on a slotted heal aimed at a summon still goes to the caster: Girdle's rider reads hero stats only.** "utility/defense cards heal their target 15": slotted Heal/Gulped Potion aimed at a summon (allowed, main.gd:13991-13995) heals the caster — card.gd:2549-2555 falls back when target has no get_stats |
| 78 | ice_orb | item | DISAGREE | FIXED | Point and area plays (target = you) skipped the item on-hit riders and life steal | same as Frost Book: "Your damaging offensive cards apply 2 Cold" misses every point/AoE card (card.gd:2586, main.gd:12704-12716) |
| 79 | magic_staff | item | DISAGREE | BLOCKED | Generic bonuses (+block, +damage, +heal) added to a field the card's executor never reads | "+4 on damaging offensive cards": Chain Lightning main.gd:12471 / Ice Grenade main.gd:12493 recompute from base 10/5, bonus_damage ignored |
| 80 | mail_coif | item | DISAGREE | BLOCKED | Co-op: Player 2 or the hero you are not controlling | solo OK (inventory.gd:1037-1045); CO-OP-A: P2 never gains the 5 unerring armor |
| 81 | mane_of_narashimha | item | DISAGREE | BLOCKED | Co-op: Player 2 or the hero you are not controlling | aura stamped once per cycle by distance at that instant (main.gd:12156-12159), not live; CO-OP-B: only controlled player's helm/position |
| 82 | mauls_sabre | item | DISAGREE | PARTLY FIXED | Point and area plays (target = you) skipped the item on-hit riders and life steal | **Weaken / combo Vulnerable on point cards FIXED; the +8 block on a card that never reads block is the unread-bonus cause (BLOCKED).** blue "applies 1 Weaken on hit"/combo Vuln skipped for point cards (Fireball): card.gd:2586 `not target.has_method("get_stats")`; blue +8 block lost on Turtle Power (probe: +0) |
| 83 | medic_wraps | item | DISAGREE | BLOCKED | Co-op: Player 2 or the hero you are not controlling | **Also solo: the skill fires with no target and always heals you.** "heal an ally": skill fires with null target (main.gd:3378) → always heals self (inventory.gd:1486); also CO-OP-A cooldown |
| 84 | momentum_mits | item | DISAGREE | BLOCKED | Co-op: Player 2 or the hero you are not controlling | on-self draw OK card.gd:1794; CO-OP-A: P2's Continue to move never comes off cooldown |
| 85 | presence_of_mind | item | DISAGREE | BLOCKED | Generic bonuses (+block, +damage, +heal) added to a field the card's executor never reads | PoM block added to `block` (card.gd:1626) but Shield Ready/Repelled Block add base_block (card.gd:3947/3961), Hunker Down reads none — probe: +5/+5/+0 instead of +25/+25/+20 |
| 86 | quiver_of_wet_stones | item | DISAGREE | BLOCKED | Point and area plays: riders that still read the card's single `target` | armor shred needs `"current_armor" in target` (card.gd:1689); point arrows (Spirit Arrow) target the Player node → no shred; line damage main.gd:12862 |
| 87 | reaper_scythe | item | DISAGREE | PARTLY FIXED | Point and area plays (target = you) skipped the item on-hit riders and life steal | **Vulnerable on point/area hits FIXED; its above/below-half life and mana still read the single target only (BLOCKED, area-rest).** Vuln/lifesteal/mana skipped for point cards (Fireball, card.gd:2586 & 2489 need enemy target) and for Chain Lightning (last_damage_dealt 0) |
| 88 | ring_of_stone_hide | item | DISAGREE | BLOCKED | Co-op: Player 2 or the hero you are not controlling | solo OK inventory.gd:1148-1152 / main.gd:11305; CO-OP-C: P2's stone skin never fires |
| 89 | ring_of_thomas_the_train_tracks | item | DISAGREE | BLOCKED | Co-op: Player 2 or the hero you are not controlling | solo OK inventory.gd:1375-1381; CO-OP-C: P2's shuffles never fire it |
| 90 | sabre_tooth | item | DISAGREE | BLOCKED | Point and area plays: riders that still read the card's single `target` | "same target twice": two point-target casts both pass the Player node as target → card.gd:2522 counts it, extra attack-speed tick |
| 91 | shepherds_crook | item | UNCLEAR | FLAGGED | Description ambiguous | "All your healing heals 5 more": healing you cast on a partner uses the partner's healing_bonus (player_stats.gd:1650) |
| 92 | side_card_sabre | item | UNCLEAR | FLAGGED | Description ambiguous | "its slotted cards cost 1 less tempo": plain-slot cards get neutral bonus (item_data.gd:186-189) → no -1 |
| 93 | smithed_excellence | item | UNCLEAR | FLAGGED | Description ambiguous | "while you have block": checks current_armor only (player_stats.gd:1838) — unerring armor alone gives no 10% |
| 94 | spidey_web_shooters | item | DISAGREE | BLOCKED | Co-op: Player 2 or the hero you are not controlling | disarm OK card.gd:2702-2706; CO-OP-A: P2's Coming in! never recharges |
| 95 | spiked_shield | item | DISAGREE | BLOCKED | Co-op: Player 2 or the hero you are not controlling | solo OK main.gd:11868; CO-OP-B: uncontrolled partner gains no Thorns |
| 96 | steel_plate | item | DISAGREE | BLOCKED | Co-op: Player 2 or the hero you are not controlling | solo OK; CO-OP-A: P2 never gains the 8 unerring armor |
| 97 | strap_of_stone | item | DISAGREE | BLOCKED | Co-op: Player 2 or the hero you are not controlling | resilient/Stone Encase OK; CO-OP-A: P2 never gains the periodic 10 unerring armor |
| 98 | stringless_sender | item | DISAGREE | BLOCKED | Point and area plays: riders that still read the card's single `target` | point-target arrow: bounce picks enemy nearest the PLAYER (main.gd:11264-11269, target = Player) → can re-hit an enemy the line already hit |
| 99 | sword_of_theseus | item | DISAGREE | PARTLY FIXED | Point and area plays (target = you) skipped the item on-hit riders and life steal | **2 Slow on point/area hits FIXED; the +1 per Slow already on the target still reads the single target (BLOCKED).** point-target Heroic Leap (Sword label): Slow and +dmg/Slow need enemy target (card.gd:2586, 1628) → none applied; AoE at main.gd:13424 |
| 100 | techno_wraps | item | DISAGREE | BLOCKED | Co-op: Player 2 or the hero you are not controlling | effect OK inventory.gd:1498; CO-OP-A: P2's skill never recharges |
| 101 | the_precious | item | DISAGREE | BLOCKED | Co-op: Player 2 or the hero you are not controlling | solo OK inventory.gd:1228 / main.gd:11362; CO-OP-C: P2 never enters shadow form |
| 102 | the_rapid_recurve | item | DISAGREE | BLOCKED | Point and area plays: riders that still read the card's single `target` | Double Shot needs `"is_dead" in target` (main.gd:11250); point arrows (Spirit Arrow/Sky Fall) target the Player node → no second shot |
| 103 | vanguard | item | DISAGREE | BLOCKED | Co-op: Player 2 or the hero you are not controlling | flat reduction OK player_stats.gd:1855; CO-OP-B: uncontrolled partner gains no Regen |
| 104 | wand_of_the_phoenix_feather | item | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | "once per play": flag reset only at main.gd:9211 (_resolve_queued_card); instants (Gift from the Phoenix, main.gd:6591-6609 apply 5 Burn) never reset it, so their Burn doesn't singe after an earlier singeing play (main.gd:6063-6066). |
| 105 | wizard_hat | item | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | pending_spell_power_bonus is read by every get_effective_spell_damage call (player_stats.gd:1646) but only cleared by a spell card (card.gd:2734): Harness Lightning ticks (main.gd:7916), flame-zone ticks (main.gd:10967), snowballs (main.gd:8114) all get +5 while armed, repeatedly. |
| 106 | wooden_spear | item | DISAGREE | FIXED | Point and area plays (target = you) skipped the item on-hit riders and life steal | on-self Bleed only applied to a single non-player target (card.gd:2586-2624); Sweeping Disarm (spear-slottable, card.gd:223) targets the player (main.gd:14043-14044) and deals its damage in main.gd:13558-13565 — no Bleed on any enemy hit. |
| 107 | wooden_sword | item | DISAGREE | BLOCKED | Generic bonuses (+block, +damage, +heal) added to a field the card's executor never reads | +1 rides bonus_damage (card.gd:1461-1462); Exposed Artery (sword-slottable, card.gd:125) computes damage without bonus_damage (card.gd:4219-4231) → no +1. |
| 108 | Deadly | passive | DISAGREE | BLOCKED | Point and area plays: riders that still read the card's single `target` | point/area card: flat +X judged on enemy nearest the aim (main.gd:9333-9335) but crit-damage flag uses `target` (=player) → st_deadly_crit_active false (progression_triggers.gd:1506-1507, 1475-1477): +X yes, +% crit damage never. |
| 109 | Directed Strength | passive | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | (minor) "below 50% health": player_stats.gd:711 `> 0.5` returns 0, so exactly 50% grants it, and get_health_percent counts temp HP (player_stats.gd:1124). |
| 110 | Dominate | passive | UNCLEAR | FLAGGED | A buff meeting one already up (merge / refresh rules) | progression_triggers.gd:1633-1655 matches; but "+X Strengthen for 3 attacks" merges with any live charge-based Strengthen (buff_manager.gd:130-139): values add, charges = max, so earlier/later values outlive their stated attack counts. |
| 111 | Easy Target | passive | UNCLEAR | FLAGGED | Description ambiguous | fires on any expose: enemy.gd:7168 → main.gd:6083 → progression_triggers.gd:1550, no source check — DoT ticks (enemy.gd:7248 take_damage(…, false)), summon bites, a partner's hit all trigger it. "When exposing your enemy" = you expose vs. the enemy becomes exposed. |
| 112 | From the Hip | passive | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | restore writes the snapshot cost back (progression_triggers.gd:663-666) after the card's own execute: Consecutive Snap (attack, sticky) drawn → reset to 30/3 (deck_manager.gd:486-488) → discounted → executes to 20/2 (card.gd:3697-3698) → restored to 30/3, i.e. losing the discount also wipes Snap's own reduction. |
| 113 | I Heal You | passive | DISAGREE | RULING KEPT | Single-entity bugs | "Allies within 3 squares of you are healed": _all_allies includes the player (main.gd:4603-4608) and progression_triggers.gd:1993-1994 heals Jeremy himself 3 — solo, it heals only him. |
| 114 | Keep Them Guessing | passive | DISAGREE | FIXED (2026-11-08) | Single-entity bugs | counts every non_play_discard (main.gd:7266) incl. an instant firing (deck_manager.gd:1437-1438, 1462) and a jail release (deck_manager.gd:1157-1158) — not discards (cf. deck_manager.gd:1488-1490 "spending it, not discarding it"). |
| 115 | Ladder Work | passive | DISAGREE | BLOCKED | Point and area plays: riders that still read the card's single `target` | bank spent only when `target is Enemy` (progression_triggers.gd:869-870): an AoE/point attack (target = player, main.gd:14043-14044, 9369) as the cycle's first attack gets nothing and the bank goes to a later attack; also fires on a blind miss (card.gd:1443-1445 returns, main.gd:9369 still runs). |
| 116 | Let's Dance | passive | UNCLEAR | FLAGGED | Description ambiguous | "within 3 range": progression_triggers.gd:1019-1022 uses Euclidean world distance ≤3.0 (reaches a (2,2) diagonal, Manhattan 4) while card range is Manhattan cells (grid_manager.gd:105-109). |
| 117 | Scouted | passive | DISAGREE | BLOCKED | Point and area plays: riders that still read the card's single `target` | auto-crit armed for any attack while bonus active, no target check (progression_triggers.gd:1511-1512), but consumed only when `target is Enemy` (1377-1383): AoE/point attacks (target = player) auto-crit every time without spending it. |
| 118 | Seance | passive | DISAGREE | BLOCKED | Point and area plays: riders that still read the card's single `target` | "targets an empty tile": emptiness tested after the card resolved and its world effects ran (main.gd:9411 then 9447 → progression_triggers.gd:2066-2072): a point card aimed at an enemy's tile that kills/moves it raises a Specter there. |
| 119 | Surprise Opener | passive | DISAGREE | BLOCKED | Point and area plays: riders that still read the card's single `target` | "Your first strike on an enemy": only runs for an Enemy `target` (progression_triggers.gd:844); AoE/point offensive cards (target = player) neither pay nor mark, so the next single-target hit counts as "first"; auto attacks never; a blind miss still pays (card.gd:1443-1445 vs main.gd:9369). |
| 120 | Swing for the Fences | passive | DISAGREE | BLOCKED | Generic bonuses (+block, +damage, +heal) added to a field the card's executor never reads | with an Enemy target the bonus is folded into bonus_damage (progression_triggers.gd:1420-1423) even if the card never reads it: Hemotoxins (5 tempo, card.gd:1921-1929) → 0 extra damage. |
| 121 | Territorial Death | passive | UNCLEAR | FLAGGED | Description ambiguous | progression_triggers.gd:1949-1977 apply_debuff(key, 1): +1 stack on stack debuffs, +1 tempo on additive timers, no-op on max-timers (stun/silence: enemy.gd ~7524/7547) and Mark (7540) yet the cooldown is spent — what "re-apply" means per debuff (same open question as Wither). |
| 122 | Alaskan Bull Worm | summon | DISAGREE | FIXED | A multi-tempo advance moved a summon one step; a walk banked attacks | "1 movement per tempo": _update_summoned_worms takes no amount (main.gd:14901) and runs once per tempo_advanced (main.gd:5758); Basic Block adds 4 tempo in one emit (main.gd:2858/2898, tempo_manager.gd:346) → 1 step (and 1 bite) for 4 tempo. |
| 123 | Battle Turtle / Turtle Power | summon | UNCLEAR | FLAGGED | Description ambiguous | "whenever it gains armor, so do its allies": main.gd:10515-10531 gives it to players and other turtles only — not dojo allies (in _all_allies, main.gd:4605) nor armor-holding summons (wolves/specters, markable_summon.gd:11). |
| 124 | Bone-arrow skeleton (Sack of Bone Arrows) | summon | DISAGREE | BLOCKED | Point and area plays: riders that still read the card's single `target` | "a kill with an offensive card raises a skeleton": only if the single `target` died (main.gd:11279-11281), run before the per-card effects (main.gd:12404); Spirit Arrow / Sky Fall (Arrow-slottable point cards, target = player) never raise one. |
| 125 | Draupnir's duplicate (summoned_clone) | summon | DISAGREE | FIXED | A multi-tempo advance moved a summon one step; a walk banked attacks | "attacks … every 7 tempo": attack_accum += amount every tick, uncapped, while walking (main.gd:~11488); once adjacent it swings once per tick until the bank drains. Skeletons cap theirs (main.gd:~10377). |
| 126 | Frankensteins Monster | summon | DISAGREE | FIXED | A multi-tempo advance moved a summon one step; a walk banked attacks | "attacks every 5 tempo": same uncapped banking while walking (main.gd:~15118) → back-to-back swings on arrival. |
