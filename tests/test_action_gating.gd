extends SceneTree

## The designer's action rulings, checked in a booted main.tscn (the dojo):
##  - Stun stops everything: the attack button, the auto attack, Block,
##    Sidestep / Flash Cut, Quick hands, gauntlet skills, Brain draw / peek,
##    gear swaps, Quiver and Manifest plays, card plays and movement are all
##    refused and spend nothing — and Wait still passes time;
##  - Blind makes the auto attack and Flash Cut miss, not only Attack cards;
##  - Weighted taxes card plays only: nothing on the auto attack or Block, but
##    a Quiver play pays the +2 and burns a stack.
## Run: godot --headless --path . --script tests/test_action_gating.gd

var failures: int = 0
var main = null

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	await _boot()
	if main == null:
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	_test_stun()
	_test_blind()
	_test_weighted()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)

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
	var stats = main.player.get_stats()
	stats.max_health = 500
	stats.current_health = 500
	stats.current_armor = 0

func _dummy() -> Enemy:
	var enemies: Array = main.enemy_spawner.get_living_enemies()
	return enemies[0] if enemies.size() > 0 else null

## Stand on the tile beside the dummy so every melee reach check passes.
func _stand_beside(dummy: Enemy) -> void:
	var cell: Vector2i = main.grid_manager.world_to_grid(dummy.position) + Vector2i(1, 0)
	main.player.position = main._ground_pos(cell)
	main.player.target_position = main.player.position
	if "is_moving" in main.player:
		main.player.is_moving = false

func _refill(stats) -> void:
	stats.max_mana = maxi(stats.max_mana, 200)
	stats.current_mana = stats.max_mana
	stats.current_flash_points = 50
	stats.current_brain_points = 100
	stats.current_armor = 0

func _toughen(dummy: Enemy) -> void:
	dummy.max_health = 100000
	dummy.current_health = 100000
	if "current_armor" in dummy:
		dummy.current_armor = 0

## Drop a queued auto attack without letting it tick.
func _drop_queued_basic(card: Card) -> void:
	main.tempo_manager.cancel_card_ticks(card)
	for i in range(main._pending_resolve_queue.size() - 1, -1, -1):
		if main._pending_resolve_queue[i]["card"] == card:
			main._pending_resolve_queue.remove_at(i)

func _test_stun() -> void:
	print("-- Stun: every action refused, nothing spent; Wait still works --")
	var stats: PlayerStats = main.player.get_stats()
	var dbm: DebuffManager = main.player.get_debuff_manager()
	var inv = main.player.get_inventory()
	var tm = main.tempo_manager
	var dummy := _dummy()
	dbm.clear_all_debuffs()
	_check(dbm.can_act(), "unstunned: can_act")
	_refill(stats)
	if dummy:
		_stand_beside(dummy)
		_toughen(dummy)

	# Kit for the gated actions: a gauntlet with an active skill (Guard), a
	# shield for Block, and a Manifest token.
	var gloves: ItemData = ItemData.create_chain_gloves()
	inv.equip_item(gloves, 0)
	var shield: ItemData = ItemData.create_wooden_shield()
	if not inv.has_shield_equipped():
		for s in range(4):
			if inv.equip_item(shield, s):
				break
	main.overflow_manager.manifest_zone.append({
		"card": Card.create_slash(), "effect": null, "manifest_name": "Mushroom",
		"manifest_id": "use_mushroom", "manifest_description": "", "manifest_value": 5,
		"mana_cost": 0, "tempo_cost": 2,
	})

	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.STUN, 0, 15))
	_check(not dbm.can_act(), "stunned: can_act is false")
	_check(not dbm.can_play_cards() and not dbm.can_move(), "stunned: card plays and movement were already refused")

	var t0: int = tm.global_tempo
	var mana0: int = stats.current_mana
	var flash0: int = stats.current_flash_points
	var brain0: int = stats.current_brain_points
	var hand0: int = main.deck_manager.hand.size()
	var queue0: int = main._pending_resolve_queue.size()
	var hp0: int = dummy.current_health if dummy else 0

	main._on_attack_pressed()
	_check(not main._basic_attack_pending, "the attack button does not arm")
	if dummy:
		main._execute_basic_attack(dummy)
		main._execute_basic_attack(dummy, true)
		_check(main._pending_resolve_queue.size() == queue0 and dummy.current_health == hp0,
			"the auto attack (and a passive's free swing) does not happen")

	main._on_block_pressed()
	_check(stats.current_armor == 0, "Block gives no armor (shield %s)" % ("on" if inv.has_shield_equipped() else "missing"))

	stats.keystone_flash_strike = false
	main._on_flash_block_pressed()
	_check(stats.current_flash_points == flash0 and stats.current_armor == 0, "Sidestep spends no flash and gives no armor")
	stats.keystone_flash_strike = true
	main._on_flash_block_pressed()
	_check(stats.current_flash_points == flash0 and (dummy == null or dummy.current_health == hp0),
		"Flash Cut spends no flash and deals nothing")
	stats.keystone_flash_strike = false

	main._on_flash_proc_pressed()
	_check(stats.current_flash_points == flash0, "Quick hands spends no flash")

	var peek0: int = main.deck_manager.brain_peek_depth
	main._on_brain_draw_pressed()
	main._on_brain_peek_pressed()
	_check(stats.current_brain_points == brain0 and main.deck_manager.hand.size() == hand0 \
			and main.deck_manager.brain_peek_depth == peek0, "Brain draw and peek spend nothing and draw/reveal nothing")

	main._on_gauntlet_skill_activated(gloves)
	_check(not gloves.is_on_cooldown() and stats.current_armor == 0 and main._pending_gauntlet_skill == null,
		"the gauntlet skill does not fire or start its cooldown")
	main._fire_gauntlet_skill(gloves, null)
	_check(not gloves.is_on_cooldown() and stats.current_armor == 0, "an armed gauntlet skill does not fire either")

	main.character_panel._handle_item_drop_on_storage({"source": "equipped", "item": gloves,
		"item_type": ItemData.ItemType.GAUNTLETS, "slot_index": 0})
	_check(inv.equipped_gauntlets[0] == gloves, "a gear swap (unequip by drag) is refused")
	main.character_panel._on_build_pressed(1)
	_check(inv.active_build == 0 and inv.equipped_gauntlets[0] == gloves, "a build switch is refused")

	var q_card := Card.create_slash()
	main.play_quiver_card(q_card, -1, dummy if dummy else main.player)
	_check(stats.current_mana == mana0, "a Quiver play spends no mana")
	var zone0: int = main.overflow_manager.manifest_zone.size()
	main._on_manifest_card_clicked(zone0 - 1)
	_check(main.overflow_manager.manifest_zone.size() == zone0, "a Manifest token is not spent")

	var here: Vector3 = main.player.position
	var moved: bool = main.player.move_to_grid(here + Vector3(0, 0, 2), 2)
	_check(not moved, "movement is refused")

	_check(tm.global_tempo == t0 and stats.current_mana == mana0 and stats.current_flash_points == flash0 \
			and stats.current_brain_points == brain0, "nothing above spent tempo, mana, flash or brain")

	var stun = dbm.get_debuff(Debuff.DebuffType.STUN)
	var left0: int = stun.duration
	main._on_wait_pressed()
	_check(tm.global_tempo == t0 + 1, "Wait still passes 1 tempo while stunned")
	_check(stun.duration == left0 - 1, "and the stun ticks down with it (%d -> %d)" % [left0, stun.duration])

	dbm.remove_debuff(Debuff.DebuffType.STUN)
	main._on_attack_pressed()
	_check(main._basic_attack_pending, "unstunned: the attack button arms again")
	main._set_basic_attack_pending(false)
	main._on_flash_block_pressed()
	_check(stats.current_flash_points < flash0, "unstunned: Sidestep spends flash again")

	# Leave the dojo clean for the next block.
	main.overflow_manager.manifest_zone.pop_back()
	dbm.clear_all_debuffs()
	_refill(stats)

func _test_blind() -> void:
	print("-- Blind: the auto attack and Flash Cut miss --")
	var stats: PlayerStats = main.player.get_stats()
	var dbm: DebuffManager = main.player.get_debuff_manager()
	var dummy := _dummy()
	if dummy == null:
		print("  (no dummy in the dojo — Blind sample skipped)")
		return
	dbm.clear_all_debuffs()
	_stand_beside(dummy)
	_toughen(dummy)
	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.BLIND, 1))

	# Queued swings: commit, then resolve the queue entry directly.
	var misses := 0
	var hits := 0
	var tempo_ok := true
	for _i in range(50):
		_toughen(dummy)
		main.deck_manager.next_attack_half_tempo = false
		var q0: int = main._pending_resolve_queue.size()
		main._execute_basic_attack(dummy)
		if main._pending_resolve_queue.size() != q0 + 1:
			tempo_ok = false
			continue
		var card: Card = main._pending_resolve_queue.back()["card"]
		if card.tempo_cost != main._basic_attack_tempo():
			tempo_ok = false
		main.tempo_manager.cancel_card_ticks(card)
		main._resolve_queued_card(card)
		if dummy.current_health < 100000:
			hits += 1
		else:
			misses += 1
		dbm.get_debuff(Debuff.DebuffType.BLIND).stack_clock = 0  # keep it blind for the whole sample
	_check(tempo_ok, "every blinded swing still committed its full tempo")
	_check(misses >= 20 and hits >= 1, "blinded auto attack: %d misses / %d hits of 50" % [misses, hits])

	# Immediate swings (a passive's free swing) roll too.
	misses = 0
	hits = 0
	for _i in range(50):
		_toughen(dummy)
		main._execute_basic_attack(dummy, true)
		if dummy.current_health < 100000:
			hits += 1
		else:
			misses += 1
		dbm.get_debuff(Debuff.DebuffType.BLIND).stack_clock = 0
	_check(misses >= 20 and hits >= 1, "blinded free swing: %d misses / %d hits of 50" % [misses, hits])

	# Flash Cut: the flash is spent on a miss too.
	stats.keystone_flash_strike = true
	misses = 0
	hits = 0
	var spent_ok := true
	for _i in range(50):
		_toughen(dummy)
		stats.current_flash_points = 50
		main._on_flash_block_pressed()
		if stats.current_flash_points != 50 - stats.get_flash_block_cost():
			spent_ok = false
		if dummy.current_health < 100000:
			hits += 1
		else:
			misses += 1
		dbm.get_debuff(Debuff.DebuffType.BLIND).stack_clock = 0
	_check(spent_ok, "every blinded Flash Cut still spent its flash")
	_check(misses >= 20 and hits >= 1, "blinded Flash Cut: %d misses / %d hits of 50" % [misses, hits])

	dbm.remove_debuff(Debuff.DebuffType.BLIND)
	_toughen(dummy)
	main._execute_basic_attack(dummy, true)
	_check(dummy.current_health < 100000, "unblinded, the auto attack lands")
	_toughen(dummy)
	stats.current_flash_points = 50
	main._on_flash_block_pressed()
	_check(dummy.current_health < 100000, "unblinded, Flash Cut lands")
	stats.keystone_flash_strike = false
	dbm.clear_all_debuffs()
	_refill(stats)

func _test_weighted() -> void:
	print("-- Weighted: card plays only --")
	var stats: PlayerStats = main.player.get_stats()
	var dbm: DebuffManager = main.player.get_debuff_manager()
	var inv = main.player.get_inventory()
	var tm = main.tempo_manager
	var dummy := _dummy()
	dbm.clear_all_debuffs()
	_refill(stats)
	dbm.apply_debuff(Debuff.create(Debuff.DebuffType.WEIGHTED, 2))
	var w = dbm.get_debuff(Debuff.DebuffType.WEIGHTED)
	_check(w != null and w.value == 2, "Weighted 2 applied")

	if dummy:
		_stand_beside(dummy)
		_toughen(dummy)
		main.deck_manager.next_attack_half_tempo = false
		var q0: int = main._pending_resolve_queue.size()
		main._execute_basic_attack(dummy)
		if main._pending_resolve_queue.size() == q0 + 1:
			var card: Card = main._pending_resolve_queue.back()["card"]
			_check(card.tempo_cost == main._basic_attack_tempo(),
				"the auto attack costs its own %d tempo, no Weighted +2 (got %d)" % [main._basic_attack_tempo(), card.tempo_cost])
			_drop_queued_basic(card)
		else:
			_check(false, "the auto attack queued")
		_check(dbm.get_debuff(Debuff.DebuffType.WEIGHTED).value == 2, "the auto attack burns no stack")

	if inv.has_shield_equipped():
		var t0: int = tm.global_tempo
		main._on_block_pressed()
		_check(tm.global_tempo - t0 == 5, "Block costs its 5 tempo, no Weighted +2 (got %d)" % (tm.global_tempo - t0))
		_check(dbm.get_debuff(Debuff.DebuffType.WEIGHTED).value == 2, "Block burns no stack")
	else:
		_check(false, "a shield is equipped for the Block check")

	var q_card := Card.create_slash()
	var burden: int = q_card.get_burden_tempo_cost()
	var t1: int = tm.global_tempo
	main.play_quiver_card(q_card, -1, dummy if dummy else main.player)
	_check(tm.global_tempo - t1 == burden + Debuff.WEIGHTED_TEMPO,
		"a Quiver play pays its %d tempo + 2 for Weighted (got %d)" % [burden, tm.global_tempo - t1])
	var w_after = dbm.get_debuff(Debuff.DebuffType.WEIGHTED)
	_check(w_after != null and w_after.value == 1, "and burns a Weighted stack (2 -> %s)" % (str(w_after.value) if w_after else "gone"))

	# The last stack: still taxed, then gone.
	var q2 := Card.create_slash()
	var t2: int = tm.global_tempo
	stats.current_mana = stats.max_mana
	main.play_quiver_card(q2, -1, dummy if dummy else main.player)
	_check(tm.global_tempo - t2 == q2.get_burden_tempo_cost() + Debuff.WEIGHTED_TEMPO,
		"the play that burns the last stack still pays the +2")
	_check(not dbm.has_debuff(Debuff.DebuffType.WEIGHTED), "and Weighted is gone after its last stack")
	dbm.clear_all_debuffs()
