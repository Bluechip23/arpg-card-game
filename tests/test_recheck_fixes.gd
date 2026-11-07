extends SceneTree

## Phase 6 re-check (docs/audit/validation.md): items the Phase 2 wiring audit
## marked CORRECT that an independent re-read found contradicting their text.
## Each is fixed to its description and proved here, in a booted dojo.
## Run: godot --headless --path . --script tests/test_recheck_fixes.gd

var failures := 0
var main = null
var stats: PlayerStats
var dm
var bm: BuffManager
var dbm: DebuffManager
var tm
var gm
var d1: Enemy

const HOME := Vector2i(8, 6)

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		printerr("  FAIL: %s" % msg)

func _initialize() -> void:
	print("=== Re-check fixes ===")
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
	bm = main.player.get_buff_manager()
	dbm = main.player.get_debuff_manager()
	tm = main.tempo_manager
	gm = main.grid_manager
	d1 = main.enemy_spawner.get_living_enemies()[0]
	stats.equipment_crit_bonus = -100.0
	_home()

	_test_petey()
	_test_vined_encasing()
	_test_premeditated()
	_test_mend()
	await _test_hero_only_ally_cards()

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

# ------------------------------------------------------------------ helpers

func _home() -> void:
	main.player.position = main._ground_pos(HOME)
	main.player.target_position = main.player.position
	main._player_last_grid_cell = HOME
	_put(d1, Vector2i(-6, -4))

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
	stats.max_health = 500
	stats.current_health = 500
	stats.current_armor = 0
	stats.max_mana = 1000
	stats.current_mana = 800
	stats.current_attack_counter = 99
	dbm.clear_all_debuffs()
	bm.remove_buff(Buff.BuffType.THORNS)
	main.mouse_override = Vector2(-1, -1)
	dm.hand.clear()
	d1.max_health = 1000
	d1.current_health = 1000
	d1.current_armor = 0
	d1.damage_resistances = {}
	d1.vulnerable_stacks = 0
	_home()

## Play `card` the way a click does and run the ticks until it resolves.
func _play(card: Card, target) -> void:
	dm.hand.clear()
	dm.hand.append(card)
	tm.current_tempo = 0
	main.selected_card_index = 0
	main.play_selected_card(target)
	var guard := 0
	while guard < 40:
		var queued := false
		for e in main._pending_resolve_queue:
			queued = queued or e["card"] == card
		if not queued:
			break
		tm._process_one_tick()
		guard += 1

# -------------------------------------------------------------------- tests

func _test_petey() -> void:
	print("-- Petey the Pet Rock: 'While in hand: Slowed 2' --")
	_fresh()
	var petey := Card.create_by_id("petey_the_pet_rock")
	dm.hand.append(petey)
	main._on_hand_updated()
	var slow = dbm.get_debuff(Debuff.DebuffType.SLOWED)
	_check(slow != null and slow.value == 2, "drawn, it slows you at once (2 stacks)")
	slow.value = 1  # a stack fell on the debuff's own clock
	main._apply_in_hand_debuffs()
	slow = dbm.get_debuff(Debuff.DebuffType.SLOWED)
	_check(slow != null and slow.value == 2, "the cycle tops it back up to 2")
	dm.hand.erase(petey)
	main._on_hand_updated()
	_check(dbm.get_debuff(Debuff.DebuffType.SLOWED) == null, "it lifts when Petey leaves the hand")
	dbm.apply_debuff(Debuff.create_slowed(1, "Frost"))
	main._on_hand_updated()
	_check(dbm.get_debuff(Debuff.DebuffType.SLOWED) != null, "a Slowed from another source is left alone")
	dbm.clear_all_debuffs()

func _vined(value: int) -> Buff:
	var b := Buff.create_thorns(value, 20, "Vined Encasing")
	b.decay_by_damage = true
	b._set_name_and_description()
	return b

func _test_vined_encasing() -> void:
	print("-- Vined Encasing: 'lose X thorns whenever you receive X damage' --")
	_fresh()
	stats.current_armor = 10
	_play(Card.create_by_id("vined_encasing"), main.player)
	var th: Buff = bm.get_buff(Buff.BuffType.THORNS)
	_check(th != null and th.value == 10 and th.decay_by_damage, "the card gives 1 thorn per armor (10)")
	bm.on_attacked(d1)
	_check(bm.get_buff(Buff.BuffType.THORNS).value == 10, "alone, a hit does not wear it down by 1")
	bm.decay_thorns_by_damage(4)
	_check(bm.get_buff(Buff.BuffType.THORNS).value == 6, "4 damage taken sheds 4")

	# Meeting ordinary thorns (Spiked Mitts etc.) used to drop the Vined rule.
	bm.remove_buff(Buff.BuffType.THORNS)
	bm.apply_buff(Buff.create_thorns(3, 20, "Spiked Mitts"))
	bm.apply_buff(_vined(10))
	th = bm.get_buff(Buff.BuffType.THORNS)
	_check(th.value == 13, "plain 3 + Vined 10 deal 13 back")
	bm.on_attacked(d1)
	_check(th.value == 12, "a hit wears the plain thorns by 1")
	bm.decay_thorns_by_damage(5)
	_check(th.value == 7 and th.vined_value == 5, "5 damage sheds 5 of the Vined thorns (7 left, 5 Vined)")
	bm.decay_thorns_by_damage(20)
	th = bm.get_buff(Buff.BuffType.THORNS)
	_check(th != null and th.value == 2 and not th.decay_by_damage, "damage never sheds the plain thorns (2 left)")

	bm.remove_buff(Buff.BuffType.THORNS)
	bm.apply_buff(_vined(10))
	bm.apply_buff(Buff.create_thorns(3, 20, "Spiked Mitts"))
	th = bm.get_buff(Buff.BuffType.THORNS)
	bm.decay_thorns_by_damage(4)
	_check(th.value == 9 and th.vined_value == 6, "plain thorns gained after Vined do not shed by damage")
	bm.remove_buff(Buff.BuffType.THORNS)

func _test_premeditated() -> void:
	print("-- Premeditated: 'your next card targeting that enemy deals +15' --")
	_fresh()
	_put(d1, Vector2i(1, 0))
	d1.premeditated_card_bonus = 15  # a first Premeditated exposed it
	var hp0 := d1.current_health
	_play(Card.create_by_id("premeditated"), d1)
	var dealt := hp0 - d1.current_health
	_check(dealt == stats.get_effective_physical_damage(8) + 15,
		"a second Premeditated is that next card: 8 + 15 (dealt %d)" % dealt)
	_check(int(d1.premeditated_card_bonus) == 0, "the bonus is spent")

func _test_mend() -> void:
	print("-- Mend: 'Allies within 4 squares restore 20% health' --")
	_fresh()
	main._summon_spirit_bow()
	var bow = main._spirit_bows.back() if main._spirit_bows.size() > 0 else null
	_check(bow != null, "a Spirit Bow summon stands by")
	if bow == null:
		return
	_put(bow, Vector2i(1, 1))
	bow.health = 5
	_play(Card.create_by_id("mend"), main.player)
	_check(bow.health == 5 + maxi(1, floori(bow.max_health * 0.2)),
		"a summon in range is restored too, not only Frankenstein's Monster (%d/%d)" % [bow.health, bow.max_health])
	main._clear_spirit_bows()

func _test_hero_only_ally_cards() -> void:
	print("-- Cryonics / Friendship on a summon --")
	_fresh()
	main._summon_spirit_bow()
	var bow = main._spirit_bows[0]
	_put(bow, Vector2i(3, 0))  # clear of the hero's own click radius
	main.enemy_spawner.summons = main._all_summon_nodes()  # as each tempo does
	await process_frame
	for id in ["cryonics", "friendship"]:
		_fresh()
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
		_check(dbm.get_debuff(Debuff.DebuffType.STUN) == null and not main.player.untargetable,
			"%s on a summon does not land on the caster" % id)
		_check(stats.current_mana == mana0 and card in dm.hand, "%s: nothing is spent" % id)
	main.mouse_override = Vector2(-1, -1)
	main._clear_spirit_bows()
