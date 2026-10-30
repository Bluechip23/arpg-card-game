extends SceneTree

## The Werewolf's slash (the designer's slash boards, 2026-10-30;
## tools/cut_pose_boards.py "actions"): Attack.png is the claw — wind-up,
## rake, recovery — and Attack2.png the claw with the rake of the other arm
## after it, cut from the side board and the front/back board into the
## four Craftpix rows, in the Idle sheet's cells. A two-row (side-only)
## action sheet still plays: facing front or back the figure turns to the
## side it leans toward. A claw on a debuffed player (the second rake for
## half) plays the double; a plain claw the single.
## Run: godot --headless --path . --script tests/test_werewolf_slash.gd

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
	print("=== Werewolf slash test ===")
	_test_figure()
	await _test_enemy()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)


## Rows from the top of the cell down through the lowest opaque row of a
## frame of `anim`: where its feet stand.
func _feet(fig: SpriteEnemyFigure, anim: String, row: int, col: int) -> float:
	var cell: int = fig._cp_cell
	fig._sprite.texture = fig._cp_sheets[anim]
	fig._sprite.region_rect = Rect2(col * cell, row * cell, cell, cell)
	return fig._measure_ground_rows()


func _test_figure() -> void:
	print("-- The figure --")
	var fig := SpriteEnemyFigure.new()
	root.add_child(fig)
	fig.setup("werewolf")
	_check(fig._cp_mode and fig._cp_sheets.has("Attack") and fig._cp_sheets.has("Attack2"),
		"the werewolf has Attack and Attack2 sheets (%s)" % ("smooth" if fig.smooth else "pixel"))
	if not fig._cp_sheets.has("Attack2"):
		fig.free()
		return
	_check(fig._cp_frame_count("Attack") == 3, "Attack: wind-up, rake, recovery (%d frames)" % fig._cp_frame_count("Attack"))
	_check(fig._cp_frame_count("Attack2") == 4, "Attack2: wind-up, rake, sweep, recovery (%d frames)" % fig._cp_frame_count("Attack2"))
	var cell: int = fig._cp_cell
	for anim in ["Attack", "Attack2"]:
		var tex: Texture2D = fig._cp_sheets[anim]
		_check(tex.get_height() == 4 * cell, "%s holds the four facing rows in the Idle sheet's %d-px cells (%dx%d)" % [anim, cell, tex.get_width(), tex.get_height()])
		_check(not fig._cp_side_only(anim), "%s is a four-row sheet" % anim)
	# The feet of every slash frame stand on the Idle ground row of its facing.
	var worst := 0.0
	for row in range(4):
		var idle_feet: float = _feet(fig, "Idle", row, 0)
		for col in range(4):
			worst = maxf(worst, absf(_feet(fig, "Attack2", row, col) - idle_feet))
	_check(worst <= 3.0 * (2.0 if fig.smooth else 1.0), "the slash frames' feet sit on the idle ground row (off by at most %.0f texels)" % worst)
	# Every slash frame is drawn: the arcs reach wide, the figure stays near his idle height.
	var sheet_img: Image = fig._cp_sheets["Attack2"].get_image()
	if sheet_img.is_compressed():
		sheet_img.decompress()
	var idle_img: Image = fig._cp_sheets["Idle"].get_image()
	if idle_img.is_compressed():
		idle_img.decompress()
	var ok_size := true
	for row in range(4):
		var idle_h: int = idle_img.get_region(Rect2i(0, row * cell, cell, cell)).get_used_rect().size.y
		for col in range(4):
			var used := sheet_img.get_region(Rect2i(col * cell, row * cell, cell, cell)).get_used_rect()
			ok_size = ok_size and used.size.x > cell / 4 and used.size.y > idle_h * 0.8 and used.size.y < idle_h * 1.25
	_check(ok_size, "every slash frame is drawn, between 0.8 and 1.25 of the idle height")
	_check(fig._cp_fps.get("Attack", 0.0) == 8.0 and fig._cp_fps.get("Attack2", 0.0) == 8.0, "the slash plays at the werewolf's own 8 fps")
	# Each facing plays its own row.
	fig.set_facing(CharacterAnimator.Direction.EAST)
	fig.play_action("claw")
	_check(fig._cp_anim == "Attack" and int(fig._sprite.region_rect.position.y / cell) == 3, "Claw facing east: Attack, the right-facing row")
	fig.set_facing(CharacterAnimator.Direction.WEST)
	_check(int(fig._sprite.region_rect.position.y / cell) == 2, "turned west mid-swing: the left-facing row")
	fig.set_facing(CharacterAnimator.Direction.SOUTH)
	_check(int(fig._sprite.region_rect.position.y / cell) == 0, "facing south: the front row, slashing at the camera")
	fig.set_facing(CharacterAnimator.Direction.NORTH)
	_check(int(fig._sprite.region_rect.position.y / cell) == 1, "facing north: the back row")
	# A side-only action sheet (two rows, left then right — the slash board
	# alone gave one): facing front or back, the side the figure leans toward.
	var four: Texture2D = fig._cp_sheets["Attack"]
	var two_img := Image.create(four.get_width(), 2 * cell, false, Image.FORMAT_RGBA8)
	two_img.blit_rect(four.get_image(), Rect2i(0, 2 * cell, four.get_width(), 2 * cell), Vector2i.ZERO)
	fig._cp_sheets["Attack"] = ImageTexture.create_from_image(two_img)
	_check(fig._cp_side_only("Attack"), "a two-row sheet is side-only")
	fig._facing_x = 1.0
	fig.set_facing(CharacterAnimator.Direction.SOUTH)
	fig.play_action("claw")
	_check(int(fig._sprite.region_rect.position.y / cell) == 1, "on a side-only sheet, facing south leaning east: the right-facing row")
	fig._facing_x = -1.0
	fig.set_facing(CharacterAnimator.Direction.NORTH)
	_check(int(fig._sprite.region_rect.position.y / cell) == 0, "facing north leaning west: the left-facing row")
	fig._cp_sheets["Attack"] = four
	fig.set_facing(CharacterAnimator.Direction.NORTH)
	# The double claw: the other arm's rake after the first.
	fig.play_action("werewolf_claw_double")
	_check(fig._cp_anim == "Attack2" and fig._cp_frame == 0, "a double claw plays Attack2 from its wind-up")
	fig._cp_step(2.5 / 8.0)   # two and a half frames in at 8 fps
	_check(fig._cp_anim == "Attack2" and fig._cp_frame == 2, "two and a half frames in, the sweep of the other arm shows (frame %d)" % fig._cp_frame)
	fig._cp_step(1.0)
	_check(fig._cp_anim == "Idle" and int(fig._sprite.region_rect.position.y / cell) == 1, "the swing done, the werewolf stands idle, facing north")
	# Being hit mid-swing never cuts to Hurt (there is none) — and a plain
	# attack while a double plays restarts as the single.
	fig.play_action("werewolf_claw_double")
	fig.play_hit()
	_check(fig._cp_anim == "Attack2", "a hit mid-double-claw keeps the swing")
	fig.play_action("claw")
	_check(fig._cp_anim == "Attack", "a plain claw is the single swing")
	fig.free()


## The player's health and armour together: a claw may chip armour first.
func _hp_and_armor() -> int:
	var st = main.player.get_stats()
	return int(st.current_health) + int(st.current_armor)


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
	var w: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.WEREWOLF, main._ground_pos(cell + Vector2i(1, 0)))
	w.chosen_action = {}
	await _settle(2)
	var fig: SpriteEnemyFigure = w._enemy_figure
	_check(fig != null and fig._cp_sheets.has("Attack2"), "the werewolf enemy wears the slash sheets")
	var dm: DebuffManager = main.player.get_debuff_manager()
	dm.debuffs.clear()
	var hp_before: int = _hp_and_armor()
	w._execute_action("werewolf_claw", main.player)
	_check(fig != null and fig._cp_anim == "Attack", "a claw on a clean player: the single swing (%s)" % (fig._cp_anim if fig else "no figure"))
	var one_claw: int = hp_before - _hp_and_armor()
	_check(one_claw > 0, "the claw landed (%d)" % one_claw)
	dm.apply_debuff(Debuff.new(Debuff.DebuffType.BURN, 3))
	hp_before = _hp_and_armor()
	w._execute_action("werewolf_claw", main.player)
	_check(fig != null and fig._cp_anim == "Attack2", "a claw on a debuffed player: the double, the rake with the other arm (%s)" % (fig._cp_anim if fig else "no figure"))
	var two_claws: int = hp_before - _hp_and_armor()
	_check(two_claws > one_claw, "and it raked twice (%d vs %d)" % [two_claws, one_claw])
	main.enemy_spawner.despawn_enemy(w)
