# Bugs found while building the simulation harness

Actual bugs (not balance), each with a repro. Fixed ones say so.

## Fixed with the designer's sign-off

- **Defensive Sacrifice never offered under headless boots.** `enemy.gd`
  reached `Main` through `get_tree().current_scene`, which is null when the
  scene is instantiated under a `--script` test (every test and the sim), so
  the Abjurers Cane reaction was silently skipped there while every other
  enemy → main lookup uses `get_parent()`. Changed to `get_parent()` (M1).
## Fixed to match the documented rule (no rule change; for review)

- **Point cards landed on the caster.** A point card's click passes the
  player as its target (`play_selected_card(player)`), and five cards'
  effects read `target.position if target else <the clicked tile>`, so they
  always resolved at the player: Fireball, Peshtigo's Kiss and Sprinkle
  Bomb centred on the caster, Spirit Arrow and Balistic Arrow fired a
  zero-length line ("pierced 0 enemies"), Roll rolled nowhere. They now aim
  at an enemy target when there is one, else at the clicked tile
  (`main._point_aim`); the tester's run showed Balistic Arrow piercing again.
- **Shield Overdraw riders never fired.** Castle Wall's "Overdraw: heal 5
  and loose Rain of Arrows", Delfin's, Treebeard's and the Sleeve's
  Cinquedea hang on `overdraw_processed`, emitted only inside
  `process_overflow`; a full-hand draw with no overflow mode active (the
  normal case) returned before it. The card still stays on the draw pile;
  the riders now fire. `test_overdraw_riders` (fails on the old code).
- **The mana cost of a play is one function** (`DeckManager.compute_play_cost`).
  `play_card` computed it inline with its logging; the tester needs the
  same number without playing, so the block moved, unchanged, into a
  function `play_card` calls with `commit = true` (same logs, same
  percent-mana record). No behaviour change.

- **Stephen's free build switch never moved his weapons.** Man of arms
  makes the weapon portion of a build switch free, so a switch where only
  the hands differ costs 0 — and `Inventory.switch_build` treated "costs 0"
  as "nothing to change", returned success, marked the target build active
  and left the old weapons in hand. The next switch then saved those
  weapons into the wrong build. Repro: Stephen with a Short Sword, open
  build II, put a Pick in hand, switch back to build I: still holding the
  Pick (Ryan, same steps, gets the sword back). The early return now also
  requires that no hand changed. `test_weapons_pass` already checked the
  switch's cost but not what was in hand; it now checks both.

- **`test_weapons_pass`'s Maul's Sabre checks were stale.** The test
  slotted Slice and Quick Shot into the Sabre, but since slot labels
  (2026-09-19) an unlabeled card is deck-only and the Sabre, a staff, takes
  Staff-labelled cards. The test now uses Fireball and Spirit Arrow, and its
  "uncolored item" check uses an Axe card that really slots into the Pick
  (it used to pass because Slice silently failed to slot). The Sabre itself
  was fine. All weapon checks pass.

## Not a bug after all

- **Wisdom and the draw timer.** Every stat text says the auto draw is a
  flat 25 tempo and the code agrees; only one sphere-grid tooltip
  (`sphere_grid_ui.gd:1069`, "faster card draw") says otherwise. A WIS
  scaling was added and then reverted at the designer's request: the flat
  25 is the rule, the tooltip is the stale line.

## Harness bugs found by the sweeps (fixed)

- **Refused plays stalled fights.** The lookahead could keep choosing a
  card the game refused (Heavy Swing without an all-offensive hand, Lead
  Arrow without high ground); three refusals forced a wait, and the fight
  idled to a timeout. The state now mirrors Heavy Swing's gate and drops
  any refused play from the legal actions for the rest of the tempo. The
  ranged ambusher's level-18 table was the visible casualty (0.83 → 1.00
  against the Earth Mage, Large Bear and Bugbear after the fix).
- **A picker could be answered twice in one frame.** A pressed picker
  frees itself deferred, so the next pass of the prompt answerer in the
  same frame found and pressed it again. Pickers are renamed once answered.

- **The same seed drifted between processes.** Enemy rolls and chance
  cards use the global RNG, and timer-driven code consumes it a frame at a
  time, so the number of draws before a Treant's slam-or-root roll depended
  on CPU load; 1–4 seeds in 30 differed between two identical runs. The
  runner now re-seeds from (run seed, global tempo, step) before every
  decision and tick; three concurrent processes produce byte-identical
  run files.

- **Eight cards were never played by the policy.** Sky Attack, Mirror
  Mirror, Collect Arrows, Friendship, Release Tension, Crack of Mintaka,
  Life Swap and Communal Donation were held out of the legal actions as
  "needs a pick", so the single-card sweep scored each as a dead card (all
  eight had identical numbers on every build). They are now playable: the
  runner answers their pickers and the lookahead values and picks for Sky
  Attack, Mirror Mirror, Collect Arrows and Release Tension.

- **Overkill was counted as damage dealt.** `Enemy.damaged` reports the
  whole hit after clamping health at 0, and the runner summed it, so a
  killing blow was credited with damage past zero. Burst and area cards
  were inflated most (If Pigs Could Fly read 168 damage per tempo against
  a pack with 116 total health). The killing hit now counts only the
  health it removed; the excess goes to a separate `overkill` column.
  Win rates were never affected; damage-per-tempo figures were re-run.

## Open (not changed)

- **Feral Evocation's blue slot cannot be filled.** The blue (Cold) slot
  takes only a blue card with a Staff label, and the only blue card, Ice
  Grenade, carries no slot label at all. `test_spell_weapons_pass` fails on
  this ("now the blue slot is next, the blue card fits"). Needs a design
  call: label Ice Grenade for Staff, or more Cold cards.
- **Presence of Mind's block rider is lost on Shield Ready and Repelled
  Block.** The rider adds its block to the card's `block`, but those two
  grant their armor through their own "now" effects and never read it
  (Tower Shield, which does, gets +12). Not changed.
- **Three game tests were stale since slot labels** (shields "take any
  card", a bow "accepts standard attacks", Presence of Mind with the
  unlabeled Clang Up). Updated to the label rule; they pass.

- **Mana clipped by a free switch is not refunded.** Taking off a weapon
  that carries INT lowers max mana, and current mana is clipped to the new
  cap; putting the weapon back raises the cap but not the mana. So a
  "free" switch off Stephen's Fallen's Wrath (+5 INT) at full mana costs
  25 mana for good. Consistent with how any INT item behaves; flagged in
  case a man-of-arms switch should be truly free. Not changed.

- **`tests/_build_sims.gd` spelled Ryan's passive `lets_dance`; the game's
  id is `let's_dance`** (the tree lowercases "Let's Dance" and keeps the
  apostrophe). Fixed in the scratch simulator at the designer's request. (`Enemy.damaged` reporting overkill is handled in the harness; see the
  fixed list above.)

- **Shadow Cowl's on-self bonus can never fire.** The cowl's "+2 damage
  and 2 free tiles for offensive cards" is an `on_self_*` bonus, and
  `Card.get_on_self_bonus()` (card.gd:728) only ever reads the item the
  card is *engraved in*. A chest piece takes Bulwark cards, and none of the
  ten Bulwark-slot cards (approach, armor_patch, best_offense, harden,
  hold_the_line, hunker_down, roar, shield_of_growth, smith_thy_soul,
  turtle_up) is offensive, so no card can collect it. Found by the compare
  tool: raising the bonus from 2 to 6 changed 0 of 90 shadow-blade runs.
  The same applies to every chest piece with an offensive on-self line:
  Elvish Cloak (+2 ranged), Chewbacca's Bandolier (+5 ranged, −1 ranged
  tempo) and Tigers Sunday Red (heal on offensive cards) all read through
  the same path and hold only Bulwark cards. Either these want a
  stat-style bonus (every offensive card you play) or a Bulwark card that
  counts as offensive. Not changed.

- **Shop flags on item-granted and conjured cards.** The sim's card pool
  follows the game's own flags (`requires_engraving`, `shop_excluded`),
  per the rule that cards are universal unless a passive names them. Two
  kinds of card are not flagged and so count as dealer-buyable: cards an
  item grants (Wrath of the Sea from Poseidon's Trident, Hemotoxins from
  the Alchemist Belt, Resourceful Replenish from Hannibal's Mask) and
  conjured tokens (Energy Ball from Absorb Essence). If any of these are
  meant to come only with their item or spell, they want `shop_excluded`
  — the sweeps will otherwise swap them into decks as ordinary cards.

- **Five tree passives never write to the battle log**: Brad's Directed
  Strength and Life Steal, Jeremy's Harnessed Power and Blood Libation,
  Cory's Wither. They work, but neither the player's log nor the sim's
  trigger count can see them fire; their `passive_triggers` entry reads
  `-` (not observable) instead of 0. A one-line `add_battle_log` in each
  would make them countable. Way of the Plate logs as "Way of the Plate"
  under the id `the_way_of_the_plate`; the sim maps the name. Not changed.

## 2026-10-17 — the designer's play report (all fixed in this pass)

- **Player debuff badges had no hover window.** `StatBarsContainer` (the
  HP/mana/carry/XP column) is laid out 50px taller than its bars and is
  added to the UI after the status rows, so its empty bottom covered the
  debuff row (and the top half of the buff row): a `MOUSE_FILTER_PASS`
  container still swallows hover for everything beneath it. The container
  now ignores the mouse (its bars keep their own input); the on-screen
  minimap beside it is gone, so the column sits at the left edge.
  `tests/test_ui_fixes.gd` pushes a mouse-motion at each badge and checks
  the hover window opens.

- **A town portal opened inside a cave led back to the overworld.** The
  portal anchor carried only world level and position; town sent the player
  to World N at the cave's tile. The anchor now carries `interior_id` and
  `parent_interior_id`, and town applies all three (`Town.apply_portal_return`).

- **Fog of war reset on every scene change** (town and back, a cave and
  back, a portal). `DungeonManager._revealed` lived and died with the scene.
  Explored tiles now travel in the progression bundle (`explored`, one byte
  per tile per place, `w2` / `w2/cave_1`), through ProgressionIO to disk, and
  are restored right after the layout is built. Layouts are seeded per world
  and interior, so the bytes map back exactly.

- **Olorin's Bladed Doughnut lesson could not be closed at 16:9.** The speech
  panel had no height limit; six long paragraphs pushed Continue below the
  bottom edge. The paragraphs now sit in a scrolling body sized to the
  screen (`_fit_body`), with the buttons always in view.

- **Cryonics did not make the iced character untargetable in solo play.**
  `EnemySpawner._target_for` skipped iced players — then fell back to the
  player when nobody was left. Enemies now have no target while their only
  possible target is iced (they wait, as with an invisible player), and
  `Enemy._deal_damage_to_player` refuses a blow at an untargetable unit, so
  area attacks and death bursts miss it too.

- **Tick speed reset to 1.5s on every scene change.** Each scene builds a
  new TempoManager at the default; the arrow tiers' choice was lost. The
  choice is now a static on TempoManager and saved in `user://settings.cfg`;
  `initialize()` reads it.

- **No floating number for damage the armor took.** `_spawn_damage_number`
  returned on `amount <= 0` after armor had eaten the hit. Armor-only hits
  now float a grey number; a split hit floats "armor/health" (grey / red) a
  little smaller, side by side (`WorldText.float_number_pair`).

- **Iron Will (and every constellation passive) could be lost on a scene
  change.** `_apply_all_constellation_bonuses` ran at scene set-up and then
  `_restore_player_progression` overwrote `stats.sphere_grid_passives` with
  the carried list. A constellation accepted on the town's grid panel (no
  listener there) or rebuilt from a disk load therefore never had its
  passive in the list, scene after scene — Iron Will never fired on a kill.
  `ProgressionTriggers.ensure_constellation_passives()` now runs after the
  restore and re-registers passives only (stat sides skipped), and
  `PlayerStats.add_sphere_grid_passive` drops a duplicate constellation
  passive. `tests/test_iron_will.gd` covers the kill and the re-register.

## 2026-10-17 — third play report (all fixed in this pass)

- **The figure stayed translucent after Invisible ended** (and after
  death). The restore check read the hidden prototype capsule's material
  (`player.mesh`), which never reads as faded, so `_set_player_invisible(false)`
  never ran once the buff was gone. Main now tracks the fade itself and
  restores the figure on every buff change, every tempo and on death.
- **The damage preview hid damage the armor would take.** The hover preview
  returned health damage only, so an armored enemy showed nothing. The
  preview now shows the armor share in grey and a split as "armor/health",
  the same reading as the floating numbers after the hit
  (`calculate_damage_preview_split`).
- **Timed buffs showed no countdown.** Badges showed xN only for charges,
  stacks, Thorns and Regen; Understanding's wait, Invisible's tempo and the
  rest were in the hover window only. Timed buffs now show their remaining
  tempo on the badge and tick in place (`BuffManager.buffs_ticked`).
- **"Too heavy" for a mythic below level 15.** Every equip refusal printed
  its reason to the log and the panel said "too heavy". `Inventory.last_refusal`
  now carries the real reason (mythic level, duplicate cap, a busy hand, a
  taken slot, carry) and the panel shows it.
- **The War Rack's rule was not enforced.** The free exchange auto-two-handed
  the incoming weapon, but the grip could be released and the plain exchange
  brought it down one-handed. A weapon in the rack's slot (on the rack, or in
  hand straight from it) is now held two-handed on either exchange and
  refuses to be held one-handed until it leaves the slot. The character card
  and the panel's tooltip spell the rule out.
- **Character cards stated the old slot counts** (Ryan 3 belts, Jeremy 4
  rings; the inventories give 2 and 3). Fixed in CharacterData and the quiz.
- **The town portal stood on its rim**, so the plan-view camera saw its edge.
  It lies on its back now.

## 2026-10-18 — found by 3a on Ryan's designed builds (not changed; design calls)

- **Cerberus's Venom Tail is a permanent stun-lock.** It applies Stun for
  15 tempo on an Async clock of 15 tempo, so the stun expires on the tempo
  the next tail lands: from the first tail the player never acts again.
  The apothecary, spellslinger and card shark spend 77–91 % of their
  decisions waiting against Cerberus (`ryan_planner_activity.csv`), and
  every bot's win rate there is the share of seeds that kill it before the
  first tail. Either the stun wants to be shorter than the clock or the
  clock longer than the stun.

- **Deathyard Dog ramps without bound against a build that heals.** Every
  heal in Cerberus's reach gives it +15 Strengthen, permanent, and
  Strengthen is added to every Bite (`attack_damage + strengthen_stacks`),
  tripled under a third of its health. The apothecary heals every cycle
  from its gear, so the Bite climbs 27 → 42 → 57 → … → 324 within 14 bites,
  past any health pool at level 18, and only Marvolo Gaunt's lethal save
  keeps the run alive to the 40-bar timeout. A self-healing build cannot
  fight Cerberus at all; if that is the intent, the sheet should say it.

- **Tool: `total_damage_taken` is the raw incoming amount.** The runner
  counts `PlayerStats.damage_taken`, which emits the hit before armor and
  before Marvolo's invulnerability, so a fight under heavy mitigation reads
  as thousands of damage taken while health never moved (apothecary vs
  Cerberus: 15,000). `planner_gap.py` reports health and armor actually
  lost from the row readings instead; the summary wants the same two
  columns (`health_lost`, `armor_lost`) — queued for after this sweep so
  its stamps stay valid.
