extends SceneTree

## The Rat King's Infest (the designer's Infest board, 2026-11-04;
## tools/cut_pose_boards.py "rat_king" actions and "rat_king_infest"):
## Cast.png is the crouch, the eyes glowing purple and green, the paws
## rubbed together and the claw pointed with eyes gone white — four facing
## rows, at his drawn 10 fps slowed as every enemy swing is. Infest.png, the
## smoke-to-rats effect, plays on the victim's square (SpotEffect) from the
## paw-rubbing, its rats appearing as he points.
## Run: godot --headless --path . --script tests/test_rat_king_infest.gd

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

func _run() -> void:
	print("=== Rat King infest test ===")
	await _test_figure()
	await _test_enemy()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)


func _feet(fig: SpriteEnemyFigure, anim: String, row: int, col: int) -> float:
	var cell: int = fig._cp_cell
	fig._sprite.texture = fig._cp_sheets[anim]
	fig._sprite.region_rect = Rect2(col * cell, row * cell, cell, cell)
	return fig._measure_ground_rows()


func _spots(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is SpotEffect:
			out.append(c)
	return out


func _test_figure() -> void:
	print("-- The figure --")
	var host := Node3D.new()
	root.add_child(host)
	var holder := Node3D.new()
	host.add_child(holder)
	var fig := SpriteEnemyFigure.new()
	holder.add_child(fig)
	fig.setup("rat_king")
	await process_frame
	_check(fig._cp_sheets.has("Cast") and fig._cp_frame_count("Cast") == 9, "a nine-frame Cast sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if not fig._cp_sheets.has("Cast"):
		host.free()
		return
	var cell: int = fig._cp_cell
	_check(fig._cp_sheets["Cast"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
	_check(is_equal_approx(fig._cp_fps.get("Cast", 0.0), 10.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at his drawn 10 fps, slowed as every enemy swing is")
	var worst := 0.0
	for row in range(4):
		var idle_feet: float = _feet(fig, "Idle", row, 0)
		for col in range(9):
			worst = maxf(worst, absf(_feet(fig, "Cast", row, col) - idle_feet))
	_check(worst <= 3.0 * (2.0 if fig.smooth else 1.0), "his paws stay on the idle ground row (off by at most %.0f texels)" % worst)
	fig.set_facing(CharacterAnimator.Direction.EAST)
	fig.play_action("infest")
	_check(fig._cp_anim == "Cast" and int(fig._sprite.region_rect.position.y / cell) == 3, "Infest facing east: the cast, the right-facing row")
	var at := fig.global_position + Vector3(-4, 0, 1)
	var secs := fig.spot_effect(at, "infest")
	var fx: Array = _spots(host)
	_check(fx.size() == 1, "the effect is laid")
	if fx.is_empty():
		host.free()
		return
	var e: SpotEffect = fx[0]
	var cast_fps: float = fig._cp_fps["Cast"]
	_check(e._frames == 11, "eleven frames, ring to rats")
	_check(e.global_position.is_equal_approx(at), "on the victim's square")
	_check(is_equal_approx(e._delay, 3.0 / cast_fps), "the smoke rises as he rubs his paws (%.2f s)" % e._delay)
	_check(is_equal_approx(e._delay + 5.0 / e._fps, 6.0 / cast_fps), "and turns to rats as he points (%.2f s)" % (e._delay + 5.0 / e._fps))
	_check(is_equal_approx(secs, e.total_time()), "the clock waits for it (%.2f s)" % secs)
	_check(not e._sprite.visible, "nothing until the paws rub")
	e._process(e._delay + 0.01)
	_check(e._sprite.visible and int(e._sprite.region_rect.position.x) == 0, "then the ring")
	e._process(2.0)
	await create_timer(0.4).timeout
	_check(not is_instance_valid(e), "and it is gone when its frames are done")
	var other := SpriteEnemyFigure.new()
	holder.add_child(other)
	other.setup("zombie")
	_check(other.spot_effect(at, "infest") == 0.0, "a kind with no effect lays none")
	host.free()


func _test_enemy() -> void:
	print("-- The enemy --")
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
	var cell: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	var k: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.RAT_KING, main._ground_pos(cell + Vector2i(4, 0)))
	k.chosen_action = {}
	await _settle(2)
	var fig: SpriteEnemyFigure = k._enemy_figure
	var holds: Array = []
	k.swing_started.connect(func(_e, s): holds.append(s))
	var hand_before: int = main.player.get_deck_manager().hand.size()
	k._execute_action("infest", main.player)
	_check(fig != null and fig._cp_anim == "Cast", "his Infest plays the cast (%s)" % (fig._cp_anim if fig else "no figure"))
	var fx: Array = _spots(k.get_parent())
	_check(fx.size() == 1 and fx[0].global_position.distance_to(main.player.global_position) < 0.01, "the smoke rises on the player's square")
	_check(main.player.get_deck_manager().hand.size() > hand_before, "and the brood squirms into the hand")
	_check(holds.size() >= 2 and holds[1] > 0.0, "the clock waits for the rats (%s s)" % str(holds))
	main.enemy_spawner.despawn_enemy(k)
