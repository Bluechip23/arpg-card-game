# Code Audit — dead code, unwired content, description mismatches

Full-codebase sweep (2026-07-23): cards, passives, keywords/status effects, stat
wiring, and dead code. Every finding below carries a file:line reference; the
highest-severity items were independently re-verified. Fix checkboxes are left
unticked so this doc can double as a worklist.

Verified clean (no action needed):
- **Cards**: every card in the factory is obtainable (drops, starting decks,
  items, skill trees, or bespoke sources), and every card id referenced anywhere
  (decks, trees, item grants, questionnaire, sandbox) resolves to a real factory.
  No dangling ids, no unreachable cards.
- **Character identity passives**: all five (Ryan belt −1 mana, Jeremy 3rd-cycle
  ring double, Stephen off-hand ±10%, Cory gauntlet mana, Brad chest −20%)
  implemented and matching their text.
- **Item passives**: `stalwart` is the only passive id, defined and handled both
  ways.
- **Skill tree**: all 60 grantable passives have live handlers.
- **Core stat pipeline (P1)**: STR damage/carry/capacity-speed, DEX threshold +
  proc, INT spell/heal/regen, WIS hand/draw, AGI flash points, DET bands,
  level-up +2 HP / +3 points, crit, thorns, regen, heal/damage bonuses — all
  wired end to end.

---

## A. Gameplay bugs — code does the wrong thing

- [ ] **Empower nerfs defense cards.** Text (README.md:146, card.gd:497) says
  defense cards get "−3 mana"; code subtracts 3 from the armor granted instead:
  `armor_amount = max(1, armor_amount - player_stats.empower_block_reduction)`
  (card.gd:1133). Empower currently makes block cards worse.
- [ ] **Shocked never deals its ally damage.** `process_turn_start()` sums it
  into a return dict (debuff_manager.gd:160) but the only caller discards the
  return (main.gd:4851). Shocked just ticks down harmlessly.
- [ ] **Iron Bastion constellation does the wrong effect.** Description: "When
  hit: 15% chance to reduce damage by 50%" (sphere_grid.gd:608). Handler grants
  +5 flat armor and ignores the stored 50 (progression_triggers.gd:1810-1813).
- [ ] **Cover doesn't reduce damage.** Text: "reduce it by the number of cards
  in your hand" within 2 spaces (card.gd:3610). Code heals the ally after the
  hit and never checks the 2-space range (card.gd:3624-3632).

## B. Purchasable no-ops — player can buy these; they do nothing

Sphere grid combat bonuses that are stored (and shown in the character panel!)
but never read by combat:
- [ ] **"Resist +X%" nodes** — `sphere_bonus_resistance` never read in
  `take_damage` (player_stats.gd; only UI read at character_panel.gd:710).
- [ ] **"Life Steal +X%" nodes** — `sphere_bonus_life_steal` write-only
  (player_stats.gd:1168).
- [ ] **"Arm/Cyc +1" nodes** — `sphere_bonus_armor_per_cycle` never applied;
  the per-cycle handler only does regen (main.gd:4839).
- [ ] **"Range +1" nodes** — `sphere_bonus_range` write-only
  (player_stats.gd:1172).

Sphere passive parser failures (progression_triggers.gd:150-230):
- [ ] **"On crit: deal 50% bonus" (node 37 + upgrades)** — the chance regex
  consumes "50%" as a proc chance, leaving effect text "bonus", which no branch
  handles → unhandled no-op.
- [ ] **"On heal: overheal becomes armor" (node 83 + upgrades)** — the generic
  `"heal" in effect_part` branch shadows the later `"overheal"` branch →
  parsed as a value-0 heal → no-op (upgraded "200%" variant is also a no-op:
  the chance regex strips "200%", leaving a value-0 armor gain).
- [ ] **Node 62 transmute "5% freeze enemy"** — parses to `freeze_enemy` but
  the dispatch match has no such case (progression_triggers.gd:1677-1839).

Inert status effects (defined, described, applied — no effect):
- [ ] **Magnetized** — `magnetize_pull` emitted (debuff_manager.gd:195) but
  never connected; handler `_apply_magnetize_pull` (main.gd:5277) never called.
- [ ] **Linked** — `calculate_linked_damage` (debuff_manager.gd:269) has zero
  call sites; `linked_ally` var never used.

## C. Co-op parity — P2 silently misses tempo-driven systems

P2 has its own PlayerStats and deck manager, so damage/heal/hand-size stats work;
these three main-node systems are P1-only:
- [ ] **DEX proc**: only P1's `dexterity_proc` is connected (main.gd:2844). P2's
  counter counts down and the proc fires into the void — no half-tempo/−2 mana.
- [ ] **Flash points**: the single TempoManager holds P1's stats; refresh and
  movement spends always hit P1's pool (tempo_manager.gd:236, :272). P2's pool
  never refreshes and can't be spent by P2's movement.
- [ ] **WIS draw timer**: the single TurnManager is initialized with P1's stats
  and deck (main.gd:2833) — P2 gets no tempo-driven draws at all.

## D. Description mismatches — text wrong, mechanic exists

- [ ] **Brad's character-select ability texts are stale** (tree/CSV/code agree
  with each other; character_data.gd disagrees): Enraged Will triggers at 25%
  HP not 10% (character_data.gd:282 vs progression_triggers.gd:794); The Way of
  the Plate discounts every 2nd defense card not every 3rd (:288 vs :858); 
  Ancestral Aid is a hand-composition effect, not "3 HP regen per 5 tempo"
  (:293 vs :912); Redemption is a guaranteed crit buff on any heal, not "10%
  crit on ally heals" (:298 vs :891); Pristine Armor applies to defense cards
  only (:289 vs :868).
- [ ] **Haste** — "+X movement per tempo spent" (keyword_legend.gd:67,
  README.md:169); actually a flat `spaces += haste_bonus` on one move command
  (player.gd:309). `get_extra_movement_per_tempo()` is dead.
- [ ] **Slowed** — "Lose X movement per cycle" (keyword_legend.gd:41,
  README.md:207); actually `spaces = max(1, spaces - reduction)` per move
  command (player.gd:304) — and a no-op on 1-tile moves, the common case.
- [ ] **Quick Shot** — literal "Deal X damage" placeholder never substituted
  (card.gd:2763; real damage 6).
- [ ] **Push** — literal "X squares" placeholder (card.gd:3008; real push 1).
- [ ] **Enchanted Quiver** — "free 0-cost Quick Arrow" (card.gd:2791); the
  arrow is 0 mana but 2 tempo (card.gd:2933).
- [ ] **Heroic Leap (skill-tree text only)** — "Deal 12 damage" 
  (skill_tree_data.gd:359); real damage = 3 × leap distance, and the card's
  `damage = 12` field is unused (card.gd:1565-1568).
- [ ] **Savage Strike copy** — copy's text claims it adds another copy; it is
  executed with `add_copy=false` (card.gd:967). Possibly intentional disguise —
  decide and either fix text or mark intended.
- [ ] **Walkthrough: Enhance** — says the enhanced card "remains at the top of
  the deck" (gameplay_walkthrough.gd:156); it is discarded
  (overflow_manager.gd:216). Legend/README are correct.
- [ ] **Bottomless Quiver overflow mode** missing from all three player-facing
  overflow lists (keyword_legend.gd:79-85, README.md:120-127,
  gameplay_walkthrough.gd:143-147) despite being fully implemented.
- [ ] **Sphere constellation blurbs** still say "+1 movement per cycle"
  (sphere_grid.gd:548, :555) — retired semantics; movement is Flash-based now.
- [ ] Minor phrasing: Exposed is "armor 30% less effective" not "removes 30%
  more armor"; Jailed legend "3 turns" = 15 tempo (3 cycles), and the `3` in
  `create_jailed(3)` is card count, not sentence length.

## E. Orphaned implementations — handlers nothing can grant

- [ ] `sword_specialist` (player_stats.gd:972, progression_triggers.gd:484) —
  no tree grants it.
- [ ] `phalanx` (progression_triggers.gd:1102) — no tree grants it.
- [ ] `disarm_mastery` (progression_triggers.gd:1139, main.gd:3819) — Stephen's
  tier grants Laced Arrow instead.
- [ ] `corrupted_strength` handlers (progression_triggers.gd:941, :972) — the
  tree grants `solemn_independence`, which has its own duplicate handlers; the
  corrupted_strength path is dead (state vars player_stats.gd:166-167).
- [ ] `on_dodge` trigger mapping (progression_triggers.gd:133) and the
  `return_to_hand` parse case — nothing produces them.

## F. Dead code

Subsystems:
- [ ] **`scripts/city/` module is fully orphaned** (expedition_system.gd,
  raid_system.gd, city_state.gd) — nothing instantiates any of it;
  `save_data.gd:46` `city` dict written/read nowhere.
- [ ] **Legacy deck-level overflow mode** — `set_overflow_mode`
  (deck_manager.gd:182) never called → `current_overflow_mode` always NONE →
  match block deck_manager.gd:190-208 unreachable and the PEAK check at
  main.gd:5413 can never be true. Superseded by OverflowManager.
- [ ] **Burden mechanic** — `get_burden_mana_cost` / `get_burden_tempo_cost` /
  `apply_burden` / `jail_burden` (card.gd:1208-1223) never invoked, though the
  keyword still appears in card text (card.gd:506, :625).
- [ ] **`get_effective_ranged_damage` never called** (player_stats.gd) — ranged
  attacks route through `get_effective_physical_damage` plus scattered
  `ranged_damage_bonus` adds (main.gd:5513, card.gd:697). Consolidate or delete.
- [ ] **`add_damage_resistance` has no callers** → `damage_resistances` is
  always empty (acknowledged TODO in code).
- [ ] **Origami swan crafting half-built** — `get_origami_swan_count` /
  `destroy_cards_for_swans` (inventory.gd:1438, :1469) dead while paper-feather
  use is live.
- [ ] **`delete_save` unwired** (save_manager.gd:50) — no way to delete saves.

Never-connected signals worth deciding on (drive-nothing broadcasts):
`magnetize_pull`, `chest_interacted`, `player_entered_zone` (dungeon_manager),
`turn_started`/`player_turn_started` (turn_manager), `character_selected`
(character_select.gd:6), test_ui `apply_debuff_requested` (debug button inert),
and the buff/debuff/overflow manager notification cluster (`buff_ticked`,
`buff_applied/removed`, `debuff_ticked/removed`, `cleanse_triggered`,
`thorns_triggered`, `overflow_effect_added/removed`, `peak_triggered`).

Notable uncalled functions (≈108 total; full sweep details in the audit run):
buff_manager query API (`get_thorns_damage`, `get_bolster_bonus`,
`get_extra_movement_per_tempo`, `get_extra_draws`, `get_brace_reduction`,
`consume_resilient`, `should_skip_tempo`, `clear_all_buffs`), debuff_manager
(`can_act` — stun gating never consulted, `get_tether_origin`,
`clear_all_debuffs`), overflow_manager zone helpers, deck_manager
(`_create_card_from_data`, `remove_card_from_all_piles`), enemy.gd
(`attack_player`, `set_target`, `_on_enemy_animation_finished` — never connected
to any animation), card.gd (`_execute_hold_the_line` / `_execute_try_this`
orphaned by `pass` dispatch arms, `get_rng_outcome`, `get_total_damage`),
player.gd (`stop_moving`, `spawn_armor_number`), tempo_manager
(`get_total_pending_ticks`, `get_tempo_percent`), plus assorted single dead
helpers in dungeon_manager, sphere_grid, sphere_inventory, skill_tree_data,
item_data, quest_manager, enemy_spawner, grid_manager, roguelike_run,
character_animator, questionnaire_data, item_tooltip, and settings_tab.
