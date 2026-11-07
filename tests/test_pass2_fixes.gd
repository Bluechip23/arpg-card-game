extends SceneTree

## Audit pass 2 (docs/audit/pass2.md): the shared causes behind rows the
## second re-read found contradicting their text, fixed once each.
##  - Point and area plays: on-hit item riders and life steal now follow the
##    hits main lands (Fire Book on a Fireball; Life Steal on Heroic Leap).
##  - "Ally" cards that act on a hero's stats refuse a summon pick instead of
##    landing on the caster; heals still reach a summon.
##  - Summons step once per tempo through a multi-tempo advance, and a walk
##    never banks attacks.
## Run: godot --headless --path . --script tests/test_pass2_fixes.gd

var failures: int = 0
var main = null
var stats = null
var dm = null
var bm = null
var pdm = null
var tm = null
var inv = null
var _spawned: Array = []
var _home := Vector2i.ZERO

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	TempoManager.preferred_swing_hold = 0
	await _boot()
	if main == null:
		quit(1)
		return
	_t_area_riders()
	_t_area_life_steal()
	await _t_summon_ally_picks()
	_t_summon_steps()
	_t_threshold_triggers()
	_t_exhausted_assault()
	_t_communal_donation_pool()
	_t_donate_cleats_save()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------ helpers

func _boot() -> void:
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
	bm = main.player.get_buff_manager()
	pdm = main.player.get_debuff_manager()
	tm = main.tempo_manager
	inv = main.player.get_inventory()
	for e in main.enemy_spawner.get_living_enemies().duplicate():
		main.enemy_spawner.despawn_enemy(e)
	_reset()

func _reset() -> void:
	_drain()
	for e in _spawned:
		if is_instance_valid(e):
			main.enemy_spawner.despawn_enemy(e)
	_spawned.clear()
	stats.max_health = 500
	stats.current_health = 500
	stats.current_armor = 0
	stats.equipment_crit_bonus = -100.0
	stats.sphere_bonus_life_steal = 0.0
	stats.max_mana = 2000
	stats.current_mana = 2000
	pdm.clear_all_debuffs()
	dm.hand.clear()
	dm.maintained_cards.clear()
	main._last_aim_world = null
	main.mouse_override = Vector2(-1, -1)
	tm.current_tempo = 0
	main.player.position = main._ground_pos(_home)
	main.player.target_position = main.player.position

func _cell() -> Vector2i:
	return main.grid_manager.world_to_grid(main.player.position)

func _spawn(offset: Vector2i, hp: int = 1000) -> Enemy:
	var e: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.DUMMY, main._ground_pos(_cell() + offset))
	e.chosen_action = {}
	e.max_health = hp
	e.current_health = hp
	e.current_armor = 0
	_spawned.append(e)
	return e

func _drain() -> void:
	var n := 0
	while tm._pending_ticks > 0 and n < 200:
		tm._process_one_tick()
		n += 1

func _queued(card: Card) -> bool:
	for en in main._pending_resolve_queue:
		if en["card"] == card:
			return true
	return false

func _play(card: Card, target, aim_cell = null) -> void:
	if not dm.hand.has(card):
		dm.hand.append(card)
	if aim_cell != null:
		main._last_aim_world = main._ground_pos(aim_cell)
	main.selected_card_index = dm.hand.find(card)
	main.play_selected_card(target)
	var n := 0
	while _queued(card) and n < 60:
		tm._process_one_tick()
		n += 1
	main._last_aim_world = null

## Fireball in a plain staff slot (as test_wiring_cards_b plays it).
func _staff_fireball() -> Card:
	var staff := ItemData.new()
	staff.item_name = "Test Staff"
	staff.card_slots = 1
	var c := Card.create_by_id("fireball")
	if not staff.slot_card(c):
		c.slotted_in_item = staff
	return c

# -------------------------------------------------------------------- tests

func _t_area_riders() -> void:
	print("-- A point card carries the item riders onto every enemy it hits --")
	_reset()
	var bare := _staff_fireball()
	var a := _spawn(Vector2i(6, 0))
	var b := _spawn(Vector2i(6, 1))
	_play(bare, main.player, _cell() + Vector2i(6, 0))
	var base_burn: int = a.burn_stacks
	_check(base_burn > 0 and a.current_health < a.max_health, "a bare Fireball burns what it hits (%d)" % base_burn)
	_reset()
	var book := ItemData.create("fire_book")
	_check(inv.equip_item(book, 0), "Fire Book equips")
	a = _spawn(Vector2i(6, 0))
	b = _spawn(Vector2i(6, 1))
	var far := _spawn(Vector2i(6, 5))
	_play(_staff_fireball(), main.player, _cell() + Vector2i(6, 0))
	_check(a.burn_stacks == base_burn + 1 and b.burn_stacks == base_burn + 1,
		"Fire Book: +1 Burn on each enemy the blast hit (%d, %d)" % [a.burn_stacks, b.burn_stacks])
	_check(far.burn_stacks == 0, "an enemy outside the blast gets none")
	var arr: Array = inv._get_slot_array(book.item_type)
	inv.unequip_item(book.item_type, arr.find(book))

func _t_area_life_steal() -> void:
	print("-- Life steal follows the hits a point attack lands --")
	_reset()
	stats.sphere_bonus_life_steal = 50.0
	stats.current_health = 300
	var leap := Card.create_by_id("heroic_leap")
	_check(leap.is_attack(), "Heroic Leap is an attack")
	_play(leap, main.player, _cell() + Vector2i(2, 0))
	_check(stats.current_health == 300, "landing on empty ground heals nothing (%d)" % stats.current_health)
	_reset()
	stats.sphere_bonus_life_steal = 50.0
	stats.current_health = 300
	var e := _spawn(Vector2i(3, 0))
	_play(Card.create_by_id("heroic_leap"), main.player, _cell() + Vector2i(2, 0))
	var dealt: int = e.max_health - e.current_health
	# Brad's own Life Steal passive adds its 1 on top of the 50%.
	var healed: int = stats.current_health - 300
	_check(dealt > 0 and healed >= floori(dealt * 0.5) and healed <= floori(dealt * 0.5) + 1,
		"landing next to an enemy steals from the %d dealt (healed %d)" % [dealt, healed])

func _t_summon_ally_picks() -> void:
	print("-- Ally cards and a summon --")
	_reset()
	dm.maintained_cards.append(Card.create_by_id("spirit_bow"))
	main._summon_spirit_bow()
	var bow = main._spirit_bows[0]
	bow.position = main._ground_pos(_cell() + Vector2i(3, 0))
	bow._is_moving = false
	main.enemy_spawner.summons = main._all_summon_nodes()
	await process_frame
	for id in ["lady_luck", "provider", "the_lights_favor", "swap", "heal"]:
		_reset()
		dm.maintained_cards.append(Card.create_by_id("spirit_bow"))
		bow.health = 5
		stats.current_health = 400
		var card := Card.create_by_id(id)
		dm.hand.append(card)
		main.selected_card_index = 0
		var mana0: float = stats.current_mana
		main.mouse_override = main.get_world_camera().unproject_position(bow.position)
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = main.mouse_override
		main._input(ev)
		_drain()
		if id == "heal":
			_check(bow.health > 5 and stats.current_health == 400, "Heal on a summon heals the summon (%d)" % bow.health)
		else:
			_check(stats.current_mana == mana0 and card in dm.hand and stats.current_health == 400,
				"%s refuses a summon pick, nothing spent and nothing on the caster" % id)
	main.mouse_override = Vector2(-1, -1)
	main._clear_spirit_bows()

func _t_summon_steps() -> void:
	print("-- Summons through a 4-tempo advance --")
	_reset()
	dm.maintained_cards.append(Card.create_by_id("spirit_bow"))
	main._summon_spirit_bow()
	var bow = main._spirit_bows[0]
	bow.position = main._ground_pos(_cell() + Vector2i(0, 4))
	bow._is_moving = false
	var e := _spawn(Vector2i(14, 4))
	var start: Vector2i = bow.get_destination_cell()
	var target: Vector2i = main.grid_manager.world_to_grid(e.position)
	var d0: int = absi(start.x - target.x) + absi(start.y - target.y)
	main._update_spirit_bows(4)
	var now: Vector2i = bow.get_destination_cell()
	var d1: int = absi(now.x - target.x) + absi(now.y - target.y)
	_check(d0 - d1 == 4, "'1 square per tempo': 4 tempo walk 4 squares (%d -> %d)" % [d0, d1])
	_check(bow.attack_accum <= bow.attack_interval(), "the walk banks no more than one shot (%d)" % bow.attack_accum)
	main._update_spirit_bows(20)
	_check(bow.attack_accum <= bow.attack_interval(), "a long walk still banks one (%d)" % bow.attack_accum)
	main._clear_spirit_bows()

func _t_threshold_triggers() -> void:
	print("-- Tight Rope: 'When a hit puts you below 20% health' --")
	_reset()
	stats.max_health = 100
	stats.current_health = 15
	stats.current_armor = 50
	var tr := Card.create_by_id("tight_rope")
	dm.hand.append(tr)
	stats.take_damage(10, pdm, bm)
	_check(stats.current_health == 15 and bm.get_buff(Buff.BuffType.STRENGTHEN) == null,
		"already below 20%%, a hit the armor soaks fires nothing")
	_reset()
	stats.max_health = 100
	stats.current_health = 25
	dm.hand.append(Card.create_by_id("tight_rope"))
	stats.take_damage(10, pdm, bm)
	_check(stats.current_health == 15 and bm.get_buff(Buff.BuffType.STRENGTHEN) != null,
		"the hit that crosses 20%% fires it")
	for b in bm.buffs.duplicate():
		bm.remove_buff(b.buff_type)

func _t_exhausted_assault() -> void:
	print("-- Exhausted Assault: 'While you have zero mana, this card costs 0 mana' --")
	_reset()
	stats.current_mana = 0
	pdm.apply_debuff(Debuff.create(Debuff.DebuffType.STAGGERED, 2, 10))
	var ea := Card.create_by_id("exhausted_assault")
	dm.hand.append(ea)
	var cost: Dictionary = dm.compute_play_cost(ea, dm.hand.find(ea), null, pdm)
	_check(int(cost["mana"]) == 0, "Staggered at zero mana it still costs 0 (%d)" % int(cost["mana"]))
	pdm.clear_all_debuffs()

func _t_communal_donation_pool() -> void:
	print("-- Communal Donation: the heals split the health given --")
	_reset()
	var ally = main._dojo_allies[0] if not main._dojo_allies.is_empty() else null
	_check(ally != null, "the dojo has a practice ally")
	if ally == null:
		return
	var ast = ally.get_stats()
	ast.current_health = ast.max_health - 50
	stats.current_health = 400
	main._donation_panel = PanelContainer.new()
	main._donation_slider = HSlider.new()
	main._donation_slider.max_value = 100
	main._donation_slider.value = 10
	var s_self := HSlider.new()
	s_self.max_value = 100
	s_self.value = 10
	var s_ally := HSlider.new()
	s_ally.max_value = 100
	s_ally.value = 10
	main._donation_ally_sliders = [{"slider": s_self, "name": "Self", "node": main.player},
		{"slider": s_ally, "name": "Ally", "node": ally}]
	var a0: int = ast.current_health
	main._on_donation_confirmed()
	var to_self: int = stats.current_health - 390
	var to_ally: int = ast.current_health - a0
	# Both sliders at the full 10: the first takes the pool, nothing is left.
	# (A heal can land a point higher: the healer's own healing bonus.)
	_check(to_self >= 10 and to_ally == 0, "10 health given, 10 handed out, however the sliders sit (self %d, ally %d)" % [to_self, to_ally])
	main._donation_ally_sliders = []

func _t_donate_cleats_save() -> void:
	print("-- Donate Cleats: the 5-tempo loan is never saved --")
	_reset()
	var agi0: int = stats.base_agility
	var dex0: int = stats.base_dexterity
	main._apply_card_world_effects(Card.create_by_id("donate_cleats"), main.player)
	_check(stats.base_agility == agi0 + 5 and stats.base_dexterity == dex0 + 4, "lent: +5 AGI, +4 DEX")
	var saved: Dictionary = stats.save_progression()
	_check(int(saved["base_agility"]) == agi0 and int(saved["base_dexterity"]) == dex0, "a save mid-loan writes the stats without it")
	main._process_delayed_effects(5)
	_check(stats.base_agility == agi0 and stats.lent_agility == 0, "after 5 tempo the loan ends")
