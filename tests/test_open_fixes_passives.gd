extends SceneTree

## Pass-2 open fixes, skill-tree passives (docs/audit/pass2.md rows 109,
## 112-114): Directed Strength, From the Hip, I Heal You, Keep Them Guessing,
## each proved against its description in a booted dojo.
## Run: godot --headless --path . --script tests/test_open_fixes_passives.gd

var failures := 0
var main = null
var stats: PlayerStats
var dm
var tm
var gm
var pt
var d1: Enemy

const HOME := Vector2i(8, 6)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Open fixes: passives ===")
	_run()

func _run() -> void:
	TempoManager.preferred_swing_hold = 0
	main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(6):
		await process_frame
	var guard := 0
	while main.olorin and main.olorin.is_busy() and guard < 10:
		main.olorin._close()
		guard += 1
		await process_frame
	stats = main.player.get_stats()
	dm = main.deck_manager
	tm = main.tempo_manager
	gm = main.grid_manager
	pt = main.progression_triggers
	d1 = main.enemy_spawner.get_living_enemies()[0]
	stats.equipment_crit_bonus = -100.0

	_test_directed_strength()
	_test_from_the_hip()
	_test_i_heal_you()
	_test_keep_them_guessing()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------ helpers

func _only(id: String, rank: int) -> void:
	stats.skill_tree_passives.clear()
	stats.passive_levels.clear()
	stats.add_skill_tree_passive(id)
	stats.passive_levels[id] = rank

func _home() -> void:
	main.player.position = main._ground_pos(HOME)
	main.player.target_position = main.player.position
	main._player_last_grid_cell = HOME

func _put(e: Node3D, off: Vector2i) -> void:
	e.position = main._ground_pos(HOME + off)
	if "target_position" in e:
		e.target_position = e.position

func _drain() -> void:
	var guard := 0
	while tm.is_ticking() and guard < 200:
		tm._process_one_tick()
		guard += 1

func _fresh() -> void:
	_drain()
	stats.max_health = 100
	stats.current_health = 100
	stats.current_temp_health = 0
	stats.current_armor = 0
	stats.max_mana = 1000
	stats.current_mana = 800
	stats.current_attack_counter = 99
	main.player.get_debuff_manager().clear_all_debuffs()
	main.mouse_override = Vector2(-1, -1)
	dm.hand.clear()
	dm.draw_pile.clear()
	dm.discard_pile.clear()
	dm.jail_pile.clear()
	d1.max_health = 1000
	d1.current_health = 1000
	d1.current_armor = 0
	_home()
	_put(d1, Vector2i(-6, -4))

func _queued(card: Card) -> bool:
	for e in main._pending_resolve_queue:
		if e["card"] == card:
			return true
	return false

# -------------------------------------------------------------------- tests

## "Gain 1→15 strength when below 50% health, lose it when going above."
func _test_directed_strength() -> void:
	print("-- Directed Strength --")
	_fresh()
	_only("directed_strength", 15)
	stats.current_health = 50
	_check(stats._directed_strength_mod() == 0, "Directed Strength: at exactly 50%% health it is not 'below 50%%' — no strength (mod %d)" % stats._directed_strength_mod())
	stats.current_health = 49
	_check(stats._directed_strength_mod() == 15, "Directed Strength: at 49%% it grants +15 (mod %d)" % stats._directed_strength_mod())
	stats.current_health = 51
	_check(stats._directed_strength_mod() == 0, "Directed Strength: above 50% it is lost")
	stats.skill_tree_passives.clear()
	stats.passive_levels.clear()

## "If an attack, your most recently drawn card has -Xm (ranks 11+ also -t).
## The discount is lost when any card is played." Losing it must not wipe
## what the card did to its own cost: Consecutive Snap's per-use cut.
func _test_from_the_hip() -> void:
	print("-- From the Hip --")
	for r in [1, 15]:
		_fresh()
		_only("from_the_hip", r)
		stats.st_from_hip_card = null
		_put(d1, Vector2i(2, 0))
		var m_off: int = mini(int(PassiveScaling.value("from_the_hip", "mana", r)), 30)
		var t_off: int = PassiveScaling.value("from_the_hip", "tempo", r)
		var snap := Card.create_by_id("consecutive_snap")
		dm.draw_pile.append(snap)
		dm.draw_card()
		_check(dm.hand.has(snap) and snap.mana_cost == 30 - m_off and snap.tempo_cost == 3 - t_off,
			"From the Hip r%d: drawn Consecutive Snap is discounted to %dm/%dt (%dm/%dt)" % [r, 30 - m_off, 3 - t_off, snap.mana_cost, snap.tempo_cost])
		var m0: float = stats.current_mana
		main.selected_card_index = dm.hand.find(snap)
		tm.current_tempo = 0
		main.play_selected_card(d1)
		_check(int(m0 - stats.current_mana) == 30 - m_off, "From the Hip r%d: the play paid the discounted %d mana (%d)" % [r, 30 - m_off, int(m0 - stats.current_mana)])
		var guard := 0
		while _queued(snap) and guard < 40:
			tm._process_one_tick()
			guard += 1
		_check(not _queued(snap) and d1.current_health < 1000, "From the Hip r%d: Snap resolved and hit" % r)
		_check(stats.st_from_hip_card == null, "From the Hip r%d: playing a card ended the discount" % r)
		_check(dm.hand.has(snap) and snap.mana_cost == 20 and snap.tempo_cost == 2,
			"From the Hip r%d: Snap keeps its own per-use cut (next 20m/2t), not reset to 30/3 (%dm/%dt)" % [r, snap.mana_cost, snap.tempo_cost])
		_drain()
	# A card that does not re-price itself gets exactly its cost back.
	_fresh()
	_only("from_the_hip", 15)
	var ms := Card.create_by_id("multishot")  # 30m / 6t attack
	pt._trigger_skill_tree_on_draw(ms)
	_check(ms.mana_cost == 0 and ms.tempo_cost == 4, "From the Hip r15: Multishot 30m/6t → 0m/4t")
	pt._trigger_skill_tree_on_card_play(Card.create_by_id("block"), null)
	_check(ms.mana_cost == 30 and ms.tempo_cost == 6, "From the Hip r15: another card played gives Multishot back its 30m/6t (%dm/%dt)" % [ms.mana_cost, ms.tempo_cost])
	stats.skill_tree_passives.clear()
	stats.passive_levels.clear()

## "Allies within 3 squares of you are healed 3 health every N tempo."
## You are not your own ally.
func _test_i_heal_you() -> void:
	print("-- I Heal You --")
	_fresh()
	_only("i_heal_you", 15)
	var pcell: Vector2i = gm.world_to_grid(main.player.position)
	var others: Array = []
	for a in main._dojo_allies:
		if is_instance_valid(a):
			others.append(a)
	# Park every dojo ally far away: Jeremy is alone.
	for a in others:
		a.position = gm.grid_to_world(pcell + Vector2i(12, 12))
	stats.current_health = 50
	var healed: int = pt._i_heal_you_pulse()
	_check(stats.current_health == 50 and healed == 0, "I Heal You: alone, it heals no one — not you (hp %d, healed %d)" % [stats.current_health, healed])
	if others.size() > 0:
		var near = others[0]
		near.position = gm.grid_to_world(pcell + Vector2i(2, 1))
		var ns = near.get_stats()
		ns.solemn_active = false
		ns.current_health = 10
		healed = pt._i_heal_you_pulse()
		_check(ns.current_health == 10 + ns.get_effective_heal_amount(3) and healed == 1,
			"I Heal You: an ally 3 squares away is healed 3, you are not (ally %d, you %d)" % [ns.current_health, stats.current_health])
		_check(stats.current_health == 50, "I Heal You: your own health is untouched")
	else:
		_check(false, "I Heal You: the dojo has an ally to heal")
	stats.skill_tree_passives.clear()
	stats.passive_levels.clear()

## "After discarding N cards, -3t from a random card in your hand." An
## instant firing is spending it, a jail release is setting it free: neither
## is a discard.
func _test_keep_them_guessing() -> void:
	print("-- Keep Them Guessing --")
	_fresh()
	_only("keep_them_guessing", 15)  # 4 discards
	stats.st_ktg_discard_count = 0
	var slash := Card.create_by_id("slash")
	dm.hand.append(slash)
	# An instant fires from hand.
	var inst := Card.create_by_id("cover")
	dm.hand.append(inst)
	_check(dm.fire_reaction(inst) and dm.discard_pile.has(inst), "Keep Them Guessing: an instant fired into the discard pile")
	_check(stats.st_ktg_discard_count == 0, "Keep Them Guessing: firing an instant is not a discard (count %d)" % stats.st_ktg_discard_count)
	# A card is released from jail at the cycle.
	var jailed := Card.create_by_id("block")
	jailed.jail_time_remaining = 1
	dm.jail_pile.append(jailed)
	dm.process_turn()
	_check(dm.discard_pile.has(jailed), "Keep Them Guessing: a jailed card was released into the discard pile")
	_check(stats.st_ktg_discard_count == 0, "Keep Them Guessing: a jail release is not a discard (count %d)" % stats.st_ktg_discard_count)
	# Ladder Work ("by means other than playing it") still hears both.
	_only("ladder_work", 1)
	stats.st_ladder_discard_count = 0
	var inst2 := Card.create_by_id("cover")
	dm.hand.append(inst2)
	dm.fire_reaction(inst2)
	_check(stats.st_ladder_discard_count == 1, "Keep Them Guessing: (Ladder Work still counts an instant reaching the pile)")
	_only("keep_them_guessing", 15)
	stats.st_ktg_discard_count = 0
	# Real discards count: the 4th cuts a hand card by 3 tempo.
	for _i in range(3):
		var c := Card.create_by_id("block")
		dm.hand.append(c)
		dm.discard_card_from_hand(c)
	_check(stats.st_ktg_discard_count == 3 and slash.temp_hand_tempo_reduction == 0, "Keep Them Guessing: 3 discards count 3, nothing yet")
	var c4 := Card.create_by_id("block")
	dm.hand.append(c4)
	dm.discard_card_from_hand(c4)
	_check(slash.temp_hand_tempo_reduction == 3, "Keep Them Guessing: the 4th discard cuts a hand card by 3 tempo")
	stats.skill_tree_passives.clear()
	stats.passive_levels.clear()
