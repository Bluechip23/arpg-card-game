extends SceneTree

## The Treasure Bunny's escape (the designer's vanish smoke, 2026-11-04;
## tools/cut_pose_boards.py "treasure_bunny_vanish"): when it Vanishes a puff
## of smoke rises where it stood and billows into a cloud with a sad frown
## (Smoke.png, SpotEffect); the bunny is gone once the cloud covers it, with
## no loot and no XP, and the smoke plays out after it.
## Run: godot --headless --path . --script tests/test_treasure_bunny_vanish.gd

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

func _spots(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is SpotEffect:
			out.append(c)
	return out

func _run() -> void:
	print("=== Treasure Bunny vanish test ===")
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
	var cell: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	var b: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.TREASURE_BUNNY, main._ground_pos(cell + Vector2i(3, 0)))
	b.chosen_action = {}
	await _settle(2)
	var fig: SpriteEnemyFigure = b._enemy_figure
	var at: Vector3 = b.global_position
	var holds: Array = []
	b.swing_started.connect(func(_e, s): holds.append(s))
	b._execute_action("vanish", main.player)
	_check(fig._fx_tween == null or not fig._fx_tween.is_valid(), "it does not lunge as it goes")
	var fx := _spots(main)
	_check(fx.size() == 1, "a puff of smoke rises")
	if fx.size() == 1:
		var sm: SpotEffect = fx[0]
		_check(sm._frames == 8, "eight frames of smoke (%d)" % sm._frames)
		_check(sm.global_position.distance_to(at) < 0.01, "where the bunny stood")
		_check(holds.size() == 1 and is_equal_approx(holds[0], sm.total_time()), "the clock waits for the smoke (%.2f s)" % (holds[0] if holds.size() else -1.0))
	_check(is_instance_valid(b), "the bunny is still there as the puff starts")
	await create_timer(0.35).timeout
	_check(not is_instance_valid(b) or b.is_queued_for_deletion(), "and gone once the cloud covers it")
	_check(fx.size() == 1 and is_instance_valid(fx[0]), "the smoke plays on after it")
	await create_timer(1.0).timeout
	_check(fx.size() == 1 and not is_instance_valid(fx[0]), "then drifts away")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
