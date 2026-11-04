extends SceneTree

## The Battle Turtle's armor animation (the designer's armor board,
## 2026-11-03; tools/cut_pose_boards.py "actions"): Armor.png — the turtle
## crouches, digs a brick out of the dirt, tosses it over its head and it
## lands on it — in the four facing rows and the Idle sheet's cells, its
## feet on the Idle ground row. It plays every time the turtle GIVES ITSELF
## armor (its own regain), and not when it only gains armor from another
## turtle's passive, nor when it is full and gives itself nothing. A hit
## doesn't cut it short.
## Run: godot --headless --path . --script tests/test_turtle_armor_anim.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _settle(n := 6) -> void:
	for _i in range(n):
		await process_frame

func _summons_of(main, kind: String) -> Array:
	return main._skeletons.filter(func(s): return is_instance_valid(s) and not s.is_dead and s.kind == kind)

func _run() -> void:
	print("=== Battle Turtle armor animation ===")
	_test_figure()
	await _test_turtles()
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
	fig.setup("battle_turtle")
	_check(fig._cp_mode and fig._cp_sheets.has("Armor"), "the Battle Turtle has an Armor sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if not fig._cp_sheets.has("Armor"):
		fig.free()
		return
	var cell: int = fig._cp_cell
	var tex: Texture2D = fig._cp_sheets["Armor"]
	_check(fig._cp_frame_count("Armor") == 8, "Armor: crouch, reach, dig, pull, lift, toss, high, land (%d frames)" % fig._cp_frame_count("Armor"))
	_check(tex.get_height() == 4 * cell, "Armor holds the four facing rows in the Idle sheet's %d-px cells (%dx%d)" % [cell, tex.get_width(), tex.get_height()])
	var worst := 0.0
	for row in range(4):
		var idle_feet: float = _feet(fig, "Idle", row, 0)
		for col in range(8):
			worst = maxf(worst, absf(_feet(fig, "Armor", row, col) - idle_feet))
	_check(worst <= 3.0 * (2.0 if fig.smooth else 1.0), "every armor frame's feet sit on the idle ground row (off by at most %.0f texels)" % worst)
	fig._cp_play("Idle", true)
	_check(fig.play_armor() and fig._cp_anim == "Armor", "play_armor plays the Armor sheet")
	fig.play_hit()
	_check(fig._cp_anim == "Armor", "a hit doesn't cut it short")
	fig.set_walking(true)
	_check(fig._cp_anim == "Armor", "nor does a step")
	fig._cp_step(1.2)
	_check(fig._cp_anim == "Walk", "it plays once (1 s at 8 fps), then hands back to the walk")
	fig.free()
	var other := SpriteEnemyFigure.new()
	root.add_child(other)
	other.setup("shadow_hound")
	_check(not other.play_armor(), "a figure with no Armor sheet plays nothing")
	other.free()


func _test_turtles() -> void:
	print("-- The turtles --")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	await _settle()
	if main.olorin and main.olorin.is_busy():
		main.olorin._close()
	var stats: PlayerStats = main.player.get_stats()
	var gm = main.grid_manager
	var here: Vector2i = gm.world_to_grid(main.player.position)
	stats.base_intelligence = 40
	main._summon_from_card("turtle_power", gm.grid_to_world(here + Vector2i(0, -3)))
	var turtles := _summons_of(main, "battle_turtle")
	_check(turtles.size() == 3, "Turtle Power raises 3 Battle Turtles")
	if turtles.size() != 3:
		main.queue_free()
		return
	var t = turtles[0]
	var ally = turtles[1]
	for s in turtles:
		s._figure._cp_play("Idle", true)
	# Full: it gives itself nothing, so it doesn't dig.
	main._regain_turtle_armor(t, 5)
	_check(t._figure._cp_anim == "Idle", "a full turtle gives itself nothing: no animation")
	# Down some armor: its regain gives it armor — the brick is dug up.
	t.take_damage(10)
	ally.take_damage(10)
	var ally_before: int = ally.unerring_armor
	main._regain_turtle_armor(t, 5)
	_check(t._figure._cp_anim == "Armor", "the turtle that gives itself armor plays the armor board")
	_check(ally.unerring_armor > ally_before and ally._figure._cp_anim == "Idle",
		"the ally that only gains armor from its passive does not")
	_check(turtles[2]._figure._cp_anim == "Idle", "nor does the full one beside them")
	# Only on the regain tick: tempo short of the interval gives nothing.
	t._figure._cp_play("Idle", true)
	main._regain_turtle_armor(t, 2)
	_check(t._figure._cp_anim == "Idle", "between regains it doesn't dig")
	main.queue_free()
	await _settle(2)
