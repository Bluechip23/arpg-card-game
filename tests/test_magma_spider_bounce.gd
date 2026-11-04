extends SceneTree

## The Magma Spider's Fire Bounce (the designer's bounce board, 2026-11-04;
## tools/cut_pose_boards.py "magma_spider" actions, `keep_ground`):
## Bounce.png is the crouch, the spring off a burst of fire, the leap, the
## landing in fire and the settle — four facing rows, every frame keeping
## its height above the ground (the airborne frames stay in the air). Its
## Fire Bounce plays it facing the leap, lands at once on the board, and the
## figure is carried across through the airborne frames (leap_from).
## Its Fire Web plays Cast.png (the designer's web board) and spits a glob
## of fire at its prey, the web's flames showing as it lands.
## Run: godot --headless --path . --script tests/test_magma_spider_bounce.gd

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
	print("=== Magma Spider bounce test ===")
	await _test_figure()
	await _test_enemy()
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)


## The lowest opaque row of a frame, from the cell's top.
func _feet(fig: SpriteEnemyFigure, anim: String, row: int, col: int) -> float:
	var cell: int = fig._cp_cell
	fig._sprite.texture = fig._cp_sheets[anim]
	fig._sprite.region_rect = Rect2(col * cell, row * cell, cell, cell)
	return fig._measure_ground_rows()


## The lowest solid row of a frame: its claw tips, for the frames with no
## fire at its feet (the crouch, the stance, the frames in the air).
func _body_bottom(img: Image, cell: int, row: int, col: int) -> int:
	var low := -1
	for y in range(cell):
		for x in range(0, cell, 2):
			if img.get_pixel(col * cell + x, row * cell + y).a > 0.8:
				low = y
				break
	return low


func _test_figure() -> void:
	print("-- The figure --")
	var fig := SpriteEnemyFigure.new()
	root.add_child(fig)
	fig.setup("magma_spider")
	await process_frame
	_check(fig._cp_sheets.has("Bounce") and fig._cp_frame_count("Bounce") == 9, "a nine-frame Bounce sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if not fig._cp_sheets.has("Bounce"):
		fig.free()
		return
	var cell: int = fig._cp_cell
	_check(fig._cp_sheets["Bounce"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
	_check(is_equal_approx(fig._cp_fps.get("Bounce", 0.0), 10.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at its drawn 10 fps, slowed as every enemy swing is")
	var img: Image = fig._cp_sheets["Bounce"].get_image()
	if img.is_compressed():
		img.decompress()
	var idle_img: Image = fig._cp_sheets["Idle"].get_image()
	if idle_img.is_compressed():
		idle_img.decompress()
	var grounded := true
	var airborne := true
	var report := ""
	for row in range(4):
		var stand := _body_bottom(idle_img, cell, row, 0)
		for col in [0, 8]:   # the crouch and the stance: on the ground (the settle's dying flare reaches below its feet)
			if absi(_body_bottom(img, cell, row, col) - stand) > int(cell * 0.06):
				grounded = false
				report += " row %d col %d: %d vs %d;" % [row, col, _body_bottom(img, cell, row, col), stand]
		for col in [3, 4]:      # high in the air, coming down: well off it
			if stand - _body_bottom(img, cell, row, col) < int(cell * 0.12):
				airborne = false
	_check(grounded, "crouched and standing again, it is on the idle ground line%s" % report)
	_check(airborne, "in the air, it stays in the air (its height kept)")
	fig.set_facing(CharacterAnimator.Direction.EAST)
	fig.play_action("fire_bounce")
	_check(fig._cp_anim == "Bounce" and int(fig._sprite.region_rect.position.y / cell) == 3, "Fire Bounce facing east: the leap, the right-facing row")
	_check(fig._fx_tween == null or not fig._fx_tween.is_valid(), "no lunge: the leap carries it")
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
	var cell: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	var s: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.MAGMA_SPIDER, main._ground_pos(cell + Vector2i(1, 0)))
	s.chosen_action = {}
	await _settle(2)
	var fig: SpriteEnemyFigure = s._enemy_figure
	var take_off: Vector3 = s.global_position
	s._execute_action("fire_bounce", main.player)
	var landing: Vector3 = s.global_position
	_check(fig != null and fig._cp_anim == "Bounce", "its Fire Bounce plays the leap (%s)" % (fig._cp_anim if fig else "no figure"))
	_check(landing.distance_to(take_off) > 1.5, "on the board it has landed away from the player")
	_check(fig.global_position.distance_to(Vector3(take_off.x, fig.global_position.y, take_off.z)) < 0.05, "but it is drawn at its take-off square")
	_check(fig._dir_name() == "right" if fig.has_method("_dir_name") else fig._cp_row(fig._cp_dir) == 3, "facing its leap (east, away from the player)")
	var fps: float = fig._cp_fps["Bounce"]
	await create_timer(2.0 / fps).timeout
	_check(fig.global_position.distance_to(Vector3(take_off.x, fig.global_position.y, take_off.z)) < 0.05, "still crouched on its take-off square")
	await create_timer(3.5 / fps).timeout
	_check(fig.global_position.distance_to(Vector3(landing.x, fig.global_position.y, landing.z)) < 0.05, "through the air and down on its landing square")
	main.enemy_spawner.despawn_enemy(s)
	await _test_web(cell)


func _thrown(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is ThrownSprite:
			out.append(c)
	return out


## Its Fire Web (the designer's web board, 2026-11-04): Cast.png — rearing,
## aiming, spitting a glob of fire — and the glob flies to its prey, the
## web's flames showing as it lands.
func _test_web(cell: Vector2i) -> void:
	print("-- Fire Web --")
	var s: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.MAGMA_SPIDER, main._ground_pos(cell + Vector2i(3, 0)))
	s.chosen_action = {}
	await _settle(2)
	var fig: SpriteEnemyFigure = s._enemy_figure
	_check(fig._cp_sheets.has("Cast") and fig._cp_frame_count("Cast") == 7, "a seven-frame Cast sheet")
	_check(fig._cp_sheets["Cast"].get_height() == 4 * fig._cp_cell, "in the four facing rows, the Idle sheet's cells")
	_check(is_equal_approx(fig._cp_fps.get("Cast", 0.0), 10.0 / SpriteEnemyFigure.DRAWN_ATTACK_SLOW), "at its drawn 10 fps, slowed as every enemy swing is")
	var holds: Array = []
	s.swing_started.connect(func(_e, sec): holds.append(sec))
	s._execute_action("fire_web", main.player)
	_check(fig._cp_anim == "Cast", "its Fire Web plays the spit (%s)" % fig._cp_anim)
	var globs := _thrown(s.get_parent())
	_check(globs.size() == 1, "a glob of fire flies at its prey")
	var release: float = 4.0 / fig._cp_fps["Cast"]
	_check(globs.size() == 1 and is_equal_approx(globs[0]._delay, release), "it leaves as the spider flicks it off (%.2f s)" % (globs[0]._delay if globs.size() else -1.0))
	_check(globs.size() == 1 and globs[0]._to.distance_to(main.player.global_position) < 0.01, "to the player")
	var web: Dictionary = main._fire_webs.back() if not main._fire_webs.is_empty() else {}
	_check(not web.is_empty() and main.grid_manager.world_to_grid(main.player.position) in web["cells"], "the web is laid around the player at once")
	_check(globs.size() == 1 and globs[0]._frames == 5, "the ball of webbing flies through its five frames (magma_spider_web_strip.webp)")
	var art: Array = web.get("nodes", [])
	_check(art.size() == 1 and art[0] is SpotEffect, "the web wears the designer's web, not the fire walls' flames")
	if art.size() == 1 and art[0] is SpotEffect:
		var sp: SpotEffect = art[0]
		_check(sp._frames == 7 and sp._hold, "the impact and the web spreading, its last frame held (%d frames)" % sp._frames)
		_check(is_equal_approx(sp._delay, globs[0].total_time()), "it starts as the ball lands (%.2f s)" % sp._delay)
		_check(sp._sprite.position.y < CameraView.SPRITE_LIFT, "laid under whoever stands on it")
	var hidden := true
	for v in web.get("nodes", []):
		if (v._sprite.visible if v is SpotEffect else v.visible):
			hidden = false
	_check(hidden, "nothing on the ground while the ball flies")
	_check(holds.size() >= 2 and holds.max() > release, "the clock waits for the glob (%s s)" % str(holds))
	await create_timer(holds.max() + 0.2).timeout
	var shown := true
	for v in web.get("nodes", []):
		if is_instance_valid(v) and not (v._sprite.visible if v is SpotEffect else v.visible):
			shown = false
	_check(shown, "and the web spreads as it lands")
	await create_timer(1.0).timeout
	_check(art.size() == 1 and is_instance_valid(art[0]) and art[0]._sprite.visible, "the web stays on the ground while it lasts")
	s.die()
	main.tempo_manager.add_tempo(1)
	await _settle(2)
	_check(art.is_empty() or not is_instance_valid(art[0]) or art[0].is_queued_for_deletion(), "and goes with the spider")
