# Wiring audit — cards, slice E (Sky Attack … Wrath of the Sea)

Phase 2 of `audit/full-pass-1`. Every card was played through the real play
path in a booted `main.tscn` (the dojo): `DeckManager.play_card` charges the
mana, `TempoManager` ticks the tempo, `_resolve_queued_card` runs the executor
and `main._apply_card_world_effects`. Timers are read the moment the card
resolves (before that tick's tempo reaches them).

Test file: `tests/test_wiring_cards_e.gd` (shortened to `wce` below). Every
non-instant card in the slice also passes the price check
`wce::<id> charges <N> mana` / `wce::<id> costs <N> tempo` — the play path
charges exactly the card's `mana_cost` and `tempo_cost` (Specific Strike's
hand surcharge, Summon Skeleton's 45 − INT, Wrath of the Sea's half of current
mana and Territorial Mark's 35 health included).

Delays follow the engine's one convention for "in N tempo": the tick a card
resolves on counts as the first of the N (Spark, Succumb, Vines, Terrain
formation, Understanding, Sky Fall).

| name | type | status | what was wrong | what changed | test name |
|---|---|---|---|---|---|
| sky_attack | card | CORRECT | | | wce::…and shoots for its damage plus High Ground's +4 |
| sky_fall | card | FIXED | "In 10 tempo, it lands": the arrow counted down 5 per tempo cycle, so it landed 5–10 tempo after the shot depending on where in the cycle it was loosed (1 tempo later when shot just before a cycle boundary). | `main._process_pending_sky_falls(amount)` now ticks on raw tempo from the tempo dispatcher, not on the cycle. | wce::phase 0: it lands on the 10th tempo counting the shot's own; wce::phase 3: … |
| slash | card | CORRECT | | | wce::Slash deals 10; Conditional: tests/test_conditional_range.gd |
| slice | card | CORRECT | | | wce::Slice deals 15 |
| smith_thy_soul | card | FLAGGED | Formula reads the raw mana pool (x10 code units); see Flagged. | | wce::armor = ((health + mana) / 2) / 10 (raw pools) |
| smoke_bomb | card | CORRECT | | | wce::standing in the smoke: invisible; wce::…and +10% crit; wce::the cloud is gone after 8 tempo; wce::jailed for 20 tempo after play |
| snowballs_chance | card | CORRECT | | | wce::fire 3 spaces forward deals 10, no snowballs on a miss; wce::on the 50%, snowballs (4 each) also strike |
| song_of_a_swords_sing | card | FLAGGED | Kinds are counted before its own Disarm lands; see Flagged. | | wce::disarms for 5 tempo; wce::3 Burn + 1 Weaken = 2 kinds = 4 armor |
| spark | card | CORRECT | | | wce::Spark deals 3; wce::-2 tempo on two cards in hand; wce::15 tempo later, +2 tempo back on two cards |
| specific_strike | card | CORRECT | | | wce::+1m (10) per other card in hand; wce::+1 tempo per other card in hand |
| spider_senses | card | CORRECT | | | wce::taking damage fires it: +5 armor |
| spirit_arrow | card | CORRECT | | | wce::pierces every enemy on the line for 8 |
| spirit_bow | card | CORRECT | | | wce::a 10-damage shot on the 4th tempo; wce::it dissolves once the mana is no longer reserved |
| splinter | card | CORRECT | | | wce::applies 1 Bleed, no damage; wce::range 3 |
| sprinkle | card | CORRECT | | | wce::Sprinkle deals 25; wce::Sprinkle is erased after play |
| sprinkle_bomb | card | CORRECT | | | wce::Sprinkle Bomb hits every enemy within 2 tiles for 25; wce::Sprinkle Bomb is erased after play |
| stance_switch | card | CORRECT | | | wce::removes 10 armor and applies 2 Vulnerable; wce::no armor: just 2 Vulnerable |
| stone_encase | card | CORRECT | | | wce::+50 armor; wce::stunned for 5 tempo |
| succumb | card | CORRECT | | | wce::Blessed 2 for 20 tempo (4 cycles); wce::after 10 tempo: takes the 10 damage; wce::…and CUFFED for 10 tempo |
| summon_battle_turtle | card | CORRECT | | | wce::summon_battle_turtle raises 1 battle_turtle; stat block: tests/test_summon_cards.gd |
| summon_shadow_hound | card | CORRECT | | | wce::summon_shadow_hound raises 1 shadow_hound; tests/test_summon_cards.gd::bites every 8 - INT/10 tempo |
| summon_skeleton | card | CORRECT | | | wce::summon_skeleton charges 42 mana (45 − INT 3); tests/test_summon_cards.gd::...and refunds INT - 45 |
| surrounding_ice | card | CORRECT | | | wce::hits within two squares for its damage; wce::a missed roll spares that enemy |
| swap | card | CORRECT | | | wce::switches positions with the enemy |
| sweeping_disarm | card | CORRECT | | | wce::surrounding enemies (diagonal too) disarmed for 5 tempo; wce::…and take 3 |
| switch_kick | card | CORRECT | | | wce::2 damage and Disarm for 5 tempo |
| taunt | card | CORRECT | | | wce::an enemy 3 squares away is taunted for 10 tempo; wce::one 4 squares away … is not |
| terrain_formation | card | CORRECT | | | wce::a hill rises where aimed; wce::gone after 5 tempo |
| territorial_mark | card | CORRECT | | | wce::deals 15; wce::an enemy 2 squares beside the arrow's path is Weakened; wce::the smoke lasts 25 tempo; wce::territorial_mark costs 35 health |
| the_lights_favor | card | CORRECT | | | wce::heals 5 (… after healing bonuses) and draws a card |
| the_nibelung_curse | card | CORRECT | | | wce::aimed at an enemy: deals the stored healing as damage; wce::aimed at yourself: takes the stored healing |
| thrown_stone | card | CORRECT | | | wce::On Draw: 4 damage to a random enemy; wce::played: 4 damage to an enemy |
| tight_rope | card | CORRECT | | | wce::a hit that puts you below 20% fires it; wce::+20 temp health for 5 tempo; wce::+15 damage on the next attack |
| tighten_string | card | FIXED | "Next 3 ranged attacks played": the charge was spent when the attack RESOLVED, so attacks queued before the first resolved were all strung (4 shots off 3 charges; the count went to -1). | The charge is spent in `main.play_selected_card` when the strung attack is played; `_undo_card_temp_mods` no longer spends it (a cancelled shot still keeps its charge spent, as before). | wce::queued before any resolves, only 3 of 4 ranged attacks are strung; wce::ranged attack 1: +3 tempo, +6 damage; wce::+6 range on the charged shot; wce::+20% crit on the charged shot |
| tower_shield | card | CORRECT | | | wce::+40 armor; wce::staggered for 40 tempo |
| trick_shot | card | CORRECT | | | wce::the 80% bounce repeats the hit on the next enemy; wce::never more than 4 bounces (80/60/40/20%) |
| tricks_of_alberich | card | CORRECT | | | wce::taunts enemies in a 4-square radius for 5 tempo; wce::+10 STR for the taunt's 5 tempo; wce::+4 armor per enemy taunted; wce::+2 Regen per enemy taunted |
| trip | card | CORRECT | | | wce::5 damage; wce::movement -4 for 10 tempo |
| try_this | card | CORRECT | | | wce::+3 mana pool, +2 hand size; wce::for 10 tempo; wce::the 10% reverse: -3 mana pool, -2 hand size |
| turtle_power | card | CORRECT | | | wce::turtle_power raises 3 battle_turtle; tests/test_summon_cards.gd::after 5 tempo it regains a fifth of the cap |
| turtle_up | card | CORRECT | | | wce::Fortify for 20 tempo |
| twenty_twenty | card | CORRECT | | | wce::+3 range on ranged offensive cards; wce::not on melee cards |
| understanding | card | CORRECT | | | wce::armed after 10 tempo; wce::the next damaging card auto-crits |
| vengeful_shield | card | CORRECT | | | wce::exposed: it fires for 5 armor; wce::…and stuns the enemy in melee range for 5 tempo |
| vined_encasing | card | FIXED | *(Phase 6 re-check)* Meeting thorns already up (Spiked Mitts, Spiked Shield…), the Vined thorns merged into them and lost their rule — the lot then fell 1 per hit; ordinary thorns gained later started shedding by damage. | `Buff.vined_value` keeps the Vined share inside the one Thorns buff: hits wear only the plain share, damage taken sheds only the Vined share. | test_recheck_fixes.gd::Vined Encasing; wce::1 thorn per armor (12) for 20 tempo, shed X per X damage |
| vines | card | CORRECT | | | wce::held in place for 15 tempo; wce::4 damage every 5 tempo, three times |
| volatile_mixture | card | CORRECT | | | wce::On Discard: 8 to the nearest enemy; wce::5 tempo in hand: discarded; wce::…after 8 self-damage |
| wear_down | card | FLAGGED | Card text omits the enemy-side limit (the reduction clears after the enemy's next 2 attacks); see Flagged. | | wce::lasts 15 tempo; wce::a hit: enemy attack -1; wce::a consecutive hit: -2 |
| worms_armageddon | card | CORRECT | | | wce::23 damage to a single target; wce::the 10%: two Alaskan Bull Worms; wce::each 12 HP, 6 damage, burrowed |
| worst_that_could_happen | card | CORRECT | | | wce::heads: 5 damage +15; wce::tails: 5 damage, stunned 5 tempo |
| wrath_of_the_sea | card | CORRECT | | | wce::spends HALF your current mana; wce::the mana spent (plus STR) to every enemy in the 4x4; wce::shoved to the burst's edge; wce::+15 mana per enemy hit |

## Flagged

- **smith_thy_soul** — "Gain armor equal to ((Health + mana) / 2) / 10." The code adds the raw mana pool, which runs on the x10 economy (`passive_scaling.gd`: design "1 mana" = 10 in code; Try This's "+3 mana pool" is +30 and Specific Strike's "+1m" is +10 in code). At 100 HP / 100 code-mana the card gives 10 armor; read in design units (100 + 10) it gives 5. `tests/test_card_sheet_pass.gd` pins the raw reading. **Question: is "mana" in the formula the raw pool (as now) or design mana (pool / 10)?**
- **song_of_a_swords_sing** — "Disarm the enemy for 5 tempo and gain 2 armor for every KIND of debuff on it". The code counts kinds *before* its own Disarm lands, so on a clean enemy it gives 0 armor; the card's example ("burn + frost + disarm is three") counts a Disarm already there. **Question: does the Song's own Disarm count as a kind (always at least +2 armor), or only debuffs already on the enemy (as now)?**
- **wear_down** — "Decrease enemy attack by 1 per consecutive hit. Lasts 15 tempo." The 15 tempo is the window in which your attacks stack the reduction (as written). The reduction itself, though, clears after the enemy's next 2 attacks (`Enemy.WEAR_DOWN_ATTACKS`, from the sheet), which the card text does not say, and "consecutive" is not enforced (a miss or a non-attack does not reset the count). **Question: should the card text mention the 2-attack limit, and should a break in the hits reset the stack?**

## Notes for other slices

- `DeckManager.trigger_reactions` (shared) fires an instant from the hand without checking `requires_engraving`, so an un-engraved Vengeful Shield or other engrave-only instant in the hand would still fire. Only the hand-play path (`play_card`) enforces the engrave gate. Not changed here: the card texts in this slice don't speak to it.
- The Sky Fall and Tighten String fixes are in shared `main.gd` code (`_on_tempo_advanced`, the cycle dispatcher, `play_selected_card`, `_undo_card_temp_mods`).
