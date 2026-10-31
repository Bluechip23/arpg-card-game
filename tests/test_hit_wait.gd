extends SceneTree

## The hit wait (designer, 2026-10-31): a hero's drawn attack lands its blow
## partway through (SpriteFigure's "hit" frame), so the damage waits for it
## and the tick clock is held meanwhile. Covers the queued auto attack, the
## Attack card and the instant (Steady) swing; with the swing hold off in
## Settings, the hit lands at once as it always did.
## Run: godot --headless --path . --script tests/test_hit_wait.gd

var failures := 0
var main = null

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout

func _run() -> void:
	print("=== Hit wait test ===")
	_test_figures()
	await _test_battle()
	TempoManager.preferred_swing_hold = -1
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)


## Each hero's attack lands on its hit frame: (frame - 1) x seconds a frame.
func _test_figures() -> void:
	print("-- The figures --")
	var D := CharacterAnimator.Direction
	var want := {"Brad": 0.36, "Jeremy": 0.36, "Stephen": 0.36, "Ryan": 0.27, "Cory": 0.22}
	for hero in want:
		var f := SpriteFigure.new()
		get_root().add_child(f)
		f.setup(hero)
		var d: float = f.hit_delay("basic_attack", D.EAST)
		_check(absf(d - want[hero]) < 0.001, "%s's blow lands %.2f s into his attack" % [hero, d])
		_check(f.hit_delay("basic_block", D.EAST) == 0.0, "%s's block marks no blow" % hero)
		f.free()
	var brad := SpriteFigure.new()
	get_root().add_child(brad)
	brad.setup("Brad")
	_check(absf(brad.hit_delay("attack_slash", D.EAST) - 0.36) < 0.001, "a card attack's swing is his drawn smash, and waits for its blow")
	_check(brad.hit_delay("heavy_swing", D.EAST) == 0.0, "an action with nothing drawn waits for nothing")
	brad.free()


func _test_battle() -> void:
	print("-- In battle --")
	TempoManager.preferred_swing_hold = 1
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
		return
	var tm = main.tempo_manager
	main.player.get_stats().current_health = 500
	var cell: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	var w: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WOLF, main._ground_pos(cell + Vector2i(1, 0)))
	await _settle(2)
	w.max_health = 999
	w.current_health = 999
	w.current_armor = 0
	var wait: float = main._hit_wait("basic_attack", w)
	_check(absf(wait - 0.36) < 0.001, "Brad's smash waits %.2f s for its blow" % wait)

	# The queued auto attack: swings now, lands on the hit frame.
	var card := Card.create_by_id("slash")
	main._pending_resolve_queue.append({"card": card, "target": w, "owner_index": 0,
		"data": {"is_basic_attack": true, "basic_attack_damage": 7, "basic_attack_crit": false, "basic_attack_proc": false}})
	main._on_card_tick_resolved(card)
	_check(w.current_health == 999, "the auto attack has not landed as the swing starts")
	_check(tm.is_holding_for_swing(), "the tick clock waits for the blow")
	_check(main.player._figure._action_sprite.visible, "Brad is mid-smash")
	await _wait(wait + 0.1)
	_check(w.current_health == 992, "the blow lands on the hit frame (%d)" % w.current_health)

	# The Attack card.
	var hp := w.current_health
	var slash := Card.create_by_id("slash")
	main._pending_resolve_queue.append({"card": slash, "target": w, "owner_index": 0, "data": {}})
	main._on_card_tick_resolved(slash)
	_check(w.current_health == hp, "the Attack card has not landed as the swing starts")
	await _wait(wait + 0.1)
	_check(w.current_health < hp, "the Attack card lands on the hit frame (%d -> %d)" % [hp, w.current_health])

	# A target slain mid-swing: the blow finds no one and the card goes home.
	var w2: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WOLF, main._ground_pos(cell + Vector2i(0, 1)))
	await _settle(2)
	var late := Card.create_by_id("slash")
	main._pending_resolve_queue.append({"card": late, "target": w2, "owner_index": 0,
		"data": {"is_basic_attack": true, "basic_attack_damage": 7, "basic_attack_crit": false, "basic_attack_proc": false}})
	main._on_card_tick_resolved(late)
	w2.is_dead = true
	await _wait(wait + 0.1)
	_check(not main._pending_resolve_queue.any(func(e): return e["card"] == late), "a swing at a fallen target is dropped")

	# Off: the blow lands at once.
	TempoManager.preferred_swing_hold = 0
	await _wait(0.6)
	hp = w.current_health
	var now := Card.create_by_id("slash")
	main._pending_resolve_queue.append({"card": now, "target": w, "owner_index": 0,
		"data": {"is_basic_attack": true, "basic_attack_damage": 7, "basic_attack_crit": false, "basic_attack_proc": false}})
	main._on_card_tick_resolved(now)
	_check(w.current_health == hp - 7, "with the swing hold off the blow lands at once (%d -> %d)" % [hp, w.current_health])
	main.enemy_spawner.despawn_enemy(w)
