extends SceneTree

## The Spirit Collector's Collect Soul (the designer's board, 2026-11-06;
## tools/cut_pose_boards.py "spirit_collector_collect" / "_soul"): Cast.png
## is the lantern raised and lifted, a soul drawn in and swirling into it, a
## soul sent out, four facing rows; Soul.png the skull-headed wisp, which
## flies from the victim into the lantern and then back out to the victim.
## Run: godot --headless --path . --script tests/test_spirit_collector_collect.gd

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

func _thrown(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is ThrownSprite:
			out.append(c)
	return out

func _run() -> void:
	print("=== Spirit Collector collect test ===")
	var fig := SpriteEnemyFigure.new()
	root.add_child(fig)
	fig.setup("spirit_collector")
	await process_frame
	var cell: int = fig._cp_cell
	_check(fig._cp_sheets.has("Cast") and fig._cp_frame_count("Cast") == 5, "a five-frame Cast sheet (%s)" % ("smooth" if fig.smooth else "pixel"))
	if fig._cp_sheets.has("Cast"):
		_check(fig._cp_sheets["Cast"].get_height() == 4 * cell, "in the four facing rows, the Idle sheet's cells")
		var img: Image = fig._cp_sheets["Cast"].get_image()
		if img.is_compressed():
			img.decompress()
		var drawn := true
		for row in range(4):
			for col in range(5):
				if img.get_region(Rect2i(col * cell, row * cell, cell, cell)).get_used_rect().size.y < cell * 0.4:
					drawn = false
		_check(drawn, "every frame of the four rows holds him")
	_check(ResourceLoader.exists(fig._sheet_folder + "/Soul.png"), "the flying soul beside his sheets")
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
	var sc: Enemy = main.enemy_spawner.spawn_enemy(Enemy.EnemyType.SPIRIT_COLLECTOR, main._ground_pos(pc + Vector2i(1, 0)))
	sc.chosen_action = {}
	await _settle(2)
	var before := _thrown(main).size()
	sc._execute_action("collect_soul", main.player)
	var souls := _thrown(main)
	_check(sc._enemy_figure._cp_anim == "Cast", "Collect Soul plays the lantern board (%s)" % sc._enemy_figure._cp_anim)
	_check(souls.size() - before == 2, "two souls fly: one drawn in, one sent out (%d)" % (souls.size() - before))
	if souls.size() - before == 2:
		var a: ThrownSprite = souls[souls.size() - 2]
		var b: ThrownSprite = souls[souls.size() - 1]
		var pl: Vector3 = main.player.global_position
		_check(Vector2(a._from.x - pl.x, a._from.z - pl.z).length() < 0.05, "the first starts at the victim")
		_check(Vector2(b._to.x - pl.x, b._to.z - pl.z).length() < 0.05, "the second ends at the victim")
		_check(b._delay > a._delay, "and leaves after the first is drawn in")
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
