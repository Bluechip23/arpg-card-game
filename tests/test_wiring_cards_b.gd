extends SceneTree

## Phase 2 wiring audit, card slice B (docs/audit/wiring/cards_b.md):
## Detonova … Heavy Greedy Cheese. Each card is played through the real
## play path of a booted main.tscn (the dojo) — Main.play_selected_card,
## DeckManager.play_card's costs, the tempo ticker and the resolve queue —
## and the check asserts what the card's description says. "costs X / Y"
## checks read the mana the play spent and the ticks it put on the clock.
## Run: godot --headless --path . --script tests/test_wiring_cards_b.gd

var failures: int = 0
var main = null
var stats = null
var dm = null
var bm = null
var pdm = null
var tm = null
var _spawned: Array = []
var _gains: Array = []  # non-regen mana gains (mana_gained)

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	TempoManager.preferred_swing_hold = 0  # resolve on the tick, no animation wait
	await _boot()
	if main == null:
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	_t_detonova()
	_t_discard_and_exacerbate()
	_t_djinn_wish()
	_t_donate_cleats()
	_t_down_but_not_out()
	_t_down_town()
	_t_draw()
	_t_earth_rattle()
	_t_element_pollination()
	_t_elixir()
	_t_empower()
	_t_enchanted_quiver()
	_t_enchantments()
	_t_endured_tolerance()
	_t_energy_ball()
	_t_energy_barrier()
	_t_escape_and_bewilder()
	_t_exhausted_assault()
	_t_exposed_artery()
	_t_exposing_strike()
	_t_feed_into_the_pain()
	_t_fire_punch()
	_t_fireball()
	_t_fleet_etching()
	_t_forever_armor()
	_t_fortify_alliance()
	_t_fountain_of_life()
	_t_friendship()
	_t_from_the_ashes()
	_t_gain_mana()
	_t_gargle_and_spit()
	_t_gift_from_the_gods()
	_t_gift_from_the_phoenix()
	_t_give_in()
	_t_god_of_thunder()
	_t_grounding()
	_t_gulped_potion()
	_t_halo()
	_t_hard_helmet()
	_t_harden()
	_t_harness_lightning()
	_t_heals()
	_t_healthy_bliss()
	_t_healthy_habit()
	_t_heavy_greedy_cheese()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------ harness

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _boot() -> void:
	print("-- Booting main.tscn as the dojo --")
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle()
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	_check(main.player != null and main.enemy_spawner != null, "the dojo is up")
	if main.player == null:
		main = null
		return
	stats = main.player.get_stats()
	dm = main.deck_manager
	bm = main.player.get_buff_manager()
	pdm = main.player.get_debuff_manager()
	tm = main.tempo_manager
	# The dojo's own dummies would stand in every area test: clear them.
	for e in main.enemy_spawner.get_living_enemies().duplicate():
		main.enemy_spawner.despawn_enemy(e)
	stats.mana_gained.connect(func(amount: int, is_regen: bool) -> void:
		if not is_regen:
			_gains.append(amount))
	_reset()

## A clean slate between cards: full health and mana, no statuses, an empty
## hand, no crits, nothing on the clock, every spawned enemy gone.
func _reset() -> void:
	_drain()
	for e in _spawned:
		if is_instance_valid(e):
			main.enemy_spawner.despawn_enemy(e)
	_spawned.clear()
	stats.max_health = 500
	stats.current_health = 500
	stats.current_armor = 0
	stats.current_temp_health = 0
	stats.equipment_crit_bonus = -5.0  # cancels the innate 5%: no stray crits
	stats.healing_bonus = 0
	stats.max_mana = 2000
	stats.current_mana = 2000
	pdm.clear_all_debuffs()
	for b in bm.buffs.duplicate():
		bm.remove_buff(b.buff_type)
	bm.enchanted_quiver_charges = 0
	dm.hand.clear()
	dm.maintained_cards.clear()
	stats.maintained_mana = 0
	dm.next_attack_half_tempo = false
	dm.next_attack_mana_discount = 0
	dm.fire_spells_this_turn = 0
	dm.true_discards_this_cycle = 0
	dm.skip_next_tempo_draw = false
	main.glut_tempo_remaining = 0
	main._last_aim_world = null
	main.mouse_override = Vector2(-1, -1)
	tm.current_tempo = 0
	_gains.clear()
	_place_player(_home)

var _home := Vector2i.ZERO  # the player's tile for every card

func _player_cell() -> Vector2i:
	return main.grid_manager.world_to_grid(main.player.position)

func _place_player(cell: Vector2i) -> void:
	main.player.position = main._ground_pos(cell)
	main.player.target_position = main.player.position
	if "is_moving" in main.player:
		main.player.is_moving = false

func _spawn(offset: Vector2i, hp: int = 1000) -> Enemy:
	var e: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.DUMMY, main._ground_pos(_player_cell() + offset))
	e.chosen_action = {}
	e.max_health = hp
	e.current_health = hp
	e.current_armor = 0
	_spawned.append(e)
	return e

func _lost(e: Enemy) -> int:
	return e.max_health - e.current_health

## Run the clock until nothing is queued.
func _drain() -> int:
	var n := 0
	while tm._pending_ticks > 0 and n < 200:
		tm._process_one_tick()
		n += 1
	return n

func _queued(card: Card) -> bool:
	for en in main._pending_resolve_queue:
		if en["card"] == card:
			return true
	return false

## Play `card` from the hand on `target` exactly as a click does, then tick
## the clock until the card has RESOLVED (the rest of its ticks stay pending —
## _drain() or the next _reset() spends them). Returns whether it played, the
## mana the play spent and the tempo it put on the clock.
func _play(card: Card, target, aim_cell = null) -> Dictionary:
	dm.next_attack_half_tempo = false
	dm.next_attack_mana_discount = 0
	if not dm.hand.has(card):
		dm.hand.append(card)
	if aim_cell != null:
		main._last_aim_world = main._ground_pos(aim_cell)
	main.selected_card_index = dm.hand.find(card)
	var m0: float = stats.current_mana
	main.play_selected_card(target)
	var played: bool = main.selected_card_index == -1
	var mana_spent := int(round(m0 - stats.current_mana))
	var tempo := 0
	for entry in tm._active_cards:
		if entry["card"] == card:
			tempo = int(entry["total_ticks"])
	var n := 0
	while _queued(card) and n < 60:
		tm._process_one_tick()
		n += 1
	main._last_aim_world = null
	return {"played": played, "mana": mana_spent, "tempo": tempo}

func _costs(r: Dictionary, mana: int, tempo: int) -> bool:
	return r["played"] and r["mana"] == mana and r["tempo"] == tempo

func _cost_str(r: Dictionary) -> String:
	return "played %s, %d mana / %d tempo" % [str(r["played"]), r["mana"], r["tempo"]]

func _ally():
	return main._dojo_allies[0] if not main._dojo_allies.is_empty() else null

# ------------------------------------------------------------------ cards

func _t_detonova() -> void:
	print("-- Detonova --")
	_reset()
	var cuirass := ItemData.new()
	cuirass.item_name = "Test Cuirass"
	cuirass.banked_damage = 17.0
	cuirass.banked_stacks = 3
	var c := Card.create_by_id("detonova")
	c.granted_by_item = cuirass
	var near := _spawn(Vector2i(2, 0))
	var far := _spawn(Vector2i(0, 3))
	var r := _play(c, main.player)
	_check(_costs(r, 60, 5), "Detonova costs 60 mana / 5 tempo (%s)" % _cost_str(r))
	_check(_lost(near) == 17, "Detonova deals the banked 17 flat (no INT) to an enemy within 2 (%d)" % _lost(near))
	_check(_lost(far) == 0, "Detonova misses an enemy 3 squares away (%d)" % _lost(far))
	_check(cuirass.banked_damage == 0.0 and cuirass.banked_stacks == 0, "Detonova purges the cuirass's stacks")

func _t_discard_and_exacerbate() -> void:
	print("-- Discard / Exacerbate Wounds --")
	_reset()
	var keep_a := Card.create_by_id("block")
	var keep_b := Card.create_by_id("slash")
	var d := Card.create_by_id("discard")
	dm.hand.append_array([keep_a, keep_b])
	var pile0: int = dm.discard_pile.size()
	var r := _play(d, main.player)
	_check(_costs(r, 0, 1), "Discard costs 0 mana / 1 tempo (%s)" % _cost_str(r))
	var gone: int = int(not dm.hand.has(keep_a)) + int(not dm.hand.has(keep_b))
	_check(gone == 1, "Discard discards one random card from the hand (%d gone)" % gone)
	_check(dm.true_discards_this_cycle == 1, "Discard's discard counts as a card discarded this cycle (%d)" % dm.true_discards_this_cycle)
	_check(dm.discard_pile.size() == pile0 + 2, "the discarded card and Discard itself are in the discard pile")
	# Exacerbate Wounds: 3 per card discarded this cycle (2 now).
	dm.hand.append(Card.create_by_id("block"))
	dm.discard_card_from_hand(dm.hand[dm.hand.size() - 1])
	var en := _spawn(Vector2i(1, 0))
	var ew := Card.create_by_id("exacerbate_wounds")
	var want: int = stats.get_effective_physical_damage(6)
	r = _play(ew, en)
	_check(_costs(r, 0, 7), "Exacerbate Wounds costs 0 mana / 7 tempo (%s)" % _cost_str(r))
	_check(_lost(en) == want, "Exacerbate Wounds deals 3 x 2 discards through the STR pipeline (%d, want %d)" % [_lost(en), want])
	_check(not ew.is_ranged, "Exacerbate Wounds is melee without a bow (Conditional)")

func _t_djinn_wish() -> void:
	print("-- Wish (djinn_wish) --")
	_reset()
	var w := Card.create_djinn_wish(3)
	dm.hand.append(w)
	var hp0: int = stats.current_health
	dm.process_turn()
	_check(stats.current_health == hp0 - 3, "a Wish held over a cycle sears its holder for 3 (%d)" % (hp0 - stats.current_health))
	var r := _play(w, main.player)
	_check(_costs(r, 60, 0), "Wish costs 60 mana / 0 tempo to play (%s)" % _cost_str(r))
	_check(not dm.hand.has(w) and not dm.discard_pile.has(w) and not dm.draw_pile.has(w), "playing the Wish is rid of it for good (erased)")

func _t_donate_cleats() -> void:
	print("-- Donate Cleats --")
	_reset()
	var ally = _ally()
	_check(ally != null, "the dojo has an ally dummy")
	if ally == null:
		return
	var ast = ally.get_stats()
	var agi0: int = ast.agility
	var dex0: int = ast.dexterity
	var r := _play(Card.create_by_id("donate_cleats"), ally)
	_check(_costs(r, 35, 0), "Donate Cleats costs 35 mana / 0 tempo (%s)" % _cost_str(r))
	_check(ast.agility == agi0 + 5 and ast.dexterity == dex0 + 4, "Donate Cleats grants the ally +5 AGI and +4 DEX (%d/%d)" % [ast.agility - agi0, ast.dexterity - dex0])
	tm.add_tempo(4)
	_check(ast.agility == agi0 + 5, "still there after 4 tempo")
	tm.add_tempo(1)
	_check(ast.agility == agi0 and ast.dexterity == dex0, "gone after 5 tempo")

func _t_down_but_not_out() -> void:
	print("-- Down but not out --")
	_reset()
	pdm.apply_debuff(Debuff.create_slowed(4))
	pdm.apply_debuff(Debuff.create(Debuff.DebuffType.WEAKENED, 2, 20))
	stats.current_health = 100
	var stacks := 0
	for d in pdm.debuffs:
		stacks += maxi(1, d.value)
	var want: int = stats.get_effective_heal_amount(stacks)
	var r := _play(Card.create_by_id("down_but_not_out"), main.player)
	_check(_costs(r, 50, 2), "Down but not out costs 50 mana / 2 tempo (%s)" % _cost_str(r))
	_check(stacks == 6 and stats.current_health - 100 == want, "Down but not out heals 1 per debuff stack (6 stacks -> +%d, want %d)" % [stats.current_health - 100, want])

func _t_down_town() -> void:
	print("-- Down Town --")
	_reset()
	var c := Card.create_by_id("down_town")
	_check(c.get_effective_range() == 12, "Down Town reaches 5 + 7 = 12 (%d)" % c.get_effective_range())
	var en := _spawn(Vector2i(10, 0))
	var want: int = stats.get_basic_attack_damage()
	var r := _play(c, en)
	_check(_costs(r, 30, 5), "Down Town costs 30 mana / 5 tempo (%s)" % _cost_str(r))
	_check(_lost(en) == want, "Down Town deals the auto attack's damage (%d, want %d)" % [_lost(en), want])

func _t_draw() -> void:
	print("-- Draw --")
	_reset()
	var top := Card.create_by_id("block")
	dm.draw_pile.append(top)
	var r := _play(Card.create_by_id("draw"), main.player)
	_check(_costs(r, 0, 1), "Draw costs 0 mana / 1 tempo (%s)" % _cost_str(r))
	_check(dm.hand.size() == 1, "Draw draws a card (hand %d)" % dm.hand.size())

func _t_earth_rattle() -> void:
	print("-- Earth Rattle --")
	_reset()
	var t := _spawn(Vector2i(1, 0))
	var side := _spawn(Vector2i(1, 3))
	var out := _spawn(Vector2i(5, 0))
	var r := _play(Card.create_by_id("earth_rattle"), t)
	_check(_costs(r, 60, 6), "Earth Rattle costs 60 mana / 6 tempo (%s)" % _cost_str(r))
	_check(_lost(t) == 40 and _lost(side) == 40, "Earth Rattle deals 40 to the impact and 3 squares around it (%d, %d)" % [_lost(t), _lost(side)])
	_check(_lost(out) == 0, "an enemy 4 squares from the impact is untouched")
	_check(t.slow_stacks == 2 and t.weaken_stacks == 2 and side.slow_stacks == 2, "enemies hit are Slowed 2 and Weakened 2 (%d/%d)" % [t.slow_stacks, t.weaken_stacks])

func _t_element_pollination() -> void:
	print("-- Element Pollination --")
	_reset()
	var c := Card.create_by_id("element_pollination")
	var r := _play(c, main.player)
	_check(_costs(r, 60, 3), "Element Pollination costs 60 mana / 3 tempo (%s)" % _cost_str(r))
	_check(dm.maintained_cards.has(c), "Element Pollination is maintained")
	main._update_element_pollination()
	_check(Card.element_pollination_active, "while maintained the pollination is live")
	var a := _spawn(Vector2i(3, 0))
	var b := _spawn(Vector2i(4, 0))
	a.apply_debuff("burn", 1)
	a._tick_status_durations()
	_check(_lost(b) == 1, "Burn splashes its tick onto a nearby enemy (%d)" % _lost(b))
	var hp_b: int = b.current_health
	b.apply_debuff("cold", 2)
	b._tick_status_durations()
	_check(hp_b - b.current_health == 1, "Cold ticks damage like Burn (%d)" % (hp_b - b.current_health))
	a.apply_debuff("shock", 5)
	_check(a.shock_stacks == 0 and a.stun_tempo >= 5, "5 Shock stacks lock the enemy for 5 tempo (stun %d) — see the flag on freeze vs stun" % a.stun_tempo)
	dm.maintained_cards.erase(c)
	main._update_element_pollination()
	_check(not Card.element_pollination_active, "dropping the maintain ends it")

func _t_elixir() -> void:
	print("-- Elixir --")
	_reset()
	var r := _play(Card.create_by_id("elixir"), main.player)
	_check(_costs(r, 10, 2), "Elixir costs 10 mana / 2 tempo (%s)" % _cost_str(r))
	_check(stats.elixir_tempo == 25 - 1, "Elixir opens a 25-tempo window (%d left a tick later)" % stats.elixir_tempo)
	var en := _spawn(Vector2i(1, 0))
	en.current_health = 500
	var hemo := Card.create_by_id("hemotoxins")
	_play(hemo, en)
	_check(en.poison_stacks == 0 and en.current_health > 500, "poison a card applies under Elixir heals its target instead (%d hp, %d poison)" % [en.current_health, en.poison_stacks])
	_drain()
	tm.add_tempo(25)
	_check(stats.elixir_tempo == 0, "the window closes after 25 tempo")

func _t_empower() -> void:
	print("-- Empower --")
	_reset()
	var r := _play(Card.create_by_id("empower"), main.player)
	_check(_costs(r, 10, 2), "Empower costs 10 mana / 2 tempo (%s)" % _cost_str(r))
	_check(stats.empowered_cards_remaining == 2, "Empower readies 2 charges")
	_drain()
	dm.hand.clear()
	var blk := Card.create_by_id("block")
	dm.draw_pile.append(blk)
	dm.draw_card()
	_check(not blk.draw_empowered and stats.empowered_cards_remaining == 2, "a non-attack drawn spends no charge")
	var s1 := Card.create_by_id("slash")
	var s2 := Card.create_by_id("slash")
	var s3 := Card.create_by_id("slash")
	for s in [s1, s2, s3]:
		dm.draw_pile.append(s)
		dm.draw_card()
	_check(s1.draw_empowered and s2.draw_empowered and not s3.draw_empowered, "the next 2 attack cards drawn are empowered, the third is not")
	var e1 := _spawn(Vector2i(1, 0))
	var e2 := _spawn(Vector2i(-1, 0))
	_play(s1, e1)
	_play(s3, e2)
	_check(_lost(e1) - _lost(e2) == 3, "an empowered attack deals +3 damage (%d vs %d)" % [_lost(e1), _lost(e2)])

func _t_enchanted_quiver() -> void:
	print("-- Enchanted Quiver --")
	_reset()
	var r := _play(Card.create_by_id("enchanted_quiver"), main.player)
	_check(_costs(r, 40, 5), "Enchanted Quiver costs 40 mana / 5 tempo (%s)" % _cost_str(r))
	_check(bm.enchanted_quiver_charges == 3, "Enchanted Quiver readies 3 charges")
	_drain()
	var en := _spawn(Vector2i(3, 0))
	# A melee attack spends none.
	var melee_t := _spawn(Vector2i(0, 1))
	_play(Card.create_by_id("slash"), melee_t)
	_check(bm.enchanted_quiver_charges == 3, "a melee attack spends no charge")
	dm.hand.clear()
	var made := 0
	for i in range(4):
		_drain()
		var shot := Card.create_by_id("down_town")
		_play(shot, en)
		var arrows: Array = dm.hand.filter(func(h): return h.card_id == "quick_arrow")
		made = arrows.size()
	_check(made == 3, "the next 3 ranged attacks each put a Quick Arrow in hand, the 4th none (%d)" % made)
	var qa: Card = dm.hand.filter(func(h): return h.card_id == "quick_arrow")[0] if made > 0 else null
	_check(qa != null and qa.mana_cost == 0 and qa.damage == 4 and qa.is_ranged, "a Quick Arrow is a free (0 mana) 4-damage ranged attack")

func _t_enchantments() -> void:
	print("-- Enchantments --")
	_reset()
	var en := _spawn(Vector2i(1, 0))
	var base_dmg: int = stats.get_effective_physical_damage(10)
	var ea := Card.create_by_id("enchantment_attack")
	dm.hand.append(ea)
	main._recalculate_enchantment_bonuses()
	_check(stats.enchantment_damage_bonus == 3, "Enchantment: Attack in hand -> +3 damage")
	var r := _play(Card.create_by_id("slash"), en)
	_check(_lost(en) == base_dmg + 3, "a card deals +3 while it is in hand (%d vs %d)" % [_lost(en), base_dmg])
	var res: Dictionary = dm.play_card(dm.hand.find(ea), null, main.player)
	_check(not res["played"], "an Enchantment cannot be played")
	main._process_enchantment_cycles()
	_check(dm.hand.has(ea), "still in hand after 1 cycle")
	main._process_enchantment_cycles()
	_check(not dm.hand.has(ea) and dm.discard_pile.has(ea), "Enchantment: Attack discards after 2 cycles")
	main._recalculate_enchantment_bonuses()
	_check(stats.enchantment_damage_bonus == 0, "the bonus leaves with it")

	_reset()
	var ed := Card.create_by_id("enchantment_defense")
	dm.hand.append(ed)
	main._recalculate_enchantment_bonuses()
	stats.add_armor(5)
	_check(stats.current_armor == 8, "Enchantment: Defense -> +3 block on an armor gain (%d)" % stats.current_armor)
	main._process_enchantment_cycles()
	main._process_enchantment_cycles()
	_check(dm.discard_pile.has(ed), "Enchantment: Defense discards after 2 cycles")
	main._recalculate_enchantment_bonuses()

	_reset()
	var regen0: float = stats.get_effective_mana_regen()
	var em := Card.create_by_id("enchantment_mana_regen")
	dm.hand.append(em)
	main._recalculate_enchantment_bonuses()
	_check(is_equal_approx(stats.get_effective_mana_regen() - regen0, 10.0), "Enchantment: Mana Regen -> +1 mana regen (x10 scale: %.1f)" % (stats.get_effective_mana_regen() - regen0))
	main._process_enchantment_cycles()
	main._process_enchantment_cycles()
	_check(dm.discard_pile.has(em), "Enchantment: Mana Regen discards after 2 cycles")
	main._recalculate_enchantment_bonuses()

	_reset()
	var flash0: int = stats.get_max_flash_points()
	var mv := Card.create_by_id("enchantment_movement")
	dm.hand.append(mv)
	main._recalculate_enchantment_bonuses()
	_check(stats.get_max_flash_points() - flash0 == 5 * PlayerStats.FLASH_COST_MOVE, "Enchantment: Movement -> 5 more tiles of flash per refresh (%d points)" % (stats.get_max_flash_points() - flash0))
	main._process_enchantment_cycles()
	main._process_enchantment_cycles()
	_check(dm.discard_pile.has(mv), "Enchantment: Movement discards after 2 cycles")
	main._recalculate_enchantment_bonuses()

func _t_endured_tolerance() -> void:
	print("-- Endured Tolerance --")
	_reset()
	var c := Card.create_endured_tolerance(5)
	var r := _play(c, main.player)
	_check(_costs(r, 20, 1), "Endured Tolerance costs 20 mana / 1 tempo (%s)" % _cost_str(r))
	var b: Buff = bm.get_buff(Buff.BuffType.RESILIENT)
	_check(b != null and b.value == 5 and b.damage_type == DamageTypes.ALL, "Endured Tolerance: 5% resistance to all damage")
	var d0: int = b.duration if b else 0
	_play(Card.create_endured_tolerance(5), main.player)
	b = bm.get_buff(Buff.BuffType.RESILIENT)
	_check(b != null and b.value == 5 and b.duration == d0 + 5 - 1, "another copy adds 5 more tempo, not more %% (%d -> %d, one tick of its play spent)" % [d0, b.duration if b else -1])
	# Erase 20 that waits for the Glut.
	var held := Card.create_endured_tolerance(5)
	dm.hand.append(held)
	main.glut_tempo_remaining = 10
	dm._process_erase_timers()
	_check(held.erase_tempo_remaining == 20, "its Erase fuse waits while Glutted")
	main.glut_tempo_remaining = 0
	for i in range(4):
		dm._process_erase_timers()
	_check(not dm.hand.has(held), "then it erases after 20 tempo")

func _t_energy_ball() -> void:
	print("-- Energy Ball --")
	_reset()
	var c := Card.create_by_id("energy_ball")
	c.damage = 12
	c.base_damage = 12
	_check(c.get_effective_range() == 6, "Energy Ball reaches 6")
	var en := _spawn(Vector2i(5, 0))
	var want: int = stats.get_effective_spell_damage(12)
	var r := _play(c, en)
	_check(_costs(r, 10, 1), "Energy Ball costs 10 mana / 1 tempo (%s)" % _cost_str(r))
	_check(_lost(en) == want, "Energy Ball deals X = Absorb Essence's total (as a spell) (%d, want %d)" % [_lost(en), want])
	_check(not dm.discard_pile.has(c) and not dm.hand.has(c), "Energy Ball is erased after use")

func _t_energy_barrier() -> void:
	print("-- Energy Barrier --")
	_reset()
	var c := Card.create_energy_barrier(5)
	var r := _play(c, main.player)
	_check(_costs(r, 0, 0), "Energy Barrier costs 0 mana / 0 tempo (%s)" % _cost_str(r))
	_check(stats.current_armor == 5, "Energy Barrier: gain 5 armor (%d)" % stats.current_armor)
	var held := Card.create_energy_barrier(5)
	dm.hand.append(held)
	dm._process_erase_timers()
	_check(not dm.hand.has(held), "Erase 1: gone at the next erase tick")

func _t_escape_and_bewilder() -> void:
	print("-- Escape and bewilder --")
	_reset()
	var origin: Vector2i = _player_cell()
	var near := _spawn(Vector2i(2, 1))
	var far := _spawn(Vector2i(-4, 0))
	var dest: Vector2i = origin + Vector2i(0, -4)
	# The cursor wanders off during the wind-up: the blink still lands on the aimed tile.
	main.mouse_override = Vector2(5, 5)
	var r := _play(Card.create_by_id("escape_and_bewilder"), main.player, dest)
	_check(_costs(r, 50, 2), "Escape and bewilder costs 50 mana / 2 tempo (%s)" % _cost_str(r))
	_check(_player_cell() == dest, "Escape and bewilder blinks up to 5 spaces to the aimed tile (%s, want %s)" % [str(_player_cell()), str(dest)])
	# The 3-tempo stun lands on the resolving tick, which already counts as one.
	_check(near.is_stunned and near.stun_tempo == 2, "an enemy within 3 of the vacated tile is stunned for 3 tempo (%d left after the landing tick)" % near.stun_tempo)
	tm._process_one_tick()
	tm._process_one_tick()
	_check(not near.is_stunned or near.stun_tempo <= 0, "and the stun is over 3 tempo after it landed")
	_check(not far.is_stunned, "an enemy 4 from it is not")
	_reset()
	var too_far: Vector2i = _player_cell() + Vector2i(0, -6)
	var before: Vector2i = _player_cell()
	_play(Card.create_by_id("escape_and_bewilder"), main.player, too_far)
	_check(_player_cell() == before, "no blink past 5 spaces")

func _t_exhausted_assault() -> void:
	print("-- Exhausted Assault --")
	_reset()
	var c := Card.create_by_id("exhausted_assault")
	_check(c.get_effective_range() == 5, "Exhausted Assault is ranged 5")
	var en := _spawn(Vector2i(4, 0))
	var per: int = stats.get_effective_physical_damage(4)
	var r := _play(c, en)
	_check(_costs(r, 40, 3), "Exhausted Assault costs 40 mana / 3 tempo with mana (%s)" % _cost_str(r))
	_check(_lost(en) == per * 3, "Exhausted Assault deals 4 damage 3 times (%d, want %d)" % [_lost(en), per * 3])
	_check(main.glut_tempo_remaining > 0 and main.glut_tempo_remaining <= 10, "Glut 10 after it resolves (%d)" % main.glut_tempo_remaining)
	_reset()
	stats.current_mana = 0
	var c2 := Card.create_by_id("exhausted_assault")
	var en2 := _spawn(Vector2i(2, 0))
	r = _play(c2, en2)
	_check(r["played"] and r["mana"] == 0, "at zero mana it costs 0 mana (%s)" % _cost_str(r))

func _t_exposed_artery() -> void:
	print("-- Exposed Artery --")
	_reset()
	var en := _spawn(Vector2i(1, 0))
	en.current_health = 400  # 60% missing
	var r := _play(Card.create_by_id("exposed_artery"), en)
	_check(_costs(r, 50, 2), "Exposed Artery costs 50 mana / 2 tempo (%s)" % _cost_str(r))
	_check(400 - en.current_health == 30, "Exposed Artery deals 0.5 x 60%% missing = 30 (%d)" % (400 - en.current_health))

func _t_exposing_strike() -> void:
	print("-- Exposing Strike --")
	_reset()
	var en := _spawn(Vector2i(1, 0))
	var want: int = stats.get_effective_physical_damage(10)
	var r := _play(Card.create_by_id("exposing_strike"), en)
	_check(_costs(r, 30, 3), "Exposing Strike costs 30 mana / 3 tempo (%s)" % _cost_str(r))
	_check(_lost(en) == want and en.vulnerable_stacks == 1, "Exposing Strike: 10 damage and 1 Vulnerable (%d, vuln %d)" % [_lost(en), en.vulnerable_stacks])

func _t_feed_into_the_pain() -> void:
	print("-- Feed into the Pain --")
	_reset()
	var c := Card.create_by_id("feed_into_the_pain")
	dm.hand.append(c)
	_check(not dm.play_card(0, null, main.player)["played"], "an Instant cannot be played by hand")
	stats.current_health = 200  # 40%: a hit above 30% does nothing
	stats.take_damage(10)
	_check(dm.hand.has(c), "a hit that leaves you above 30% does not fire it")
	stats.take_damage(60)  # 130 = 26%
	var s: Buff = bm.get_buff(Buff.BuffType.STRENGTHEN)
	_check(not dm.hand.has(c), "a hit below 30% health fires it")
	_check(s != null and s.value == 20 and s.charges == 4, "Strengthen 20 for 4 attacks")
	_check(stats.current_temp_health == 25 and stats.temp_health_tempo_remaining == 5, "25 temp HP for 5 tempo (%d / %d)" % [stats.current_temp_health, stats.temp_health_tempo_remaining])

func _t_fire_punch() -> void:
	print("-- Fire Punch --")
	_reset()
	var en := _spawn(Vector2i(1, 0))
	var want: int = stats.get_effective_physical_damage(0)
	var spots0: int = main._fire_spots.size()
	var c := Card.create_by_id("fire_punch")
	var r := _play(c, en)
	_check(_costs(r, 5, 1), "Fire Punch costs 5 mana / 1 tempo (%s)" % _cost_str(r))
	_check(_lost(en) == want, "Fire Punch: 0 base + STR scaling (%d, want %d)" % [_lost(en), want])
	var ecell: Vector2i = main.grid_manager.world_to_grid(en.position)
	var cells: Array = []
	for i in range(spots0, main._fire_spots.size()):
		cells.append(main._fire_spots[i]["cell"])
	_check(cells.has(ecell + Vector2i(1, 0)) and cells.has(ecell + Vector2i(2, 0)), "a path of fire behind the target (%s)" % str(cells))
	var copies: Array = dm.hand.filter(func(h): return h.card_id == "fire_punch")
	_check(copies.size() == 1 and copies[0].erase_tempo == 5, "a copy with Erase 5 lands in hand")
	if copies.size() == 1:
		_drain()
		_play(copies[0], en)
		_check(dm.hand.filter(func(h): return h.card_id == "fire_punch").is_empty(), "the copy does not copy itself")

func _t_fireball() -> void:
	print("-- Fireball --")
	_reset()
	var staff := ItemData.new()
	staff.item_name = "Test Staff"
	staff.card_slots = 1
	var c := Card.create_by_id("fireball")
	if not staff.slot_card(c):
		c.slotted_in_item = staff
	_check(c.get_effective_range() == 10, "Fireball: range +5 (%d)" % c.get_effective_range())
	var aim: Vector2i = _player_cell() + Vector2i(6, 0)
	var hit := _spawn(Vector2i(6, 0))
	var edge := _spawn(Vector2i(6, 2))
	var miss := _spawn(Vector2i(6, 3))
	var want: int = stats.get_effective_spell_damage(12)
	main.mouse_override = Vector2(3, 3)  # the cursor is elsewhere when it lands
	var r := _play(c, main.player, aim)
	_check(_costs(r, 80, 8), "Fireball costs 80 mana / 8 tempo (%s)" % _cost_str(r))
	_check(_lost(hit) == want and hit.burn_stacks == 3, "Fireball: 12 damage and 3 burn where it was aimed (%d, burn %d)" % [_lost(hit), hit.burn_stacks])
	_check(_lost(edge) == want, "the 4-square circle catches an enemy 2 from the centre (%d)" % _lost(edge))
	_check(_lost(miss) == 0, "an enemy 3 from the centre is outside it")
	_reset()
	dm.fire_spells_this_turn = 2
	var c2 := Card.create_by_id("fireball")
	c2.slotted_in_item = staff
	r = _play(c2, main.player, _player_cell() + Vector2i(6, 0))
	_check(r["played"] and r["mana"] == 60, "1 less mana (10 on the x10 scale) per other fire spell this cycle (%s)" % _cost_str(r))
	_reset()
	stats.equipment_crit_bonus = 100.0
	var c3 := Card.create_by_id("fireball")
	c3.slotted_in_item = staff
	var crit_t := _spawn(Vector2i(6, 0))
	_play(c3, main.player, _player_cell() + Vector2i(6, 0))
	_check(_lost(crit_t) > want, "Fireball can crit (%d > %d)" % [_lost(crit_t), want])
	_reset()
	var bare := Card.create_by_id("fireball")
	r = _play(bare, main.player, _player_cell() + Vector2i(6, 0))
	_check(not r["played"], "an unengraved Fireball cannot be played")

func _t_fleet_etching() -> void:
	print("-- Fleet Etching --")
	_reset()
	var boots := ItemData.new()
	boots.item_name = "Test Boots"
	boots.item_type = ItemData.ItemType.BOOTS
	boots.card_slots = 1
	var c := Card.create_by_id("fleet_etching")
	boots.slot_card(c)
	var r := _play(c, main.player)
	_check(_costs(r, 0, 2), "Fleet Etching costs 0 mana / 2 tempo (%s)" % _cost_str(r))
	var h: Buff = bm.get_buff(Buff.BuffType.HASTE)
	_check(h != null and h.value == 1 and h.charges == 2, "Fleet Etching: Haste 1 for the next 2 moves")

func _t_forever_armor() -> void:
	print("-- Forever Armor --")
	_reset()
	var cap0: int = stats.get_unerring_cap()
	var c := Card.create_by_id("forever_armor")
	var reserved0: int = stats.maintained_mana
	var r := _play(c, main.player)
	_check(r["played"] and r["mana"] == 20, "Forever Armor costs 20 mana (%s)" % _cost_str(r))
	_check(dm.maintained_cards.has(c) and stats.maintained_mana - reserved0 == 20, "it is maintained, reserving 20")
	_check(stats.get_unerring_cap() - cap0 == 6, "Maintain: +6 max unerring armor (%d)" % (stats.get_unerring_cap() - cap0))
	dm.maintained_cards.erase(c)
	main._sync_maintained_passives()
	_check(stats.get_unerring_cap() == cap0, "the cap falls back when it is no longer maintained")

func _t_fortify_alliance() -> void:
	print("-- Fortify Alliance --")
	_reset()
	var ally = _ally()
	if ally == null:
		return
	var c := Card.create_by_id("fortify_alliance")
	_check(c.get_effective_range() == 5, "Fortify Alliance reaches 5")
	ally.position = main._ground_pos(_player_cell() + Vector2i(0, 2))
	var ast = ally.get_stats()
	ast.current_health = 300
	var r := _play(c, ally)
	_check(_costs(r, 20, 3), "Fortify Alliance costs 20 mana / 3 tempo (%s)" % _cost_str(r))
	_check(ast.current_health >= 305, "Fortify Alliance heals the ally for 5 (%d)" % (ast.current_health - 300))
	_check(stats.current_armor == 5, "and gives the caster 5 armor (%d)" % stats.current_armor)
	ast.current_health = ast.max_health

func _t_fountain_of_life() -> void:
	print("-- Fountain of Health --")
	_reset()
	var c := Card.create_by_id("fountain_of_life")
	var r := _play(c, main.player)
	_check(r["played"] and r["mana"] == 30, "Fountain of Health costs 30 mana (%s)" % _cost_str(r))
	_check(dm.maintained_cards.has(c), "it is maintained (3M)")
	_drain()
	dm.hand.clear()
	dm.draw_pile.append(Card.create_by_id("block"))
	var hp0: int = stats.current_health
	main._process_maintained_card_effects()
	_check(hp0 - stats.current_health == 2, "every cycle: 2 damage to self (%d)" % (hp0 - stats.current_health))
	_check(dm.hand.size() == 1, "and a card drawn (%d)" % dm.hand.size())
	dm.maintained_cards.erase(c)

func _t_friendship() -> void:
	print("-- Friendship --")
	_reset()
	var ally = _ally()
	if ally == null:
		return
	var c := Card.create_by_id("friendship")
	_check(c.get_effective_range() == 5 and main.FRIENDSHIP_SECOND_RANGE == 10, "first ally within 5, second within 10")
	ally.position = main._ground_pos(_player_cell() + Vector2i(0, 6))
	var ast = ally.get_stats()
	ast.current_health = 300
	ast.current_armor = 0
	c.picked_ally = ally
	var r := _play(c, main.player)
	_check(_costs(r, 30, 0), "Friendship costs 30 mana / 0 tempo (%s)" % _cost_str(r))
	stats.current_health = 300
	stats.heal(4)
	_check(ast.current_health > 300, "when one heals, both heal (ally %d)" % ast.current_health)
	var a0: int = ast.current_health
	var p0: int = stats.current_health
	stats.take_damage(10)
	_check(p0 - stats.current_health == 5 and a0 - ast.current_health == 5, "damage is split (%d / %d)" % [p0 - stats.current_health, a0 - ast.current_health])
	tm.add_tempo(5)
	_check(stats.friendship_partner == null, "the bond lasts 5 tempo")
	ast.current_health = ast.max_health

func _t_from_the_ashes() -> void:
	print("-- From the Ashes --")
	_reset()
	pdm.apply_debuff(Debuff.create(Debuff.DebuffType.BURN, 4, 20))
	var near := _spawn(Vector2i(2, 1))
	var far := _spawn(Vector2i(4, 0))
	stats.current_health = 200
	var r := _play(Card.create_by_id("from_the_ashes"), main.player)
	_check(_costs(r, 80, 2), "From the Ashes costs 80 mana / 2 tempo (%s)" % _cost_str(r))
	_check(pdm.get_debuff(Debuff.DebuffType.BURN) == null, "it purges all your Burn")
	_check(_lost(near) == 20 and _lost(far) == 0, "enemies within 3 take 5 per stack purged (%d, far %d)" % [_lost(near), _lost(far)])
	_check(stats.current_health - 200 >= 20, "heal 5 per stack (+%d)" % (stats.current_health - 200))
	var rg: Buff = bm.get_buff(Buff.BuffType.REGEN)
	_check(rg != null and rg.value == 2, "Regen equal to half the stacks (%d)" % (rg.value if rg else -1))

func _t_gain_mana() -> void:
	print("-- Energy (gain_mana) --")
	_reset()
	stats.current_mana = 100
	var r := _play(Card.create_by_id("gain_mana"), main.player)
	_check(_costs(r, 0, 1), "Energy costs 0 mana / 1 tempo (%s)" % _cost_str(r))
	_check(_gains == [20], "Energy: gain 2 mana (20 on the x10 scale) (%s)" % str(_gains))

func _t_gargle_and_spit() -> void:
	print("-- Gargle and Spit --")
	_reset()
	stats.current_health = 300
	var want: int = stats.get_effective_heal_amount(3)
	var c := Card.create_by_id("gargle_and_spit")
	_check(c.get_effective_range() == 5 and c.target_types.has("ally"), "Gargle and Spit can be aimed at an ally within 5")
	var r := _play(c, main.player)
	_check(_costs(r, 10, 1), "Gargle and Spit costs 10 mana / 1 tempo (%s)" % _cost_str(r))
	_check(stats.current_health - 300 == want, "heal 3 (%d)" % (stats.current_health - 300))
	var m: Buff = bm.get_buff(Buff.BuffType.MIGHT)
	_check(m != null and m.value == 1 and m.duration == 20 - 1, "+1 strength for 20 tempo (one tick of its play spent) (%s)" % (str(m.value) + "/" + str(m.duration) if m else "none"))
	_check(dm.hand.has(c), "Sticky 4: it stays in hand")
	for i in range(3):
		_drain()
		_play(c, main.player)
	_check(not dm.hand.has(c) and dm.discard_pile.has(c), "after the 4th play it is discarded")

func _t_gift_from_the_gods() -> void:
	print("-- Gift from the Gods --")
	_reset()
	var r := _play(Card.create_by_id("gift_from_the_gods"), main.player)
	_check(r["played"] and r["mana"] == 40, "Gift from the Gods costs 40 mana (%s)" % _cost_str(r))
	var en: Buff = bm.get_buff(Buff.BuffType.KEEN)
	_check(en != null and en.value == 10 and en.charges == 3, "Gain 3 Keen (10% crit chance)")

func _t_gift_from_the_phoenix() -> void:
	print("-- Gift from the Phoenix --")
	_reset()
	var c := Card.create_by_id("gift_from_the_phoenix")
	dm.hand.append(c)
	var near := _spawn(Vector2i(2, 0))
	var far := _spawn(Vector2i(6, 0))
	stats.healing_bonus = 7  # healing gear must not carry it past 80%
	stats.current_health = 300
	main._last_hp_ratio = 0.6
	stats.take_damage(100)  # 200 / 500 = 40%
	_check(not dm.hand.has(c), "dropping below 50% fires it")
	_check(stats.current_health == 400, "heal up to 80%% — not past it (%d / 500)" % stats.current_health)
	_check(near.burn_stacks == 5 and far.burn_stacks == 0, "5 burn on the nearest enemy (%d, far %d)" % [near.burn_stacks, far.burn_stacks])

func _t_give_in() -> void:
	print("-- Give In --")
	_reset()
	stats.current_mana = 100
	var r := _play(Card.create_by_id("give_in"), main.player)
	_check(_costs(r, 0, 2), "Give In costs 0 mana / 2 tempo (%s)" % _cost_str(r))
	_check(_gains == [30], "immediately gain 3 mana (30) (%s)" % str(_gains))
	_check(dm.skip_next_tempo_draw, "the next tempo draw is skipped")
	_drain()
	dm.hand.clear()
	for i in range(3):
		dm.draw_pile.append(Card.create_by_id("block"))
	var guard := 0
	while dm.skip_next_tempo_draw and guard < 30:
		tm.add_tempo(1)
		guard += 1
	_check(not dm.skip_next_tempo_draw and dm.hand.is_empty(), "the next tempo-triggered draw does not happen (hand %d)" % dm.hand.size())

func _t_god_of_thunder() -> void:
	print("-- God of Thunder --")
	_reset()
	var c := Card.create_by_id("god_of_thunder")
	_check(c.get_effective_range() == 9, "God of Thunder reaches 9")
	var tgt := _spawn(Vector2i(6, 0))
	var r := _play(c, tgt)
	_check(_costs(r, 50, 10), "God of Thunder costs 50 mana / 10 tempo (%s)" % _cost_str(r))
	_reset()
	var t2 := _spawn(Vector2i(6, 0))
	var in_r := _spawn(Vector2i(6, 3))
	var out_r := _spawn(Vector2i(6, -5))
	t2.shock_stacks = 2
	in_r.shock_stacks = 3
	out_r.shock_stacks = 4
	main._apply_card_world_effects(Card.create_by_id("god_of_thunder"), t2)
	_check(t2.shock_stacks == 0 and in_r.shock_stacks == 0 and out_r.shock_stacks == 4, "absorbs all shock within a diameter of 8 of the target")
	_check(_lost(t2) == 5, "the bolt deals the shock absorbed (%d)" % _lost(t2))

func _t_grounding() -> void:
	print("-- Grounding --")
	_reset()
	var shocked := _spawn(Vector2i(4, 0))
	var clean := _spawn(Vector2i(0, 5))
	var outside := _spawn(Vector2i(11, 0))
	shocked.shock_stacks = 2
	outside.shock_stacks = 3
	pdm.apply_debuff(Debuff.create(Debuff.DebuffType.SHOCKED, 1, 20))
	var c := Card.create_by_id("grounding")
	dm.hand.append(c)
	main._update_grounding_discount()
	var r := _play(c, main.player)
	_check(_costs(r, 185, 10), "Grounding costs 200 - 5 per Shock in reach (3 -> 185) / 10 tempo (%s)" % _cost_str(r))
	_check(shocked.shock_stacks == 0 and outside.shock_stacks == 3, "absorbs every Shock within 10 squares, not beyond")
	_check(pdm.get_debuff(Debuff.DebuffType.SHOCKED) == null, "your own Shock too")
	_check(_lost(shocked) == 10 and _lost(clean) == 10 and _lost(outside) == 0, "10 damage to each enemy in the radius, shocked or not (%d, %d, %d)" % [_lost(shocked), _lost(clean), _lost(outside)])

func _t_gulped_potion() -> void:
	print("-- Gulped Potion --")
	_reset()
	stats.current_health = 300
	var want: int = stats.get_effective_heal_amount(1)
	var c := Card.create_by_id("gulped_potion")
	var r := _play(c, main.player)
	_check(_costs(r, 10, 3), "Gulped Potion costs 10 mana / 3 tempo (%s)" % _cost_str(r))
	_check(stats.current_health - 300 == want, "heal 1 (%d)" % (stats.current_health - 300))
	_check(dm.hand.has(c), "Sticky 3: it stays in hand")
	for i in range(2):
		_drain()
		_play(c, main.player)
	_check(not dm.hand.has(c), "gone after the 3rd play")

func _t_halo() -> void:
	print("-- Halo --")
	_reset()
	var c := Card.create_by_id("halo")
	var r := _play(c, main.player)
	_check(r["played"] and r["mana"] == 30 and dm.maintained_cards.has(c), "Halo costs 30 mana and is maintained (3M) (%s)" % _cost_str(r))
	_drain()
	var ally = _ally()
	stats.current_health = 300
	var in_ally = ally
	if in_ally:
		in_ally.position = main._ground_pos(_player_cell() + Vector2i(0, 2))
		in_ally.get_stats().current_health = 300
	main._spawn_wolf()
	var wolf = main._wolves.back() if not main._wolves.is_empty() else null
	if wolf:
		wolf.health = 1
	main._process_maintained_card_effects()
	_check(stats.current_health > 300, "every cycle Halo heals you (+%d)" % (stats.current_health - 300))
	_check(in_ally == null or in_ally.get_stats().current_health > 300, "and an ally within 3")
	_check(wolf != null and wolf.health > 1, "summons inside the radius are allies too (wolf %d)" % (wolf.health if wolf else -1))
	if in_ally:
		in_ally.position = main._ground_pos(_player_cell() + Vector2i(0, 5))
		in_ally.get_stats().current_health = 300
		main._process_maintained_card_effects()
		_check(in_ally.get_stats().current_health == 300, "an ally 5 squares away is outside the circle")
		in_ally.get_stats().current_health = in_ally.get_stats().max_health
	dm.maintained_cards.erase(c)
	if wolf and is_instance_valid(wolf):
		main._wolves.erase(wolf)
		wolf.queue_free()

func _t_hard_helmet() -> void:
	print("-- Hard Helmet --")
	_reset()
	var hh := Card.create_by_id("hard_helmet")
	var close := _spawn(Vector2i(2, 0))
	var aimed := _spawn(Vector2i(6, 0))
	dm.hand.append(hh)
	# A utility play fires it — even one aimed at a farther enemy.
	main._weapon_post_card_effects(Card.create_by_id("draw"), aimed)
	_check(not dm.hand.has(hh), "playing a utility card fires it")
	_check(stats.current_armor == 8, "gain 8 armor (%d)" % stats.current_armor)
	_check(_lost(close) == 2 and _lost(aimed) == 0, "2 damage to the closest enemy (%d, aimed-at %d)" % [_lost(close), _lost(aimed)])
	_reset()
	var hh2 := Card.create_by_id("hard_helmet")
	dm.hand.append(hh2)
	var e3 := _spawn(Vector2i(3, 0))
	_play(Card.create_by_id("draw"), main.player)
	_check(not dm.hand.has(hh2) and _lost(e3) == 2, "fires off a real utility play (%d)" % _lost(e3))

func _t_harden() -> void:
	print("-- Harden --")
	_reset()
	var r := _play(Card.create_by_id("harden"), main.player)
	_check(r["played"] and r["mana"] == 30, "Harden costs 30 mana (%s)" % _cost_str(r))
	_check(stats.current_armor == 10, "Harden: 10 armor (%d)" % stats.current_armor)
	var rs: Buff = bm.get_buff(Buff.BuffType.RESILIENT)
	_check(rs != null and rs.value == 10 and rs.damage_type == DamageTypes.Type.PHYSICAL and rs.duration >= 14, "10%% physical resistance for 15 tempo (%s)" % (str(rs.duration) if rs else "none"))

func _t_harness_lightning() -> void:
	print("-- Harness Lightning --")
	_reset()
	var near := _spawn(Vector2i(2, 1))
	var far := _spawn(Vector2i(5, 0))
	var per: int = stats.get_effective_spell_damage(4)
	var r := _play(Card.create_by_id("harness_lightning"), main.player)
	_check(r["played"] and r["mana"] == 30, "Harness Lightning costs 30 mana (%s)" % _cost_str(r))
	var n := 0
	for d in main._delayed_effects:
		if d["label"] == "harness_lightning":
			n += 1
	_check(n == 6, "an orb that strikes every 5 tempo for 30 tempo (%d strikes)" % n)
	_drain()
	var lost0: int = _lost(near)
	tm.add_tempo(30)
	_check(_lost(near) - lost0 == per * 6, "4 (INT-scaled) to an enemy within 3 each strike (%d, per %d)" % [_lost(near) - lost0, per])
	_check(_lost(far) == 0, "never an enemy 5 away")

func _t_heals() -> void:
	print("-- Heal / Healing Potion / Healing Tonic --")
	_reset()
	stats.current_health = 300
	var c := Card.create_by_id("heal")
	_check(c.get_effective_range() == 5 and c.target_types.has("ally"), "Heal reaches an ally within 5")
	var want: int = stats.get_effective_heal_amount(4)
	var r := _play(c, main.player)
	_check(_costs(r, 10, 2), "Heal costs 10 mana / 2 tempo (%s)" % _cost_str(r))
	_check(stats.current_health - 300 == want, "Heal: restore 4 HP (%d)" % (stats.current_health - 300))
	_reset()
	stats.current_health = 300
	want = stats.get_effective_heal_amount(5)
	r = _play(Card.create_by_id("healing_potion"), main.player)
	_check(_costs(r, 10, 1), "Healing Potion costs 10 mana / 1 tempo (%s)" % _cost_str(r))
	_check(stats.current_health - 300 == want, "Healing Potion: heal 5 (%d)" % (stats.current_health - 300))
	_reset()
	var ally = _ally()
	var t := Card.create_by_id("healing_tonic")
	_check(t.get_effective_range() == 5 and t.target_types.has("ally"), "Healing Tonic reaches an ally within 5")
	if ally:
		ally.position = main._ground_pos(_player_cell() + Vector2i(3, 0))
		var ast = ally.get_stats()
		ast.current_health = 300
		_check(main._is_target_in_card_range(t, ally), "an ally 3 squares away is in range")
		r = _play(t, ally)
		_check(_costs(r, 0, 0), "Healing Tonic costs 0 mana / 0 tempo (%s)" % _cost_str(r))
		_check(ast.current_health - 300 >= 5, "Healing Tonic heals the ally for 5 (%d)" % (ast.current_health - 300))
		ally.position = main._ground_pos(_player_cell() + Vector2i(6, 0))
		_check(not main._is_target_in_card_range(t, ally), "an ally 6 squares away is not")
		ast.current_health = ast.max_health

func _t_healthy_bliss() -> void:
	print("-- Healthy Bliss --")
	_reset()
	var c := Card.create_by_id("healthy_bliss")
	dm.hand.append(c)
	_check(not dm.play_card(0, null, main.player)["played"], "an Instant cannot be played by hand")
	var ally = _ally()
	stats.current_health = 300
	if ally:
		ally.get_stats().current_health = 300
	var want: int = stats.get_effective_heal_amount(10)
	for i in range(3):
		main._process_healthy_bliss_cards()
	_check(dm.hand.has(c) and stats.current_health == 300, "nothing before 20 tempo in hand")
	main._process_healthy_bliss_cards()
	_check(not dm.hand.has(c), "after 20 tempo in hand it fires")
	_check(stats.current_health - 300 == want, "heals you for 10 (%d)" % (stats.current_health - 300))
	_check(ally == null or ally.get_stats().current_health > 300, "and every ally")
	if ally:
		ally.get_stats().current_health = ally.get_stats().max_health

func _t_healthy_habit() -> void:
	print("-- Healthy Habit --")
	_reset()
	for i in range(4):
		dm.draw_pile.append(Card.create_by_id("block"))
	var c := Card.create_by_id("healthy_habit")
	stats.current_mana = 500
	var r := _play(c, main.player)
	_check(_costs(r, 20, 3), "Healthy Habit costs 20 mana / 3 tempo (%s)" % _cost_str(r))
	_check(dm.hand.size() == 2, "draw 2 cards (%d)" % dm.hand.size())
	_check(_gains == [20], "gain 2 mana (20) (%s)" % str(_gains))
	_drain()
	dm.hand.clear()
	_gains.clear()
	dm.discard_pile.erase(c)
	r = _play(c, main.player)
	_check(_costs(r, 30, 4), "Burden: the next play costs more (%s)" % _cost_str(r))

func _t_heavy_greedy_cheese() -> void:
	print("-- Heavy Greedy Cheese --")
	_reset()
	var cheese := Card.create_by_id("heavy_greedy_cheese")
	var en := _spawn(Vector2i(1, 0))
	var slash := Card.create_by_id("slash")
	dm.hand.append(cheese)
	var r := _play(slash, en)
	_check(_costs(r, slash.mana_cost + 100, slash.tempo_cost + 2), "with the Cheese in hand another card costs +100 mana and +2 tempo (%s)" % _cost_str(r))
	_drain()
	var other := Card.create_by_id("heavy_greedy_cheese")
	dm.hand.append(other)
	var want_mana: int = dm.greedy_cheese_mana() + 100
	r = _play(cheese, main.player)
	_check(_costs(r, want_mana, 5 + 2), "the Cheese itself: 25%% of max mana and 5 tempo, plus the other Cheese's tax (%s, want %d)" % [_cost_str(r), want_mana])
	_check(not dm.hand.has(cheese) and not dm.discard_pile.has(cheese) and not dm.draw_pile.has(cheese), "played, it is rid of for good")
	_check(dm.greedy_cheese_mana() == ceili(stats.max_mana * 0.25), "25%% of max mana (%d)" % dm.greedy_cheese_mana())
