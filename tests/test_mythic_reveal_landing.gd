extends SceneTree

## Looting a mythic: the ceremony's present lands on an open tile right beside
## the player — never a random spot further out — and skips walls and enemies;
## the glow still bursts its full radius.
## Run: godot --headless --path . --script tests/test_mythic_reveal_landing.gd

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

func _settle(frames: int = 6) -> void:
	for _i in range(frames):
		await process_frame

func _run() -> void:
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
	if main.player == null:
		_check(false, "the dojo is up")
		_finish()
		return

	var gm = main.grid_manager
	var dm = main.dungeon_manager
	var here: Vector2i = gm.world_to_grid(main.player.position)
	var item: ItemData = ItemData.get_items_of_rarity(ItemData.Rarity.MYTHIC)[0]

	# Several reveals in a row: every present lands on the same adjacent tile.
	var spots := {}
	for i in range(5):
		main._start_mythic_reveal(item, main.player)
		var reveal: MythicReveal = main._mythic_reveals.back()
		var cell: Vector2i = gm.world_to_grid(reveal.click_position())
		spots[cell] = true
		_check(is_equal_approx(reveal.glow_radius, 3.0), "reveal %d: the glow still bursts its full 3 tiles" % [i + 1])
		_check(maxi(absi(cell.x - here.x), absi(cell.y - here.y)) == 1,
			"reveal %d: the present is one tile from the player (%s vs %s)" % [i + 1, cell, here])
		_check(dm.is_floor(cell) and not dm.is_obstacle(cell), "reveal %d: it lands on open floor" % [i + 1])
		reveal.queue_free()
	_check(spots.size() == 1, "it lands in one spot every time, not a random one")

	# A wall or an enemy on the first choice moves it to the next open side.
	var first: Vector2i = spots.keys()[0]
	var enemy = main.enemy_spawner.get_living_enemies()[0] if not main.enemy_spawner.get_living_enemies().is_empty() else null
	if enemy:
		var old_pos: Vector3 = enemy.position
		enemy.position = gm.grid_to_world(first)
		var off: Vector3 = main._mythic_landing_offset(main.player)
		var cell2: Vector2i = gm.world_to_grid(main.player.position + off)
		_check(cell2 != first and maxi(absi(cell2.x - here.x), absi(cell2.y - here.y)) == 1,
			"an enemy on that tile sends the present to another adjacent tile (%s)" % cell2)
		enemy.position = old_pos
	_finish()

func _finish() -> void:
	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
