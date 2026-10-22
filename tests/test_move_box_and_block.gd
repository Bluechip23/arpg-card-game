extends SceneTree

## The Block button is always on the bar: greyed out with "Equip a shield to
## activate button" until a shield is worn. The move box shows two numbers:
## the spaces (brown, on top) and the tempo the walk costs (yellow, below),
## and that tempo follows flash movement, Slowed and free (shift) tiles.
## Run: godot --headless --path . --script tests/test_move_box_and_block.gd

var failures := 0

func _check(ok: bool, msg: String) -> void:
	if ok:
		print("  PASS: %s" % msg)
	else:
		failures += 1
		print("  FAIL: %s" % msg)

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== Move box and block button test ===")
	var main = load("res://scenes/core/main.tscn").instantiate()
	main.set("starting_character", CharacterData.create_brad())
	main.set("current_interior_id", "dojo")
	get_root().add_child(main)
	for _i in range(8):
		await process_frame
	while main.olorin and main.olorin.is_busy():
		main.olorin._close()
		await process_frame
	var inv = main.player.get_inventory()
	var stats = main.player.get_stats()

	# --- Block button ---
	for i in range(inv.equipped_weapons.size()):
		var it = inv.equipped_weapons[i]
		if it and it == inv.get_equipped_shield():
			inv.equipped_weapons[i] = null
	main._update_block_button_visibility()
	var b: Button = main._block_button
	_check(b.visible and b.disabled, "no shield: the Block button is shown, greyed out")
	_check(b.tooltip_text == "Equip a shield to activate button", "and its tooltip says to equip a shield (%s)" % b.tooltip_text)
	var tempo_before: int = main.tempo_manager.global_tempo
	b.pressed.emit()
	_check(main.tempo_manager.global_tempo == tempo_before, "pressing it without a shield costs nothing")
	var shield = ItemData.create("wooden_shield")
	inv.stored_items.append(shield)
	inv.equip_item(shield, 1)
	main._update_block_button_visibility()
	_check(b.visible and not b.disabled and b.text.ends_with("4T"), "a worn shield lights it up (%s)" % b.text)

	# --- Move box numbers ---
	var gs: float = main.grid_manager.grid_size
	var target: Vector3 = main.player.position + Vector3(gs * 3, 0, gs)
	var route = main.player.preview_path_cells(target, main.ROUTE_BUDGET)
	_check(route.size() >= 3, "a route of %d spaces" % route.size())
	stats.flash_movement_enabled = false
	stats.free_move_tiles = 0
	var plain: int = main.preview_move_tempo(route)
	_check(plain == route.size(), "on foot every space costs a tempo (%d)" % plain)
	stats.current_flash_points = PlayerStats.FLASH_COST_MOVE * 2
	stats.flash_movement_enabled = true
	_check(main.preview_move_tempo(route) == route.size() - 2, "flash movement on: two spaces paid with flash (%d)" % main.preview_move_tempo(route))
	stats.flash_movement_enabled = false
	_check(main.preview_move_tempo(route) == route.size(), "flash movement off: the points are not spent")
	stats.free_move_tiles = 1
	_check(main.preview_move_tempo(route) == route.size() - 1, "a Shadow Cowl free tile is free")
	stats.free_move_tiles = 0
	main.player.get_debuff_manager().apply_debuff(Debuff.create(Debuff.DebuffType.SLOWED, 2))
	_check(main.preview_move_tempo(route) == route.size() * Debuff.SLOWED_TEMPO_PER_TILE, "Slowed: each space costs %d" % Debuff.SLOWED_TEMPO_PER_TILE)
	main.player.get_debuff_manager().clear_all_debuffs()

	# The preview is what the walk really charges: flash on, 1 tile's worth.
	stats.current_flash_points = PlayerStats.FLASH_COST_MOVE
	stats.flash_movement_enabled = true
	var predicted: int = main.preview_move_tempo(route)
	var t0: int = main.tempo_manager.global_tempo
	main.player.move_to_grid(target, route.size())
	var guard := 0
	while (main.player.is_moving or main.grid_manager.world_to_grid(main.player.position) != route[route.size() - 1]) and guard < 600:
		guard += 1
		await process_frame
	var spent: int = main.tempo_manager.global_tempo - t0
	_check(spent == predicted, "walking the route spent %d tempo, the box said %d" % [spent, predicted])
	stats.flash_movement_enabled = false
	target = main.player.position + Vector3(-gs * 3, 0, -gs)
	route = main.player.preview_path_cells(target, main.ROUTE_BUDGET)

	var cur = main.move_path_cursor
	cur.show_path(main.grid_manager.world_to_grid(target), route, 7)
	_check(cur._spaces_label.text == str(route.size()) and cur._tempo_label.text == "7", "the box reads %s over %s" % [cur._spaces_label.text, cur._tempo_label.text])
	_check(cur._spaces_label.offset.y > 0 and cur._tempo_label.offset.y < 0, "spaces on top, tempo below")
	_check(cur._spaces_label.modulate == MovePathCursor.SPACES_COLOR and cur._tempo_label.modulate == MovePathCursor.TEMPO_COLOR, "brown spaces, yellow tempo")
	_check(cur.get_node("MoveNumbers/Bar") != null and cur._numbers.visible, "with the bar between them")
	cur.show_path(main.grid_manager.world_to_grid(target), route)
	_check(not cur._numbers.visible, "no tempo given (town): no numbers")

	print("=== %d failure(s) ===" % failures)
	quit(1 if failures > 0 else 0)
