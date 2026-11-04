extends SceneTree

## The Sewer Cobra's Venom Spray (the designer's spray board, 2026-11-04;
## tools/cut_pose_boards.py "sewer_cobra" actions): Cast.png is the venom
## welling in its jaws, the mouth opening, the spray starting, spraying, the
## full spray, the spray dying and at rest — four facing rows, at its drawn
## 10 fps slowed as every enemy swing is. Its Venom Spray plays it; its Bite
## plays Attack.png (the designer's bite board).
## Run: godot --headless --path . --script tests/test_sewer_cobra_spray.gd

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
	print("=== Sewer Cobra spray test ===")
	await _test_figure()
	await _test_enemy()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)


func _feet(fig: SpriteEnemyFigure, anim: String, row: int, col: int) -> float:
	var cell: int = fig._cp_cell
	fig._sprite.texture = fig._cp_sheets[anim]
	fig._sprite.region_rect = Rect2(col * cell, row * cell, cell, cell)
	return fig._measure_ground_rows()


func _test_figure() -> void:
	print("-- The figure --")
	var fig := SpriteEnemyFigure.new()
	root.add_child(fig)
	fig.setup("sewer_croc")
	await process_frame
	_check(fig._cp_sheets.has("Cast") and fig._cp_frame_count("Cast") == 7, "a seven-frame Cast sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if not fig._cp_sheets.has("Cast"):
		fig.free()
		return
	var cell: int = fig._cp_cell
	_check(fig._cp_sheets["Cast"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
	_check(is_equal_approx(fig._cp_fps.get("Cast", 0.0), 10.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at its drawn 10 fps, slowed as every enemy swing is")
	var worst := 0.0
	for row in range(4):
		var idle_feet: float = _feet(fig, "Idle", row, 0)
		for col in range(7):
			worst = maxf(worst, absf(_feet(fig, "Cast", row, col) - idle_feet))
	_check(worst <= 3.0 * (2.0 if fig.smooth else 1.0), "its coils stay on the idle ground row (off by at most %.0f texels)" % worst)
	fig.set_facing(CharacterAnimator.Direction.EAST)
	fig.play_action("venom_spray")
	_check(fig._cp_anim == "Cast" and int(fig._sprite.region_rect.position.y / cell) == 3, "Venom Spray facing east: the spray, the right-facing row")
	fig.play_action("bite")
	_check(fig._cp_anim == "Attack" and fig._cp_frame_count("Attack") == 7, "its Bite plays the bite (sewer_cobra_bite_board.webp): seven frames")
	_check(fig._cp_sheets["Attack"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
	_check(is_equal_approx(fig._cp_fps.get("Attack", 0.0), 10.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at its drawn 10 fps, slowed as every enemy swing is")
	var bworst := 0.0
	for row in range(4):
		var bfeet: float = _feet(fig, "Idle", row, 0)
		for col in range(7):
			bworst = maxf(bworst, absf(_feet(fig, "Attack", row, col) - bfeet))
	_check(bworst <= 3.0 * (2.0 if fig.smooth else 1.0), "its coils stay on the ground row through the bite (off by at most %.0f texels)" % bworst)
	fig.free()


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
	main.player.get_stats().current_health = 500
	var cell: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	var c: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.SEWER_CROC, main._ground_pos(cell + Vector2i(2, 0)))
	c.chosen_action = {}
	await _settle(2)
	var fig: SpriteEnemyFigure = c._enemy_figure
	c._execute_action("venom_spray", main.player)
	_check(fig != null and fig._cp_anim == "Cast", "its Venom Spray plays the spray (%s)" % (fig._cp_anim if fig else "no figure"))
	c.position = main._ground_pos(cell + Vector2i(1, 0))
	await _settle(2)
	c._execute_action("bite", main.player)
	_check(fig != null and fig._cp_anim == "Attack", "its Bite plays the bite (%s)" % (fig._cp_anim if fig else "no figure"))
	main.enemy_spawner.despawn_enemy(c)
