extends SceneTree

## The Infected Hunter's Hook (the designer's hook board, 2026-11-06;
## tools/cut_pose_boards.py "infected_hunter_hook" / "_chain" / "_hookhead"):
## Throw.png is the hook swung back, wound up, thrown and held while the
## chain runs out, then pulled back and settled, four facing rows (the west
## row the east's mirror: the board's west row throws the wrong way). The
## chain is two links repeated out to its prey with the hook at the end; the
## prey is reeled in when the hook gets to them, not before.
## Run: godot --headless --path . --script tests/test_infected_hunter_hook.gd

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

func _chains(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is ChainHook:
			out.append(c)
	return out

func _run() -> void:
	print("=== Infected Hunter hook test ===")
	var fig := SpriteEnemyFigure.new()
	root.add_child(fig)
	fig.setup("infected_hunter")
	await process_frame
	var cell: int = fig._cp_cell
	_check(fig._cp_sheets.has("Throw") and fig._cp_frame_count("Throw") == 13, "a thirteen-frame Throw sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if fig._cp_sheets.has("Throw"):
		_check(fig._cp_sheets["Throw"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
		var img: Image = fig._cp_sheets["Throw"].get_image()
		if img.is_compressed():
			img.decompress()
		var drawn := true
		for row in range(4):
			for col in range(13):
				if img.get_region(Rect2i(col * cell, row * cell, cell, cell)).get_used_rect().size.y < cell * 0.4:
					drawn = false
		_check(drawn, "every frame of the four rows holds him")
		# The throw (col 3) on the left row is the right row's, mirrored.
		var lt: Image = img.get_region(Rect2i(3 * cell, 2 * cell, cell, cell))
		var rt: Image = img.get_region(Rect2i(3 * cell, 3 * cell, cell, cell))
		rt.flip_x()
		var same := 0
		var lit := 0
		for y in range(0, cell, 3):
			for x in range(0, cell, 3):
				var a := lt.get_pixel(x, y).a > 0.5
				var b := rt.get_pixel(x, y).a > 0.5
				if a or b:
					lit += 1
					if a == b:
						same += 1
		_check(lit > 0 and float(same) / float(lit) > 0.85, "the west throw is the east's, mirrored (%d of %d alike)" % [same, lit])
	# Its Cleave (the designer's cleave board, 2026-11-06): Attack.png.
	_check(fig._cp_sheets.has("Attack") and fig._cp_frame_count("Attack") == 6, "a six-frame Cleave sheet")
	if fig._cp_sheets.has("Attack"):
		var cimg: Image = fig._cp_sheets["Attack"].get_image()
		if cimg.is_compressed():
			cimg.decompress()
		var cdrawn := true
		for row in range(4):
			for col in range(6):
				if cimg.get_region(Rect2i(col * cell, row * cell, cell, cell)).get_used_rect().size.y < cell * 0.4:
					cdrawn = false
		_check(cdrawn, "every cleave frame of the four rows holds him")
		fig.set_facing(CharacterAnimator.Direction.WEST)
		fig.play_action("cleave")
		_check(fig._cp_anim == "Attack" and int(fig._sprite.region_rect.position.y / cell) == fig._cp_row(CharacterAnimator.Direction.WEST), "its Cleave plays the cleave board")
	for nm in ["Chain", "Hook"]:
		_check(ResourceLoader.exists(fig._sheet_folder + "/%s.png" % nm), "%s.png beside his sheets" % nm)
	fig.free()

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
	var pc: Vector2i = main.grid_manager.world_to_grid(main.player.position)
	var h: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.INFECTED_HUNTER, main._ground_pos(pc + Vector2i(5, 0)))
	h.chosen_action = {}
	await _settle(2)
	var start_pos: Vector3 = main.player.position
	h._execute_action("hook", main.player)
	var f: SpriteEnemyFigure = h._enemy_figure
	_check(f._cp_anim == "Throw", "its Hook plays the throw board (%s)" % f._cp_anim)
	var chains := _chains(main)
	_check(chains.size() == 1, "a chain is thrown")
	if chains.is_empty():
		print("=== %d failure(s) ===" % failures)
		quit(1)
		return
	var c: ChainHook = chains[0]
	_check(main.player.target_position.distance_to(start_pos) < 0.05, "the prey is not pulled before the hook gets to them")
	var fps: float = f._cp_fps["Throw"]
	await create_timer(3.0 / fps + 0.15).timeout
	var n := 0
	for l in c._links:
		if l.visible:
			n += 1
	_check(n >= 6, "the links are repeated out toward the prey (%d shown)" % n)
	await create_timer(1.2).timeout
	var hc: Vector2i = main.grid_manager.world_to_grid(h.position)
	var now: Vector2i = main.grid_manager.world_to_grid(main.player.target_position)
	_check(now == hc + Vector2i(-1, 0), "the hook bit and reels them in beside him (%s, he is at %s)" % [now, hc])
	await create_timer(1.5).timeout
	_check(not is_instance_valid(c), "the chain is home and gone")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
