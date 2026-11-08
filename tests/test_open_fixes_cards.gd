extends SceneTree

## Audit pass 2, open card rows (docs/audit/pass2.md): each card brought back
## to its description and proved here, in a booted dojo.
##  - Choke: every use's 2 damage lands at the next cycle.
##  - Harness Lightning: "within 3 spaces" counts grid steps.
##  - Lead Arrow: "Requires high ground" from the Bottomless Quiver too.
##  - Mirror Mirror: the copy is a duplicate of that very card.
##  - Release Tension: "any debuff" includes Polymorph and Narashimha.
##  - Reverberate Regrowth: every break returns its armor, each on its own timer.
##  - Savage Strike: the copy is added every play, past the deck-building cap.
##  - Shield of Growth: DoT ticks and Mind-over-Matter hits grow the armor.
##  - 20/20: the +3 range counts on a point-aimed ranged offensive card.
## Run: godot --headless --path . --script tests/test_open_fixes_cards.gd

var failures: int = 0
var main = null
var stats = null
var dm = null
var bm = null
var pdm = null
var tm = null
var _spawned: Array = []
var _home := Vector2i(2, 6)

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
	_t_choke()
	_t_harness_lightning()
	_t_lead_arrow_quiver()
	_t_mirror_mirror()
	_t_release_tension()
	_t_reverberate_regrowth()
	_t_savage_strike()
	_t_shield_of_growth()
	await _t_twenty_twenty()
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
	stats.exposed_cooldown_tempo = 0
	stats.pending_armor_returns.clear()
	stats.pending_mana_ward = false
	stats.equipment_crit_bonus = -100.0
	stats.max_mana = 2000
	stats.current_mana = 2000
	pdm.clear_all_debuffs()
	bm.buffs.clear()
	dm.hand.clear()
	dm.discard_pile.clear()
	dm.maintained_cards.clear()
	main.active_pillars.clear()
	main._last_aim_world = null
	main.mouse_override = Vector2(-1, -1)
	main.selected_card_index = -1
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

func _play(card: Card, target) -> void:
	if not dm.hand.has(card):
		dm.hand.append(card)
	main.selected_card_index = dm.hand.find(card)
	main.play_selected_card(target)
	var n := 0
	while _queued(card) and n < 60:
		tm._process_one_tick()
		n += 1

# -------------------------------------------------------------------- tests

func _t_choke() -> void:
	print("-- Choke: 'deal 2 damage at the next cycle' for every use --")
	_reset()
	var e := _spawn(Vector2i(1, 0))
	var ck := Card.create_by_id("choke")
	# Three Sticky uses inside one cycle (no tempo between them).
	for _i in range(3):
		ck.execute(e, stats, dm, 0.0, 0.0, bm)
	_check(e.choke_dot_stacks == 3, "three uses queue three grips (%d)" % e.choke_dot_stacks)
	var hp0: int = e.current_health
	e._cycle_accumulator = 0
	e._tick_status_durations()  # the next cycle
	_check(hp0 - e.current_health == 6, "all three land at the next cycle: 3 x 2 = 6 (%d)" % (hp0 - e.current_health))
	_check(e.choke_dot_stacks == 0, "…and nothing is left for a later cycle (%d)" % e.choke_dot_stacks)
	var hp1: int = e.current_health
	e._tick_status_durations()
	_check(e.current_health == hp1, "the cycle after deals nothing more")

func _t_harness_lightning() -> void:
	print("-- Harness Lightning: 'a random enemy within 3 spaces' (grid steps) --")
	_reset()
	var diag := _spawn(Vector2i(2, 2))  # 4 steps away, 2.8 world units
	var hp0: int = diag.current_health
	for _i in range(5):
		main._harness_lightning_tick()
	_check(diag.current_health == hp0, "an enemy 4 steps away (2 across, 2 down) is out of reach")
	var near := _spawn(Vector2i(3, 0))
	var hp1: int = near.current_health
	main._harness_lightning_tick()
	_check(near.current_health < hp1 and diag.current_health == hp0,
		"an enemy 3 steps away is zapped (%d)" % (hp1 - near.current_health))

func _t_lead_arrow_quiver() -> void:
	print("-- Lead Arrow from the Bottomless Quiver: 'Requires high ground' --")
	_reset()
	var e := _spawn(Vector2i(3, 0))
	var la := Card.create_by_id("lead_arrow")
	var hp0: int = e.current_health
	var mana0: float = stats.current_mana
	main.play_quiver_card(la, -1, e)
	_drain()
	_check(e.current_health == hp0 and stats.current_mana == mana0,
		"level with the target, the quiver shot is refused: no damage, nothing spent")
	# On a pillar the shot goes.
	var pillar_node := Node3D.new()
	main.active_pillars.append({"node": pillar_node, "position": main.player.position, "tempo_remaining": 99})
	main.play_quiver_card(la, -1, e)
	_drain()
	main.active_pillars.clear()
	pillar_node.free()
	_check(e.current_health < hp0, "from high ground it fires (%d)" % (hp0 - e.current_health))

func _t_mirror_mirror() -> void:
	print("-- Mirror Mirror: 'Duplicate a card in your hand' --")
	_reset()
	var barrier := Card.create_magic_barrier(12)
	dm.hand.append(barrier)
	var mm := Card.create_by_id("mirror_mirror")
	mm.picked_card = barrier
	_play(mm, main.player)
	var dup: Card = null
	for c in dm.hand:
		if c != barrier and c.card_id == "magic_barrier":
			dup = c
	_check(dup != null, "the copy arrives in hand")
	if dup:
		_check(dup.block == 12 and dup.description == barrier.description,
			"a 12-armor Magic Barrier copies as 12 armor (%d)" % dup.block)
		_check(dup.erase_tempo == 5 and dup.erase_tempo_remaining == 5 and barrier.erase_tempo == 0,
			"…the copy has Erase 5, the original does not")
	# An engraved card slotted into an item copies still slotted, so playable.
	_reset()
	var staff := ItemData.new()
	staff.item_name = "Test Staff"
	staff.card_slots = 1
	var fb := Card.create_by_id("fireball")
	staff._take_slot(fb, 0)  # engrave it (bypassing the label check)
	_check(fb.slotted_in_item == staff, "Fireball (Engrave) sits in the staff's slot")
	dm.hand.append(fb)
	var mm2 := Card.create_by_id("mirror_mirror")
	mm2.picked_card = fb
	_play(mm2, main.player)
	var fdup: Card = null
	for c in dm.hand:
		if c != fb and c.card_id == "fireball":
			fdup = c
	_check(fdup != null, "the Fireball copy arrives in hand")
	if fdup:
		_check(fdup.requires_engraving and fdup.slotted_in_item == staff,
			"…engraved in the same staff, so the Engrave gate lets it play")
		_check(staff.slotted_cards.size() == 1 and staff.slotted_cards[0] == fb,
			"…a separate card: the staff's slots still hold only the original")
		_check(fdup.get_on_self_bonus() == fb.get_on_self_bonus(), "…with the same slot riders")
	staff.unslot_card(0)

func _t_release_tension() -> void:
	print("-- Release Tension: 'Remove a stack of any debuff' --")
	for kind in ["polymorph", "narashimha"]:
		_reset()
		var e := _spawn(Vector2i(1, 0))
		e.apply_debuff(kind, 10)
		var field: String = kind + "_tempo"
		_check(int(e.get(field)) > 0, "%s is on the enemy" % kind)
		stats.current_health = 400
		var rt := Card.create_by_id("release_tension")
		rt.rt_chosen_debuff = kind
		_play(rt, e)
		_check(int(e.get(field)) == 0, "Release Tension removes %s" % kind)
		_check(stats.current_health > 400, "…and heals for it (%d)" % (stats.current_health - 400))
		if kind == "narashimha":
			_check(e.narashimha_heal_cap == -1, "…and its heal ceiling goes with it")

func _t_reverberate_regrowth() -> void:
	print("-- Reverberate Regrowth: 'when your armor is broken through … comes back 5 tempo later' --")
	_reset()
	dm.maintained_cards.append(Card.create_by_id("reverberate_regrowth"))
	# A break inside the Exposed cooldown still echoes.
	stats.exposed_cooldown_tempo = 10
	stats.current_armor = 10
	stats.take_damage(30)
	_check(stats.current_armor == 0, "the armor is broken (on Exposed cooldown)")
	stats.process_tempo(5)
	_check(stats.current_armor == 10, "…and still comes back 5 tempo later (%d)" % stats.current_armor)
	# Two breaks inside 5 tempo: each returns on its own timer.
	_reset()
	dm.maintained_cards.append(Card.create_by_id("reverberate_regrowth"))
	stats.current_armor = 10
	stats.take_damage(30)
	stats.process_tempo(2)
	stats.current_armor = 6
	stats.take_damage(30)
	_check(stats.current_armor == 0, "a second break 2 tempo later")
	stats.process_tempo(3)
	_check(stats.current_armor == 10, "the first break's 10 returns at its 5 tempo (%d)" % stats.current_armor)
	stats.process_tempo(2)
	_check(stats.current_armor == 16, "…and the second's 6 at its own 5 tempo (%d)" % stats.current_armor)

func _t_savage_strike() -> void:
	print("-- Savage Strike: 'Add a copy of this card to your discard pile' --")
	_reset()
	var e := _spawn(Vector2i(1, 0))
	var cap: int = Card.max_deck_copies("savage_strike_copy")
	_check(cap > 0, "the copy has a deck-building cap (%d)" % cap)
	for _i in range(cap):
		dm.discard_pile.append(Card.create_by_id("savage_strike_copy"))
	var ss := Card.create_by_id("savage_strike")
	_play(ss, e)
	var copies := 0
	for c in dm.discard_pile:
		if c.card_id == "savage_strike_copy":
			copies += 1
	_check(copies == cap + 1, "a play past the cap still adds its copy (%d copies)" % copies)

func _t_shield_of_growth() -> void:
	print("-- Shield of Growth: 'all damage done to you increases your armor count' --")
	_reset()
	bm.apply_buff(Buff.create_shield_of_growth(10, "Shield of Growth"))
	# A Bleed tick (DoT damage arrives without a buff manager).
	pdm.apply_debuff(Debuff.create(Debuff.DebuffType.BLEED, 3, 10))
	pdm.on_movement(2)
	_check(stats.current_armor == 2, "a 2-damage Bleed tick grows the armor by 2 (%d)" % stats.current_armor)
	# Damage from an item/world source (no managers passed).
	stats.current_armor = 0
	stats.take_damage(4)
	_check(stats.current_armor == 4, "a bare take_damage hit grows it too (%d)" % stats.current_armor)
	# Mind over Matter paying the whole hit in mana.
	stats.current_armor = 0
	stats.pending_mana_ward = true
	var hp_mom: int = stats.current_health
	stats.take_damage(10, pdm, bm)
	_check(stats.current_armor == 10 and stats.current_health == hp_mom,
		"a hit Mind over Matter pays in full still grows it by 10 (%d)" % stats.current_armor)
	# Without the buff nothing grows.
	bm.buffs.clear()
	stats.current_armor = 0
	stats.take_damage(4)
	_check(stats.current_armor == 0, "no Shield of Growth, no growth")

func _t_twenty_twenty() -> void:
	print("-- 20/20: '+3 range on all ranged offensive cards' on a point-aimed card --")
	_reset()
	var pb := Card.create_by_id("poison_bomb")
	_check(pb.is_ranged and pb.is_offensive() and "point" in pb.target_types,
		"Poison Bomb is a point-aimed ranged offensive card (range %d)" % pb.get_effective_range())
	var aim: Vector2i = _cell() + Vector2i(pb.get_effective_range() + 2, 0)
	# Without 20/20 the tile is out of reach.
	dm.hand.append(pb)
	main.select_card(dm.hand.find(pb))
	main.mouse_override = main.get_world_camera().unproject_position(main._ground_pos(aim))
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = main.mouse_override
	main._input(ev)
	await process_frame
	_drain()
	_check(pb in dm.hand, "without 20/20, a tile %d spaces off is out of range" % (pb.get_effective_range() + 2))
	# With 20/20 maintained, the same click lands.
	_reset()
	dm.maintained_cards.append(Card.create_by_id("twenty_twenty"))
	pb = Card.create_by_id("poison_bomb")
	dm.hand.append(pb)
	main.select_card(dm.hand.find(pb))
	main.mouse_override = main.get_world_camera().unproject_position(main._ground_pos(aim))
	ev = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = main.mouse_override
	main._input(ev)
	await process_frame
	_drain()
	_check(not (pb in dm.hand), "with 20/20, the same click plays it (+3 range)")
	main.mouse_override = Vector2(-1, -1)
